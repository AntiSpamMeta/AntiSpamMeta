#!/usr/bin/perl -w

use lib '/home/icxcnika/AntiSpamMeta';
#use lib '/home/wheimbigner/perl/lib/perl5/site_perl/5.8.8';
use warnings;
use strict;
use Net::IRC;
use Data::Dumper;
use IO::All;
use Getopt::Long;
use POSIX qw(strftime);

@::eline=();
$::pass = '';

my @modules = qw/Xml Util Inspect Services Log Command Event Classes Actions Mysql/;

require 'modules/' . lc $_ . '.pl' foreach @modules;

sub rePlug
{
  my ($conn) = @_;
  foreach (@modules) {
    eval $_ . '::killsub();';
    warn $@ if $@;
    eval 'undef &' . $_ . '::killsub;';
    warn $@ if $@;
    delete $INC{'modules/' . lc $_ . '.pl'};
    require 'modules/' . lc $_ . '.pl';
  }
  registerHandlers($conn); # this is necessary in case event.pl has changed
                           # because handlers are registered via pointers
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
  readXML();
  $::pass = $::settings->{pass} if $::pass eq '';
  $host = ${$::settings->{server}}[rand @{$::settings->{server}}];
  print "Connecting to $host\n";
  $irc->debug($debug);
  sql_connect();
  $conn = $irc->newconn( Server => $host,
                         Port => $::settings->{port} || '6667',
                         Nick => $::settings->{nick},
                         Ircname => $::settings->{realname},
                         Username => $::settings->{username},
                         Password => $::pass,
			 Pacing => 1 );
  $conn->debug($debug);
  registerHandlers($conn);
  @::eline=io('exempt.txt')->getlines;
  chomp @::eline;
  $irc->start();
}

sub registerHandlers {
  my ($conn) = @_;
  print "Installing handler routines...\n";
  $conn->add_default_handler(\&blah);
  $conn->add_handler('bannedfromchan', \&on_bannedfromchan);
  $conn->add_handler('mode', \&on_mode);
  $conn->add_handler('join', \&on_join);
  $conn->add_handler('part', \&on_part);
  $conn->add_handler('quit', \&on_quit);
  $conn->add_handler('nick', \&on_nick);
  $conn->add_handler('notice', \&on_notice);
  $conn->add_handler('caction', \&on_public);
  $conn->add_handler('msg', \&on_msg);
  $conn->add_handler('namreply', \&on_names);
  $conn->add_handler('endofnames', \&on_names);
  $conn->add_handler('public', \&on_public);
  $conn->add_handler('376', \&on_connect);
  $conn->add_handler('topic', \&irc_topic);
  $conn->add_handler('topicinfo', \&irc_topic);
  $conn->add_handler('nicknameinuse', \&on_errnickinuse);
  $conn->add_handler('kick', \&on_kick);
  $conn->add_handler('cping', \&on_ctcp);
  $conn->add_handler('cversion', \&on_ctcp);
  $conn->add_handler('csource', \&on_ctcp);
  $conn->add_handler('ctime', \&on_ctcp);
  $conn->add_handler('cdcc', \&on_ctcp);
  $conn->add_handler('cuserinfo', \&on_ctcp);
  $conn->add_handler('cclientinfo', \&on_ctcp);
  $conn->add_handler('cfinger', \&on_ctcp);
  $conn->add_handler('320', \&whois_identified);
  $conn->add_handler('318', \&whois_end);
  $conn->add_handler('311', \&whois_user);
  $conn->add_handler('352', \&on_whoreply);
}

init();
