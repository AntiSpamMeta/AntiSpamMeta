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

sub dottedQuadToInt
{
  my ($dottedquad) = @_;
  my $ip_number = 0;
  my @octets = split(/\./, $dottedquad);
  foreach my $octet (@octets) {
    $ip_number <<= 8;
    $ip_number |= $octet;
  }
  return $ip_number;
}

my $cgi = new CGI_Lite;
my %data = $cgi->parse_form_data;

$debug = int($data{debug}) if (defined($data{debug}));

if ( !defined($data{query}) ) {
print "Content-type: text/html", "\n\n";
print <<HTML;
<html>
  <head>
    <title>AntiSpamMeta database query page</title>
  </head>
  <body>
  <h3>Maintaining AntiSpamMeta takes work! Please 
<form action="https://www.paypal.com/cgi-bin/webscr" method="post" target="_top">
<input type="hidden" name="cmd" value="_s-xclick">
<input type="hidden" name="encrypted" value="-----BEGIN PKCS7-----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-----END PKCS7-----
">
<input type="image" src="https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif" border="0" name="submit" alt="PayPal - The safer, easier way to pay online!">
<img alt="" border="0" src="https://www.paypalobjects.com/en_US/i/scr/pixel.gif" width="1" height="1">
</form></h3>
  <p>Matching is done based on field1 OR field2 OR field3 etc. Wildcards are supported,
except for the realIP field, which must be blank or an IPv4 dotted quad.</p>
    <form action="/cgi-bin/secret/investigate.pl" method="get">
      <input type="hidden" name="query" value="1" />
HTML
print '      Nickname: <input type="text" name="nick" ' . (defined($data{nick}) ? 'value="'.$data{nick}.'" ' : '') . "/><br />\n";
print '      User: <input type="text" name="user" ' . (defined($data{user}) ? 'value="'.$data{user}.'" ' : '') . "/><br />\n";
print '      Hostname: <input type="text" name="host" ' . (defined($data{host}) ? 'value="'.$data{host}.'" ' : '') . "/><br />\n";
print '      Gecos: <input type="text" name="gecos" ' . (defined($data{gecos}) ? 'value="'.$data{gecos}.'" ' : '') . "/><br />\n";
print '      Account: <input type="text" name="account" ' . (defined($data{account}) ? 'value="'.$data{account}.'" ' : '') . "/><br />\n";
print '      Real IP: <input type="text" name="realip" ' . (defined($data{realip}) ? 'value="'.$data{realip}.'" ' : '') . "/>\n";
print <<HTML;
      <br /><br /><input type="submit" value="Query!" />
    </form>
  </body>
</html>
HTML
exit 0;
}

if ($debug) {
	print "Content-type: text/plain", "\n\n";
	print Dumper(\%data);
} else {
	print "Content-type: text/html", "\n\n";
	print <<HTML;
<html>
<head>
<title>Query results</title>
<style>
tr {font-size:90%;}
.uhg {font-size:60%;}
.desc {font-size:90%;}
.time {font-size:80%;}
.action {}
.nick {}
</style>
</head>
<body>
HTML
}


##Queryable items:
## nick, user, host, realip, gecos, account
my $qry = 'SELECT * FROM actionlog WHERE ';

if (defined($data{nick}) && ($data{nick} ne "*") && ($data{nick} ne "")) {
  $qry .= " nick like " . esc($data{nick}) . ' or ';
}

if (defined($data{user}) && ($data{user} ne "*") && ($data{user} ne "")) {
  $qry .= ' user like ' . esc($data{user}) . ' or ';
}

if (defined($data{host}) && ($data{host} ne "*") && ($data{host} ne "")) {
  $qry .= ' host like ' . esc($data{host}) . ' or ';
}

if (defined($data{gecos}) && ($data{gecos} ne "*") && ($data{gecos} ne "")) {
  $qry .= ' gecos like ' . esc($data{gecos}) . ' or ';
}

if (defined($data{account}) && ($data{account} ne "*") && ($data{account} ne "")) {
  $qry .= ' account like ' . esc($data{account}) . ' or ';
}

if (defined($data{realip}) && ($data{realip} =~ /^\d+\.\d+\.\d+\.\d+$/)) {
  $qry .= ' ip = ' . dottedQuadToInt($data{realip}) . ' or ';
}

$qry .= '(1 = 0)'; # rather than trying to get rid of a trailing 'or '

if ($debug) {
  print "Querying: ";
  print Dumper($qry);
}

my $sth = $dbh->prepare($qry);
$sth->execute;
my $names = $sth->{'NAME'};
my $numFields = $sth->{'NUM_OF_FIELDS'};

#fields are index,time,action,reason,channel,nick,user,host,ip,gecos,account,bynick,byuser,byhost,bygecos,byaccount
my %f = (
	"index" => 0,
	"time" => 1,
	"action" => 2,
	"reason" => 3,
	"channel" => 4,
	"nick" => 5,
	"user" => 6,
	"host" => 7,
	"ip" => 8,
	"gecos" => 9,
	"account" => 10,
	"bynick" => 11,
	"byuser" => 12,
	"byhost" => 13,
	"bygecos" => 14,
	"byaccount" => 15
);
	
print "<table border=\"0\">" unless $debug;
if ($debug) {
  for (my $i = 0; $i < $numFields; $i++) {
    printf("%s%s", $i ? "," : "", $$names[$i]);
  }
}
#print "</tr>" unless $debug;
print "\n";

while (my $ref = $sth->fetchrow_arrayref) {
#fields are index,time,action,reason,channel,nick,user,host,ip,gecos,account,bynick,byuser,byhost,bygecos,byaccount
	unless ($debug) {
		print '<tr>';
		print '<td><a href="logs.pl?index=' . $$ref[$f{'index'}] . '" class="index">#' . $$ref[$f{'index'}] . ':</a></td>';
		print '<td nowrap="nowrap" class="time">' . $$ref[$f{'time'}] . '</td>';

		print '<td nowrap="nowrap"><span class="nick">' . $$ref[$f{'nick'}] . '</span>';
		print '<span class="uhg">!' . $$ref[$f{'user'}] . '@' . $$ref[$f{'host'}] . ' (' . $$ref[$f{'gecos'}] . ')';
		print ' [' . $$ref[$f{'account'}] . ']' if ($$ref[$f{'account'}] ne '');
		print '</span>';
		print ' <span class="desc">received</span> <span class="action">' . $$ref[$f{'action'}] . '</span>';
		print ' (' . $$ref[$f{'reason'}] . ')' if ($$ref[$f{'reason'}] ne '');
		print ' <span class="desc">on</span> ' . $$ref[$f{'channel'}] if ($$ref[$f{'channel'}] ne '');
		print ' ';
#		print '</td>';
#		print '<td>';
		if ($$ref[$f{'bynick'}] ne '') {
			print '<span class="desc">by</span> ' . $$ref[$f{'bynick'}];
			print '<span class="uhg">!' . $$ref[$f{'byuser'}] . '@' . $$ref[$f{'byhost'}] . ' (' . $$ref[$f{'bygecos'}] . ')';
			print ' [' . $$ref[$f{'byaccount'}] . ']' if ($$ref[$f{'byaccount'}] ne '');
			print '</span>';
		}
		print '</td>';
		print '</tr>';
	} else {
		for (my $i = 0; $i < $numFields; $i++) {
			printf("%s%s", $i ? "," : "", $$ref[$i]);
		}
	}
	print "\n";
}
unless ($debug) {
  print "</table></body></html>";
}
