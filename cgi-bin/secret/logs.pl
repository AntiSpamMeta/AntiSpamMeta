#!/usr/bin/perl

#use warnings;
use Data::Dumper;
use strict;
use DBI;

use CGI_Lite;
my $cgi = new CGI_Lite;
my %data = $cgi->parse_form_data;
my $index = $data{index};
print "Content-type: text/plain", "\n\n";
if ( !defined($index) ) {
  print "Nice hax!\n";
  exit 0;
}
$index = int $index;
my $i = int($index / 10000) + 1;

if ( -e "/var/www/actionlogs/${i}0K.tar.gz") {
  print "tar -Oxf /var/www/actionlogs/${i}0K.tar.gz $index.txt\n\n";
  print `tar -Oxf /var/www/actionlogs/${i}0K.tar.gz $index.txt`;
} elsif ( -e "/var/www/actionlogs/$index.txt.lzma" ) {
  print `lzcat /var/www/actionlogs/$index.txt.lzma`;
} elsif ( -e "/var/www/actionlogs/$index.txt" ) {
  print `cat /var/www/actionlogs/$index.txt`;
} else {
  print "u wot m8?\n";
}
