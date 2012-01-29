package ASM::XML;
use warnings;
use strict;

use XML::Simple qw(:strict);
use IO::All;

$::xs1 = XML::Simple->new( KeyAttr => ['id'], Cache => [ qw/storable memcopy/ ]);

sub readXML {
  my ( $p ) = $::cset;
  my @fchan = ( 'event', keys %::RISKS );
  $::settings = $::xs1->XMLin( "$p/settings.xml", ForceArray => ['host'], 'GroupTags' => { altnicks => 'altnick', server => 'host', autojoins => 'autojoin' });
  $::channels = $::xs1->XMLin( "$p/channels.xml", ForceArray => \@fchan );
  $::users    = $::xs1->XMLin( "$p/users.xml",    ForceArray => 'person');
  $::commands = $::xs1->XMLin( "$p/commands.xml", ForceArray => [qw/command/]);
  $::mysql    = $::xs1->XMLin( "$p/mysql.xml",    ForceArray => []);
  $::dnsbl    = $::xs1->XMLin( "$p/dnsbl.xml",    ForceArray => []);
}

sub writeXML {
  my ( $p ) = $::cset;
  $::xs1->XMLout($::settings, RootName => 'settings', KeyAttr => ['id'],
               GroupTags => { altnicks => 'altnick', server => 'host', autojoins => 'autojoin' },
               ValueAttr => { debug => 'content',     nick => 'content',    port => 'content',
                           realname => 'content', username => 'content',     dir => 'content',
                               zone => 'content',  filefmt => 'content', timefmt => 'content'}) > io("$p/settings.xml");
  $::xs1->XMLout($::channels, RootName => 'channels', KeyAttr => ['id']) > io("$p/channels.xml");
  $::xs1->XMLout($::users,    RootName => 'people',   KeyAttr => ['id']) > io("$p/users.xml");
  $::xs1->XMLout($::commands, RootName => 'commands', KeyAttr => ['id']) > io("$p/commands.xml");
}

sub writeChannels {
  $::xs1->XMLout($::channels, RootName => 'channels', KeyAttr => ['id']) > io("$::cset/channels.xml");
}

sub writeUsers {
  $::xs1->XMLout($::users,    RootName => 'people',   KeyAttr => ['id']) > io("$::cset/users.xml");
}

sub writeSettings {
  $::xs1->XMLout($::settings, RootName => 'settings', GroupTags => { altnicks => 'altnick', server => 'host', autojoins => 'autojoin' }, NoAttr => 1) > io("$::cset/settings.xml");
}

return 1;
