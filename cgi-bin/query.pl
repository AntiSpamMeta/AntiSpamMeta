#!/usr/bin/perl

#use warnings;
use Data::Dumper;
use strict;
use DBI; 

use CGI;

use XML::Simple qw(:strict);
my $xs1 = XML::Simple->new( KeyAttr => ['id'], Cache => [ qw/memcopy/ ]);
my $sqlconf = $xs1->XMLin( "/home/icxcnika/AntiSpamMeta/config-main/mysql.xml",
                           ForceArray => ['ident', 'geco'],
                           'GroupTags' => { ignoredidents => 'ident', ignoredgecos => 'geco' });

my $dbh = DBI->connect("DBI:mysql:database=" . $sqlconf->{db} . ";host=" . $sqlconf->{host} . ";port=" . $sqlconf->{port}, $sqlconf->{user}, $sqlconf->{pass});

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

my $cgi = CGI->new;
my %data = %{$cgi->{param}};

$debug = int($data{debug}->[0]) if (defined($data{debug}));

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

if (defined($data{channel}->[0])) {
  $qry = $qry . "channel like " . esc($data{channel}->[0]);
} else { die "channel not defined!\n"; }

if (defined($data{nick}->[0]) && ($data{nick}->[0] ne "*") && ($data{nick}->[0] ne "")) {
  $qry .= " and nick like " . esc($data{nick}->[0]);
}

if (defined($data{user}->[0]) && ($data{user}->[0] ne "*") && ($data{user}->[0] ne "")) {
  $qry .= " and user like " . esc($data{user}->[0]);
}

if (defined($data{host}->[0]) && ($data{host}->[0] ne "*") && ($data{host}->[0] ne "")) {
  $qry .= " and host like " . esc($data{host}->[0]);
}

if (defined($data{gecos}->[0]) && ($data{gecos}->[0] ne "*") && ($data{gecos}->[0] ne "")) {
  $qry .= " and gecos like " . esc($data{gecos}->[0]);
}

if (defined($data{since}->[0])) {
  $qry .= sprintf("and time > '%04d-%02d-%02d %02d:%02d:%02d'",
                  int($data{syear}->[0]), int($data{smonth}->[0]), int($data{sday}->[0]),
                  int($data{shour}->[0]), int($data{smin}->[0]), int($data{ssec}->[0]));
}

if (defined($data{before}->[0])) {
  $qry .= sprintf("and time < '%04d-%02d-%02d %02d:%02d:%02d'",
                  int($data{byear}->[0]), int($data{bmonth}->[0]), int($data{bday}->[0]),
                  int($data{bhour}->[0]), int($data{bmin}->[0]), int($data{bsec}->[0]));
}

#if (defined($data{id})) {
#  $qry .= " and id = " . $dbh->quote($data{id});
#}

if (defined($data{level}->[0]) && ($data{level}->[0] ne "any")) {
  $qry .= " and level = " . $dbh->quote($data{level}->[0]);
}

if (defined($data{reason}->[0])) {
  $qry .= " and reason like " . esc($data{reason}->[0]);
}

if (defined($data{sort}) && defined($data{order}) && ($data{order}->[0] =~ /^[ad]$/ ) &&
    ( $data{sort}->[0] =~ /^(time|nick|user|host|level|id|reason)$/ ) ) {
  $qry .= " order by " . $data{sort}->[0];
  $qry .= " desc" if $data{order}->[0] eq "d";
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
