#!/usr/bin/env perl
no autovivification;
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";;

use Net::IRC 0.91;
use Data::Dumper;
use IO::All;
use Getopt::Long;
use POSIX qw(strftime);
use Term::ANSIColor qw(:constants);
use File::Monitor;
use feature qw(say);
use HTTP::Async;
use Carp;
use Tie::CPHash;
use Net::DNS::Async;

use ASM::Util;
use ASM::Config;
use ASM::Inspect;
use ASM::Event;
use ASM::Services;
use ASM::Log;
use ASM::Commander;
use ASM::Classes;
use ASM::DB;
use ASM::Fifo;
use ASM::Statsp;

no if $] >= 5.017011, warnings => 'experimental::smartmatch';

$|++;
$Data::Dumper::Useqq=1;

@::nick_blacklist=();
$::netsplit = 0;
$::netsplit_ignore_lag = 0;
$::no_autojoins = 0;
$::debug = 0;
$::cset = '';
$::pacealerts = 1;
$::settingschanged = 0;
%::wordlist = ();
%::httpRequests = ();
$::version = '';

## debug variables. 0 to turn off debugging, else set it to a Term::ANSIColor constant.
%::debugx = (
  "dnsbl" => 0, # BLUE,
  "pingpong" => 0, #BLUE,
  "snotice" => YELLOW,
  "sync" => CYAN,
  "chanstate" => MAGENTA,
  "restrictions" => BLUE,
  "startup" => YELLOW,
  "mysql" => 0, #CYAN,
  "inspector" => 0,
  "commander" => GREEN,
  "msg" => GREEN,
  "dcc" => RED,
  "misc" => 0, #RED,
  "latency" => RED,
  "statsp" => MAGENTA,
  "ctcp" => 0, #RED,
  "logger" => 0,
  "dns" => MAGENTA
);
%::dsock = ();
%::spy = ();
$::starttime = time;
@::syncqueue = ();
@::bansyncqueue = ();
@::quietsyncqueue = ();
$::pendingsync = 0;
%::watchRegged = ();
$::lastline = "";
%::sn = (); %::sc = (); tie %::sc, 'Tie::CPHash'; tie %::sn, 'Tie::CPHash';
%::sa = (); tie %::sa, 'Tie::CPHash';

$SIG{__WARN__} = sub {
  $Data::Dumper::Useqq=1;
  print STDERR 'last line: ' . Dumper($::lastline);
  print STDERR strftime("%F %T", gmtime), RED, ' WARNING: ', RESET, $_[0];
};

sub alarmdeath
{
  $Data::Dumper::Useqq=1;
  confess "SIG ALARM!!! last line: " . Dumper($::lastline);
}
$SIG{ALRM} = \&alarmdeath;
alarm 300;

sub startup_checks {
  my $config_bad = 0;

  if (exists $::mysql->{table}) {
    if ($::mysql->{table} ne 'alertlog') {
      warn "FATAL - The 'table' option in mysql.json is no longer supported. Please ensure your table is named 'alertlog'.\n";
      $config_bad++;
    }
    else {
      warn "The 'table' option in mysql.json is no longer supported. Please remove it from the configuration.\n";
    }
  }
  if (exists $::mysql->{actiontable}) {
    if ($::mysql->{actiontable} ne 'actionlog') {
      warn "FATAL - The 'actiontable' option in mysql.json is no longer supported. Please ensure your table is named 'actionlog'.\n";
      $config_bad++;
    }
    else {
      warn "The 'actiontable' option in mysql.json is no longer supported. Please remove it from the configuration.\n";
    }
  }

  if (exists $::settings->{pass}) {
    warn "The 'pass' option in settings.json has been split into 'server_pass' and 'account_pass'. Please update your configuration accordingly.\n";
    $::settings->{server_pass} //= $::settings->{account_pass} //= $::settings->{pass};
  }

  if ($config_bad) {
    die "The bot cannot operate with the current configuration.\n";
  }
}

sub init {
  my ( $conn, $host );
  $::version .= `git merge-base remotes/origin/master HEAD`; chomp $::version;
  $::version .= ' ';
  $::version .= `git describe --long --all --dirty`; chomp $::version;
  $::version .= ' ';
  $::version .= `git rev-parse HEAD`; chomp $::version;
  my $irc = new Net::IRC;
  GetOptions( 'debug|d!'   => \$::debug,
              'config|c=s' => \$::cset
            );
  if (-e "debugmode") {
    $::debug = 1;
  }
  if ($::cset eq '') { $::cset = 'config-default'; }
                else { $::cset = "config-$::cset"; }
  ASM::Config->readConfig();

  startup_checks();

  $::async = HTTP::Async->new();
  $::dns = Net::DNS::Async->new(QueueSize => 5000, Retries => 3);
  $host = ${$::settings->{server}}[rand @{$::settings->{server}}];
  ASM::Util->dprint( "Connecting to $host", "startup");
  $irc->debug($::debug);
  if (-e "debugsock") {
    $irc->debugsock(1);
  }

  if (!$::mysql->{disable}) {
    my $dsn;
    if (exists $::mysql->{dsn}) {
      $dsn = $::mysql->{dsn};
    }
    else {
      # This isn't what we *should* do - notably, we'd have to wrap IPv6 addresses given
      # as host in brackets. It's what the old code did, though, and all we need is
      # compatibility with that.
      $dsn = sprintf 'DBI:mysql:database=%s;host=%s;port=%s', @{ $::mysql }{'db', 'host', 'port'};
    }
    $::db = ASM::DB->connect($dsn, $::mysql->{user}, $::mysql->{pass});
  }
  $conn = $irc->newconn( Server => $host,
                         Port => $::settings->{port} || '6667',
                         SSL => defined($::settings->{ssl}),
                         Nick => $::settings->{nick},
                         Ircname => $::settings->{realname},
                         Username => $::settings->{username},
                         Password => $::settings->{server_pass},
                         Pacing => 0 );
  $conn->debug($::debug);
  if (-e "debugsock") {
    $conn->debugsock(1);
  }

  ASM::Event->new($conn);
  ASM::Inspect->new($conn);
  $::log = ASM::Log->new($conn);
  ASM::Commander->new($conn);
  ASM::Services->new($conn);
  ASM::Statsp->new($conn);
  $::classes = ASM::Classes->new();
  ASM::Fifo->new($irc, $conn);
  my @nickbl = io('nick_blacklist.txt')->getlines;
  chomp @nickbl;
  @::nick_blacklist = @nickbl;
  %::proxies = ();
  my @proxy = io('proxy.txt')->getlines;
  chomp @proxy;
  foreach my $line (@proxy) {
    if ($line =~ /(\d+\.\d+\.\d+\.\d+):\d+/) {
      $::proxies{$1} = 1;
    }
  }
  my @wl=io('wordlist.txt')->getlines;
  chomp @wl;
  foreach my $item (@wl) {
    $::wordlist{lc $item} = 1;
  }
  $::fm = File::Monitor->new();
  foreach my $file ("channels", "dnsbl", "mysql", "restrictions", "rules", "settings", "users", "blacklist") {
    $::fm->watch("./" . $::cset . '/' . $file . ".json");
  }
  $::fm->scan();
  $irc->start();
}

init();
# vim: ts=2:sts=2:sw=2:expandtab
