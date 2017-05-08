package ASM::Config;
no autovivification;
use warnings;
use strict;
use feature 'state';

use JSON;
use IO::All;

our $json = JSON->new->utf8->pretty->canonical;

sub serialize {
  return $json->encode(@_);
}
sub deserialize {
  return $json->decode(@_);
}

sub readConfig {
  $::settings     = deserialize(io->file("$::cset/settings.json")->all);
  $::channels     = deserialize(io->file("$::cset/channels.json")->all);
  $::mysql        = deserialize(io->file("$::cset/mysql.json")->all);
  $::dnsbl        = deserialize(io->file("$::cset/dnsbl.json")->all);
  $::rules        = deserialize(io->file("$::cset/rules.json")->all);
  $::restrictions = deserialize(io->file("$::cset/restrictions.json")->all);
  $::blacklist    = deserialize(io->file("$::cset/blacklist.json")->all);
}

sub writeConfig {
  writeMysql();
  writeChannels();
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
