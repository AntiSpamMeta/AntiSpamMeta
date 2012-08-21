#!/usr/bin/perl -w

use lib '/home/icxcnika/AntiSpamMeta';

#use Devel::Profiler package_filter => sub { return 0 if $_[0] =~ /^XML::Simple/; return 1; };


use warnings;
use strict;
use Net::IRC;
use Data::Dumper;
use IO::All;
use Getopt::Long;
use POSIX qw(strftime);
use Term::ANSIColor qw(:constants);

$Data::Dumper::Useqq=1;

%::eline=();
$::pass = '';
@::string_blacklist=();
$::netsplit = 0;
$::debug = 0;
$::cset = '';

## debug variables. 0 to turn off debugging, else set it to a Term::ANSIColor constant.
%::debugx = (
  "dnsbl" => 0,
  "pingpong" => 0, #BLUE,
  "services" => YELLOW,
  "sync" => CYAN,
  "chanstate" => MAGENTA,
  "restrictions" => BLUE,
  "startup" => YELLOW,
  "mysql" => 0,
  "inspector" => 0,
  "commander" => GREEN,
  "msg" => GREEN,
  "dcc" => RED,
  "misc" => 0, #RED
  "latency" => RED,
  "statsp" => 0 #MAGENTA
);
%::dsock = ();
%::spy = ();
$::starttime = time;
@::syncqueue = ();
%::watchRegged = ();
$::lastline = "";

$SIG{__WARN__} = sub {
  $Data::Dumper::Useqq=1;
  print STDERR 'last line: ' . Dumper($::lastline);
  print STDERR strftime("%F %T", gmtime), RED, ' WARNING: ', RESET, $_[0];
};

BEGIN {
my @modules = qw/Util Xml Inspect Event Services Log Command Classes Mysql/;
require 'modules/' . lc $_ . '.pl' foreach @modules;
}

sub init {
  my ( $conn, $host );
  my $irc = new Net::IRC;
  GetOptions( 'debug|d!'   => \$::debug,
              'pass|p=s'   => \$::pass,
              'config|c=s' => \$::cset
            );
  if ($::cset eq '') { $::cset = 'config-default'; }
                else { $::cset = "config-$::cset"; }
  ASM::XML->readXML();
  mkdir($::settings->{log}->{dir});
  $::log = ASM::Log->new($::settings->{log});
  $::pass = $::settings->{pass} if $::pass eq '';
  $host = ${$::settings->{server}}[rand @{$::settings->{server}}];
  ASM::Util->dprint( "Connecting to $host", "startup");
  $irc->debug($::debug);
  $::db = ASM::DB->new($::mysql->{db}, $::mysql->{host}, $::mysql->{port}, $::mysql->{user}, $::mysql->{pass}, $::mysql->{table}, $::mysql->{dblog});
  $conn = $irc->newconn( Server => $host,
                         Port => $::settings->{port} || '6667',
                         Nick => $::settings->{nick},
                         Ircname => $::settings->{realname},
                         Username => $::settings->{username},
                         Password => $::settings->{pass},
			 Pacing => 0 );
  $conn->debug($::debug);
  $::inspector = ASM::Inspect->new();
  $::services = ASM::Services->new();
  $::commander = ASM::Commander->new();
  ASM::Event->new($conn, $::inspector);
  $::classes = ASM::Classes->new();
  my @eline=io('exempt.txt')->getlines;
  chomp @eline;
  foreach my $item (@eline) {
    $::eline{lc $item} = 1;
  }
  my @strbl = io('string_blacklist.txt')->getlines;
  chomp @strbl;
  @::string_blacklist = @strbl;
  %::proxies = ();
  my @proxy = io('proxy.txt')->getlines;
  chomp @proxy;
  foreach my $line (@proxy) {
    if ($line =~ /(\d+\.\d+\.\d+\.\d+):\d+/) {
      $::proxies{$1} = 1;
    }
  }
  $irc->start();
}

init();
