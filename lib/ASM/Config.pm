package ASM::Config;
no autovivification;
use warnings;
use strict;
use feature 'state';

use XML::Simple qw(:strict);
use JSON;
use IO::All;
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

our $json = JSON->new->utf8->pretty->canonical;

sub serialize {
  return $json->encode(@_);
}
sub deserialize {
  return $json->decode(@_);
}

sub readXML {
  my ( $p ) = $::cset;
  my @fchan = ( 'event', keys %::RISKS );
  my $xs1 = XML::Simple->new( KeyAttr => ['id'], Cache => [ qw/memcopy/ ]);
  $::settings     = $xs1->XMLin( "$p/settings.xml",     ForceArray => ['host'],
                                 'GroupTags' => { altnicks => 'altnick', server => 'host',
                                                 autojoins => 'autojoin' });
  $::channels     = $xs1->XMLin( "$p/channels.xml",     ForceArray => \@fchan );
  $::users        = $xs1->XMLin( "$p/users.xml",        ForceArray => 'person');
  $::mysql        = $xs1->XMLin( "$p/mysql.xml",        ForceArray => ['ident', 'geco'],
                                 'GroupTags' => { ignoredidents => 'ident', ignoredgecos => 'geco' });
  $::dnsbl        = $xs1->XMLin( "$p/dnsbl.xml",        ForceArray => []);
  $::rules        = $xs1->XMLin( "$p/rules.xml",        ForceArray => []);
  $::restrictions = $xs1->XMLin( "$p/restrictions.xml", ForceArray => ['host', 'nick', 'account']);
  $::blacklist    = $xs1->XMLin( "$p/blacklist.xml",    ForceArray => 'string');
}

sub readConfig {
  if (!-e "$::cset/settings.json") {
    state $in_readconfig = 0;
    die "Unexpected readConfig recursion" if $in_readconfig++;
    readXML();
    writeConfig();
    readConfig();
  }
  else {
    $::settings     = deserialize(io->file("$::cset/settings.json")->all);
    $::channels     = deserialize(io->file("$::cset/channels.json")->all);
    $::users        = deserialize(io->file("$::cset/users.json")->all);
    $::mysql        = deserialize(io->file("$::cset/mysql.json")->all);
    $::dnsbl        = deserialize(io->file("$::cset/dnsbl.json")->all);
    $::rules        = deserialize(io->file("$::cset/rules.json")->all);
    $::restrictions = deserialize(io->file("$::cset/restrictions.json")->all);
    $::blacklist    = deserialize(io->file("$::cset/blacklist.json")->all);
  }
}

sub writeConfig {
  writeMysql();
  writeChannels();
  writeUsers();
  writeSettings();
  writeRestrictions();
  writeBlacklist();
  writeDnsbl();
  writeRules();
}

sub writeMysql {
  $::settingschanged=1;
  serialize($::mysql) > io->file("$::cset/mysql.json");
}

sub writeRules {
  $::settingschanged=1;
  serialize($::rules) > io->file("$::cset/rules.json");
}

sub writeDnsbl {
  $::settingschanged=1;
  serialize($::dnsbl) > io->file("$::cset/dnsbl.json");
}

sub writeChannels {
  $::settingschanged=1;
  serialize($::channels) > io("$::cset/channels.json");
}

sub writeUsers {
  $::settingschanged=1;
  serialize($::users) > io("$::cset/users.json");
}

sub writeSettings {
  $::settingschanged=1;
  serialize($::settings) > io("$::cset/settings.json");
}

sub writeRestrictions {
  $::settingschanged=1;
  serialize($::restrictions) > io("$::cset/restrictions.json");
}

sub writeBlacklist {
  $::settingschanged=1;
  serialize($::blacklist) > io("$::cset/blacklist.json");
}

return 1;
# vim: ts=2:sts=2:sw=2:expandtab
