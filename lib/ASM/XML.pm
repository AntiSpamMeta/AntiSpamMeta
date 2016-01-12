package ASM::XML;
no autovivification;
use warnings;
use strict;

use XML::Simple qw(:strict);
use IO::All;

$::xs1 = XML::Simple->new( KeyAttr => ['id'], Cache => [ qw/memcopy/ ]);

sub readXML {
  my ( $p ) = $::cset;
  my @fchan = ( 'event', keys %::RISKS );
  $::settings     = $::xs1->XMLin( "$p/settings.xml",     ForceArray => ['host'],
                                   'GroupTags' => { altnicks => 'altnick', server => 'host',
                                                   autojoins => 'autojoin' });
  $::channels     = $::xs1->XMLin( "$p/channels.xml",     ForceArray => \@fchan );
  $::users        = $::xs1->XMLin( "$p/users.xml",        ForceArray => 'person');
  $::commands     = $::xs1->XMLin( "$p/commands.xml",     ForceArray => [qw/command/]);
  $::mysql        = $::xs1->XMLin( "$p/mysql.xml",        ForceArray => ['ident', 'geco'],
                                   'GroupTags' => { ignoredidents => 'ident', ignoredgecos => 'geco' });
  $::dnsbl        = $::xs1->XMLin( "$p/dnsbl.xml",        ForceArray => []);
  $::rules        = $::xs1->XMLin( "$p/rules.xml",        ForceArray => []);
  $::restrictions = $::xs1->XMLin( "$p/restrictions.xml", ForceArray => ['host', 'nick', 'account']);
  $::blacklist    = $::xs1->XMLin( "$p/blacklist.xml",    ForceArray => 'string');
}

sub writeXML {
  writeSettings();
  writeChannels();
  writeUsers();
  writeRestrictions();
  writeBlacklist();
  writeMysql();
#  $::xs1->XMLout($::commands,     RootName => 'commands', KeyAttr => ['id']) > io("$::cset/commands.xml");
}

sub writeMysql {
  $::settingschanged=1;
  $::xs1->XMLout($::mysql,    RootName => 'mysql',    KeyAttr => ['id']) > io("$::cset/mysql.xml");
}

sub writeChannels {
  $::settingschanged=1;
  $::xs1->XMLout($::channels, RootName => 'channels', KeyAttr => ['id'], NumericEscape => 2) > io("$::cset/channels.xml");
}

sub writeUsers {
  $::settingschanged=1;
  $::xs1->XMLout($::users,    RootName => 'people',   KeyAttr => ['id']) > io("$::cset/users.xml");
}

sub writeSettings {
  $::settingschanged=1;
  $::xs1->XMLout($::settings, RootName => 'settings', 
                GroupTags => { altnicks => 'altnick', server => 'host', autojoins => 'autojoin' }, NoAttr => 1) > io("$::cset/settings.xml");
}

sub writeRestrictions {
  $::settingschanged=1;
  $::xs1->XMLout($::restrictions, RootName => 'restrictions', KeyAttr => ['id'],
                       GroupTags => { hosts => "host", nicks => "nick", accounts => "account"}) > io("$::cset/restrictions.xml");
}

sub writeBlacklist {
  $::settingschanged=1;
  $::xs1->XMLout($::blacklist, RootName => 'blacklist', KeyAttr => ['id'], NumericEscape => 2) > io("$::cset/blacklist.xml");
}

return 1;
