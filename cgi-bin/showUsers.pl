#!/usr/bin/perl

#use warnings;
use Data::Dumper;
use strict;
use DBI; 
use XML::Simple qw(:strict);


print "Content-type: text/html", "\n\n";
print <<HTML;
<html>
  <head>
    <title>AntiSpamMeta User List</title>
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
<table>
<tr>
  <th>NickServ account</th>
  <th style="width:20px">s</th>
  <th style="width:20px">h</th>
  <th style="width:20px">a</th>
  <th style="width:20px">d</th>
  <th style="width:20px">p</th>
</tr>
HTML

my $xs1 = XML::Simple->new( KeyAttr => ['id'], Cache => [ qw/memcopy/ ]);
my $users = $xs1->XMLin( "/home/icxcnika/AntiSpamMeta/config-main/users.xml", ForceArray => 'person');

sub printout
{
  my ($user) = @_;
  print "<tr><td style=\"text-align:right\"><b>$user</b></td>";
  print "<td style=\"text-align:center\">";
  print "s" if (index($users->{person}->{$user}->{flags}, 's') != -1);
  print "</td>";
  print "<td style=\"text-align:center\">";
  print "h" if (index($users->{person}->{$user}->{flags}, 'h') != -1);
  print "</td>";
  print "<td style=\"text-align:center\">";
  print "a" if (index($users->{person}->{$user}->{flags}, 'a') != -1);
  print "</td>";
  print "<td style=\"text-align:center\">";
  print "d" if (index($users->{person}->{$user}->{flags}, 'd') != -1);
  print "</td>";
  print "<td style=\"text-align:center\">";
  print "p" if (index($users->{person}->{$user}->{flags}, 'p') != -1);
  print "</td>";
  print "</tr>\n";
}

foreach my $user (sort keys %{$users->{person}}) {
  if (index($users->{person}->{$user}->{flags}, 'd') != -1) {
    printout($user);
    delete $users->{person}->{$user};
  }
}
foreach my $user (sort keys %{$users->{person}}) {
  if (index($users->{person}->{$user}->{flags}, 'a') != -1) {
    printout($user);
    delete $users->{person}->{$user};
  }
}
foreach my $user (sort keys %{$users->{person}}) {
  if (index($users->{person}->{$user}->{flags}, 'h') != -1) {
    printout($user);
    delete $users->{person}->{$user}
  }
}
foreach my $user (sort keys %{$users->{person}}) {
  if (index($users->{person}->{$user}->{flags}, 's') != -1) {
    printout($user);
    delete $users->{person}->{$user}
  }
}
foreach my $user (sort keys %{$users->{person}}) {
#  if (index($users->{person}->{$user}->{flags}, 's') != -1) {
    printout($user);
    delete $users->{person}->{$user}
#  }
}

print "</table></body></html>";

exit 0;
