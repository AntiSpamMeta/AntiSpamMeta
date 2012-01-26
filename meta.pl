#!/usr/bin/perl -w

use lib '/home/icxcnika/AntiSpamMeta';
#use Devel::Profiler
#  package_filter => sub {
#			my $pkg = shift;
#			return 0 if $pkg =~ /^XML::Simple/;
#			return 1;
#		    };
use warnings;
use strict;
use Net::IRC;
use Data::Dumper;
use IO::All;
use Getopt::Long;

%::eline=();
$::pass = '';
@::string_blacklist=();
@::joinrate=(); #I really need to stop doing this shit

BEGIN {
my @modules = qw/Util Xml Inspect Event Services Log Command Classes Actions Mysql OperQueue/;
require 'modules/' . lc $_ . '.pl' foreach @modules;
}

sub init {
  my ( $conn, $host );
  my $debug = 0;
  my $irc = new Net::IRC;
  $::cset = '';
  GetOptions( 'debug|d!'   => \$debug,
              'pass|p:s'   => \$::pass,
              'config|c:s' => \$::cset
            );
  $::debug = $debug;
  ASM::XML->readXML();
  mkdir($::settings->{log}->{dir});
  $::log = ASM::Log->new($::settings->{log});
  $::pass = $::settings->{pass} if $::pass eq '';
  $host = ${$::settings->{server}}[rand @{$::settings->{server}}];
  print "Connecting to $host\n";
  $irc->debug($debug);
  $::db = ASM::DB->new($::mysql->{db}, $::mysql->{host}, $::mysql->{port}, $::mysql->{user}, $::mysql->{pass}, $::mysql->{table}, $::mysql->{dblog});
  $conn = $irc->newconn( Server => $host,
                         Port => $::settings->{port} || '6667',
                         Nick => $::settings->{nick},
                         Ircname => $::settings->{realname},
                         Username => $::settings->{username},
                         Password => $::settings->{pass},
			 Pacing => 1 );
  $conn->debug($debug);
  $::inspector = ASM::Inspect->new();
  $::services = ASM::Services->new();
  $::oq = ASM::OperQueue->new();
  $::commander = ASM::Commander->new();
  $::event = ASM::Event->new($conn, $::inspector);
  $::classes = ASM::Classes->new();
  $::actions = ASM::Actions->new();
  my @eline=io('exempt.txt')->getlines;
  chomp @eline;
  foreach my $item (@eline) {
    $::eline{lc $item} = 1;
  }
  my @strbl = io('string_blacklist.txt')->getlines;
  chomp @strbl;
  @::string_blacklist = @strbl;
  $irc->start();
}

init();
