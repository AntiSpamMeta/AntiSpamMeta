use warnings;
use strict;
use DBI;

sub sql_connect
{
  $::dbh = DBI->connect("DBI:mysql:database=$::mysql->{db};host=$::mysql->{host};port=$::mysql->{port}",
                        $::mysql->{user}, $::mysql->{pass});
  $::dbh->{mysql_auto_reconnect} = 1;
}

sub sql_record
{
  my ($channel, $nick, $user, $host, $gecos, $level, $id, $reason) = @_;
  $::dbh->do("INSERT INTO $::mysql->{table} (channel, nick, user, host, gecos, level, id, reason) VALUES (" .
             $::dbh->quote($channel) . ", " . $::dbh->quote($nick) . ", " . $::dbh->quote($user) .
             ", " . $::dbh->quote($host) . ", " . $::dbh->quote($gecos) . ", " . $::dbh->quote($level) . ", " .
             $::dbh->quote($id) . ", " . $::dbh->quote($reason) . ");");
}

sub sql_query
{
  my ($channel, $nick, $user, $host) = @_;
  $channel = $::dbh->quote($channel);
  $nick    = $::dbh->quote($nick);
  $user    = $::dbh->quote($user);
  $host    = $::dbh->quote($host);

  $nick =~  s/\*/%/g;
  $nick =~ s/_/\\_/g;
  $nick =~  s/\?/_/g;

  $user =~  s/\*/%/g;
  $user =~ s/_/\\_/g;
  $user =~  s/\?/_/g;

  $host =~  s/\*/%/g;
  $host =~ s/_/\\_/g;
  $host =~  s/\?/_/g;
  my $sth = $::dbh->prepare("SELECT * from $::mysql->{table} WHERE channel = $channel and nick like $nick and user like $user and host like $host;");
  $sth->execute;
  my $i = 0;
  while (my $ref = $sth->fetchrow_arrayref) {
    $i++;
  }
  return $i;
}
  
1;
