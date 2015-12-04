#!/usr/bin/perl

#use warnings;
use Data::Dumper;
use strict;
use DBI; 

use CGI_Lite;

my $dbh = DBI->connect("DBI:mysql:database=asm_main;host=localhost;port=3306", 'USER', 'PASSWORD');

my $debug = 0;

sub esc
{
  my ($arg) = @_;
  $arg = $dbh->quote($arg);
  $arg =~  s/\*/%/g;
  $arg =~ s/_/\\_/g;
  $arg =~  s/\?/_/g;
  return $arg;
}

my $cgi = new CGI_Lite;
my %data = $cgi->parse_form_data;

$debug = int($data{debug}) if (defined($data{debug}));

if ($debug) {
  print "Content-type: text/plain", "\n\n";
  print Dumper(\%data);
} else {
  print "Content-type: text/html", "\n\n";
  print "<html><head><title>Query results</title></head><body>\n";
}

my ($channel, $nick, $user, $host);
my ($level, $id, $reason);

my $qry = "SELECT time, channel, nick, user, host, gecos, level, id, reason FROM alertlog WHERE ";

if (defined($data{channel})) {
  $qry = $qry . "channel like " . esc($data{channel});
} else { die "channel not defined!\n"; }

if (defined($data{nick}) && ($data{nick} ne "*") && ($data{nick} ne "")) {
  $qry .= " and nick like " . esc($data{nick});
}

if (defined($data{user}) && ($data{user} ne "*") && ($data{user} ne "")) {
  $qry .= " and user like " . esc($data{user});
}

if (defined($data{host}) && ($data{host} ne "*") && ($data{host} ne "")) {
  $qry .= " and host like " . esc($data{host});
}

if (defined($data{gecos}) && ($data{gecos} ne "*") && ($data{gecos} ne "")) {
  $qry .= " and gecos like " . esc($data{gecos});
}

if (defined($data{since})) {
  $qry .= sprintf("and time > '%04d-%02d-%02d %02d:%02d:%02d'",
                  int($data{syear}), int($data{smonth}), int($data{sday}),
                  int($data{shour}), int($data{smin}), int($data{ssec}));
}

if (defined($data{before})) {
  $qry .= sprintf("and time < '%04d-%02d-%02d %02d:%02d:%02d'",
                  int($data{byear}), int($data{bmonth}), int($data{bday}),
                  int($data{bhour}), int($data{bmin}), int($data{bsec}));
}

#if (defined($data{id})) {
#  $qry .= " and id = " . $dbh->quote($data{id});
#}

if (defined($data{level}) && ($data{level} ne "any")) {
  $qry .= " and level = " . $dbh->quote($data{level});
}

if (defined($data{reason})) {
  $qry .= " and reason like " . esc($data{reason});
}

if (defined($data{sort}) && defined($data{order}) && ($data{order} =~ /^[ad]$/ ) &&
    ( $data{sort} =~ /^(time|nick|user|host|level|id|reason)$/ ) ) {
  $qry .= " order by " . $data{sort};
  $qry .= " desc" if $data{order} eq "d";
}

if ($debug) {
  print "Querying: ";
  print Dumper($qry);
}

my $sth = $dbh->prepare($qry);
$sth->execute;
my $names = $sth->{'NAME'};
my $numFields = $sth->{'NUM_OF_FIELDS'};

  print "<table border=\"1\"><tr>" unless $debug;

for (my $i = 0; $i < $numFields; $i++) {
  if ($debug) {
    printf("%s%s", $i ? "," : "", $$names[$i]);
  } else {
    print "<th>" . $$names[$i] . "</th>";
  }
}

print "</tr>" unless $debug;
print "\n";

while (my $ref = $sth->fetchrow_arrayref) {
  print "<tr>" unless $debug;

  for (my $i = 0; $i < $numFields; $i++) {
    if ($debug) {
      printf("%s%s", $i ? "," : "", $$ref[$i]);
    } else {
      print "<td>" . $$ref[$i] . "</td>";
    }
  }
  print "</tr>" unless $debug;
  print "\n";
}
unless ($debug) {
  print "</table></body></html>";
}
