package ASM::DB;

use warnings;
use strict;
use DBI;

sub new {
  my $module = shift;
  my ($db, $host, $port, $user, $pass, $table, $dblog) = @_;
  my $self = {};
  $self->{DBH} = DBI->connect("DBI:mysql:database=$db;host=$host;port=$port", $user, $pass);
  $self->{DBH_LOG} = DBI->connect("DBI:mysql:database=$dblog;host=$host;port=$port", $user, $pass);
  $self->{DBH}->{mysql_auto_reconnect} = 1;
  $self->{DBH_LOG}->{mysql_auto_reconnect} = 1;
  $self->{TABLE} = $table;
  bless($self);
  return $self;
}

#sub sql_connect
#{
#  $::dbh = DBI->connect("DBI:mysql:database=$::mysql->{db};host=$::mysql->{host};port=$::mysql->{port}",
#                        $::mysql->{user}, $::mysql->{pass});
#  $::dbh->{mysql_auto_reconnect} = 1;
#}

sub raw
{
  my $self = shift;
  my ($conn, $tgt, $dbh, $qry) = @_;
  my $sth = $dbh->prepare($qry);
  $sth->execute;
  my $names = $sth->{'NAME'};
  my $numFields = $sth->{'NUM_OF_FIELDS'};
  my $string = "";
  for (my $i = 0; $i < $numFields; $i++) {
    $string = $string . sprintf("%s%s", $i ? "," : "", $$names[$i]);
  }
  $conn->privmsg($tgt, $string);
  while (my $ref = $sth->fetchrow_arrayref) {
    $string = "";
    for (my $i = 0; $i < $numFields; $i++) {
      $string = $string . sprintf("%s%s", $i ? "," : "", $$ref[$i]);
    }
    $conn->privmsg($tgt, $string);
  }
}

sub record
{
  my $self = shift;
  my ($channel, $nick, $user, $host, $gecos, $level, $id, $reason) = @_;
  if (! defined($gecos)) {
    $gecos = "NOT_DEFINED";
  }
  my $dbh = $self->{DBH};
  $dbh->do("INSERT INTO $self->{TABLE} (channel, nick, user, host, gecos, level, id, reason) VALUES (" .
             $dbh->quote($channel) . ", " . $dbh->quote($nick) . ", " . $dbh->quote($user) .
             ", " . $dbh->quote($host) . ", " . $dbh->quote($gecos) . ", " . $dbh->quote($level) . ", " .
             $dbh->quote($id) . ", " . $dbh->quote($reason) . ");");
}

#FIXME: This function is shit. Also, it doesn't work like I want it to with mode.
sub logg
{
  my $self = shift;
  my ($event) = @_;
  my $dbh = $self->{DBH_LOG};
  my $table = $event->{type};
  $table = 'action' if ($table eq 'caction');
  $table = 'privmsg' if ($table eq 'public');
  my $realtable = $table;
  $realtable = 'joins' if $realtable eq 'join'; #mysql doesn't like a table named join
  my $string = 'INSERT INTO `' . $realtable . '` (';
  if (($table ne 'nick') && ($table ne 'quit')) {
    $string = $string . 'channel, ';
  }
  $string = $string . 'nick, user, host, geco';
  if (($table ne 'join') && ($table ne 'kick')) {
    $string = $string . ', content1';
  }
  if ($table eq 'mode') {
    $string = $string . ', content2';
  }
  if ($table eq 'kick') {
    $string = $string . ', victim_nick, victim_user, victim_host, victim_geco, content1';
  }
  $string = $string . ') VALUES (';
  if (($table ne 'nick') && ($table ne 'quit') && ($table ne 'kick')) {
    $string = $string . $dbh->quote($event->{to}->[0]) . ", ";
  }
  if ($table eq 'kick') {
    $string = $string . $dbh->quote($event->{args}->[0]) . ", ";
  }
  my $geco = $::sn{lc $event->{nick}}->{gecos};
  $string = $string . $dbh->quote($event->{nick}) . ", " . $dbh->quote($event->{user}) . ", " .
                      $dbh->quote($event->{host}) . ", " . $dbh->quote($geco);
  if (($table ne 'join') && ($table ne 'kick')) {
    $string = $string. ', ' . $dbh->quote($event->{args}->[0]);
  }
  if ($table eq 'kick') {
    $string = $string . ', ' . $dbh->quote($event->{to}->[0]);
    $string = $string . ', ' . $dbh->quote($::sn{lc $event->{to}->[0]}->{user});
    $string = $string . ', ' . $dbh->quote($::sn{lc $event->{to}->[0]}->{host});
    $string = $string . ', ' . $dbh->quote($::sn{lc $event->{to}->[0]}->{gecos});
    $string = $string . ', ' . $dbh->quote($event->{args}->[1]);
  }
  if ($table eq 'mode') {
    $string = $string . ', ' . $dbh->quote($event->{args}->[1]);
  }
  $string = $string . ');';
  print $string . "\n" if $::debug;
  $dbh->do($string);
}
  
sub query
{
  my $self = shift;
  my ($channel, $nick, $user, $host) = @_;
  my $dbh = $self->{DBH};
  $channel = $dbh->quote($channel);
  $nick    = $dbh->quote($nick);
  $user    = $dbh->quote($user);
  $host    = $dbh->quote($host);

  $nick =~  s/\*/%/g;
  $nick =~ s/_/\\_/g;
  $nick =~  s/\?/_/g;

  $user =~  s/\*/%/g;
  $user =~ s/_/\\_/g;
  $user =~  s/\?/_/g;

  $host =~  s/\*/%/g;
  $host =~ s/_/\\_/g;
  $host =~  s/\?/_/g;
  my $sth = $dbh->prepare("SELECT * from $self->{TABLE} WHERE channel = $channel and nick like $nick and user like $user and host like $host;");
  $sth->execute;
  my $i = 0;
  while (my $ref = $sth->fetchrow_arrayref) {
    $i++;
  }
  return $i;
}
  
1;
