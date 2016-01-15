#!/usr/bin/perl

#use warnings;
use Data::Dumper;
use strict;
use DBI;

use CGI;
my $cgi = CGI->new;
my %data = %{$cgi->{param}};
my $index = $data{index}->[0];
print "Content-type: text/plain", "\n\n";
if ( !defined($index) ) {
  print "Nice hax!\n";
  exit 0;
}
$index = int $index;
my $i = int($index / 10000) + 1;

if ( -e "/var/www/antispammeta.net/actionlogs/${i}0K.tar.gz") {
  print "tar -Oxf /var/www/antispammeta.net/actionlogs/${i}0K.tar.gz $index.txt\n\n";
  print `tar -Oxf /var/www/antispammeta.net/actionlogs/${i}0K.tar.gz $index.txt`;
} elsif ( -e "/var/www/antispammeta.net/actionlogs/$index.txt.lzma" ) {
  print `lzcat /var/www/antispammeta.net/actionlogs/$index.txt.lzma`;
} elsif ( -e "/var/www/antispammeta.net/actionlogs/$index.txt" ) {
  print `cat /var/www/antispammeta.net/actionlogs/$index.txt`;
} else {
  print "u wot m8?\n";
}
