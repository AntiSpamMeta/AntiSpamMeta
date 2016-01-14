#!/usr/bin/env perl
no autovivification;
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";;

use Net::IRC 0.90;
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

use ASM::Util;
use ASM::XML;
use ASM::Inspect;
use ASM::Event;
use ASM::Services;
use ASM::Log;
use ASM::Commander;
use ASM::Classes;
use ASM::DB;
use ASM::Fifo;
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

$|++;
$Data::Dumper::Useqq=1;

$::pass = '';
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
  "dns" => 0
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

sub init {
  my ( $conn, $host );
  my $irc = new Net::IRC;
  GetOptions( 'debug|d!'   => \$::debug,
              'pass|p=s'   => \$::pass,
              'config|c=s' => \$::cset
            );
  if (-e "debugmode") {
    $::debug = 1;
  }
  if ($::cset eq '') { $::cset = 'config-default'; }
                else { $::cset = "config-$::cset"; }
  ASM::XML->readXML();
  mkdir($::settings->{log}->{dir});
  $::log = ASM::Log->new($::settings->{log});
  $::pass = $::settings->{pass} if $::pass eq '';
  $::async = HTTP::Async->new();
  $host = ${$::settings->{server}}[rand @{$::settings->{server}}];
  ASM::Util->dprint( "Connecting to $host", "startup");
  $irc->debug($::debug);
  if (-e "debugsock") {
    $irc->debugsock(1);
  }
  if (!$::mysql->{disable}) {
      $::db = ASM::DB->new($::mysql->{db}, $::mysql->{host}, $::mysql->{port},
                           $::mysql->{user}, $::mysql->{pass}, $::mysql->{table},
                           $::mysql->{actiontable}, $::mysql->{dblog});
  }
  $conn = $irc->newconn( Server => $host,
                         Port => $::settings->{port} || '6667',
                         SSL => defined($::settings->{ssl}),
                         Nick => $::settings->{nick},
                         Ircname => $::settings->{realname},
                         Username => $::settings->{username},
                         Password => $::settings->{pass},
			 Pacing => 0 );
  $conn->debug($::debug);
  if (-e "debugsock") {
    $conn->debugsock(1);
  }
  $::inspector = ASM::Inspect->new();
  $::services = ASM::Services->new();
  $::commander = ASM::Commander->new();
  $::event = ASM::Event->new($conn, $::inspector);
  $::classes = ASM::Classes->new();
  $::fifo = ASM::Fifo->new($irc, $conn);
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
    $::fm->watch("./" . $::cset . '/' . $file . ".xml");
  }
  $::fm->scan();
  $irc->start();
}

init();
