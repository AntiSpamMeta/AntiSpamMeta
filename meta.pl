#!/usr/bin/perl -w

use lib '/home/icxcnika/AntiSpamMeta';
use warnings;
use strict;
use Net::IRC;
use Data::Dumper;
use IO::All;
use Getopt::Long;

@::eline=();
$::pass = '';

my @modules = qw/Xml Util Inspect Services Log Command Event Classes Actions Mysql OperQueue/;

require 'modules/' . lc $_ . '.pl' foreach @modules;

sub init {
  my ( $conn, $host );
  my $debug = 0;
  my $irc = new Net::IRC;
  $::cset = '';
  GetOptions( 'debug|d!'   => \$debug,
              'pass|p:s'   => \$::pass,
              'config|c:s' => \$::cset
            );
  ASM::XML->readXML();
  $::log = ASM::Log->new($::settings->{log});
  $::pass = $::settings->{pass} if $::pass eq '';
  $host = ${$::settings->{server}}[rand @{$::settings->{server}}];
  print "Connecting to $host\n";
  $irc->debug($debug);
  $::db = ASM::DB->new($::mysql->{db}, $::mysql->{host}, $::mysql->{port}, $::mysql->{user}, $::mysql->{pass}, $::mysql->{table});
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
  @::eline=io('exempt.txt')->getlines;
  chomp @::eline;
  $irc->start();
}

init();
