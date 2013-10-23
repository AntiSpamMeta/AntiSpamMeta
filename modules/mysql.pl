package ASM::DB;

use warnings;
use strict;
use DBI;
use Data::Dumper;

sub new {
  my $module = shift;
  my ($db, $host, $port, $user, $pass, $table, $actiontable, $dblog) = @_;
  my $self = {};
  $self->{DBH} = DBI->connect("DBI:mysql:database=$db;host=$host;port=$port", $user, $pass);
  $self->{DBH_LOG} = DBI->connect("DBI:mysql:database=$dblog;host=$host;port=$port", $user, $pass);
  $self->{DBH}->{mysql_auto_reconnect} = 1;
  $self->{DBH_LOG}->{mysql_auto_reconnect} = 1;
  $self->{TABLE} = $table;
  $self->{ACTIONTABLE} = $actiontable;
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

sub actionlog
{
  my ($self, $event, $modedata1, $modedata2) = @_;
  my $dbh = $self->{DBH};
  my ($action, $reason, $channel,
        $nick,   $user,   $host,   $gecos,   $account, $ip,
      $bynick, $byuser, $byhost, $bygecos, $byaccount);

  if ($event->{type} eq 'mode') {
    $action = $modedata1;
    $nick = $modedata2;
    $channel = lc $event->{to}->[0];
    $bynick = $event->{nick};
    $byuser = $event->{user};
    $byhost = $event->{host};
  } elsif ($event->{type} eq 'quit') {
    my $quitmsg = $event->{args}->[0];
    if ($quitmsg =~ /^Killed \((\S+) \((.*)\)\)$/) {
      $bynick = $1;
      $reason = $2 unless ($2 eq '<No reason given>');
      return if ($reason =~ /Nickname regained by services/);
      $action = 'kill';
    } elsif ($quitmsg =~ /^K-Lined$/) {
      $action = 'k-line';
    } else {
      return; #quit not forced/tracked
    }
    $nick = $event->{nick};
    $user = $event->{user};
    $host = $event->{host};
  } elsif (($event->{type} eq 'part') && ($event->{args}->[0] =~ /^requested by (\S+) \((.*)\)/)) {
    $bynick = $1;
    $reason = $2 unless (lc $reason eq lc $event->{nick});
    $action = 'remove';
    $nick = $event->{nick};
    $user = $event->{user};
    $host = $event->{host};
    $channel = $event->{to}->[0];
  } elsif ($event->{type} eq 'kick') {
    $action = 'kick';
    $bynick = $event->{nick};
    $byuser = $event->{user};
    $byhost = $event->{host};
    $reason = $event->{args}->[1] unless ($event->{args}->[1] eq $event->{to}->[0]);
    $nick = $event->{to}->[0];
    $channel = $event->{args}->[0];
  }
  return unless defined($action);
#  $bynick = lc $bynick if defined $bynick; #we will lowercase the NUHGA info later.
  if ( (defined($bynick)) && (defined($::sn{lc $bynick})) ) { #we have the nick taking the action available, fill in missing NUHGA info
    $byuser = $::sn{lc $bynick}{user} unless defined($byuser);
    $byhost = $::sn{lc $bynick}{host} unless defined($byhost);
    $bygecos = $::sn{lc $bynick}{gecos} unless defined($bygecos);
    $byaccount = $::sn{lc $bynick}{account} unless defined($byaccount);
    if (($byaccount eq '0') or ($byaccount eq '*')) {
      $byaccount = undef;
    }
  }
#  $nick = lc $nick if defined $nick;
  if ( (defined($nick)) && (defined($::sn{lc $nick})) ) { #this should always be true, else something has gone FUBAR
    $user = $::sn{lc $nick}{user} unless defined($user);
    $host = $::sn{lc $nick}{host} unless defined($host);
    $gecos = $::sn{lc $nick}{gecos} unless defined($gecos);
    $account = $::sn{lc $nick}{account} unless defined($account);
    if (($account eq '0') or ($account eq '*')) {
      $account = undef;
    }
    $ip = ASM::Util->getNickIP(lc $nick);
  }
#  my ($action, $reason, $channel,
#        $nick,   $user,   $host,   $gecos,   $account, $ip
#      $bynick, $byuser, $byhost, $bygecos, $byaccount);
#Now, time to escape/NULLify everything
  $action = $dbh->quote($action);
  if (defined($reason))  {  $reason = $dbh->quote($reason);     } else {  $reason = 'NULL'; }
## removed lc's from everything except IP
  if (defined($channel)) { $channel = $dbh->quote($channel); } else { $channel = 'NULL'; }

  if (defined($nick))    {    $nick = $dbh->quote($nick);    } else {    $nick = 'NULL'; }
  if (defined($user))    {    $user = $dbh->quote($user);    } else {    $user = 'NULL'; }
  if (defined($host))    {    $host = $dbh->quote($host);    } else {    $host = 'NULL'; }
  if (defined($gecos))   {   $gecos = $dbh->quote($gecos);   } else {   $gecos = 'NULL'; }
  if (defined($account)) { $account = $dbh->quote($account); } else { $account = 'NULL'; }
  if (defined($ip))      {      $ip = $dbh->quote($ip);         } else {      $ip = 'NULL'; }

  if (defined($bynick))    {    $bynick = $dbh->quote($bynick);    } else {    $bynick = 'NULL'; }
  if (defined($byuser))    {    $byuser = $dbh->quote($byuser);    } else {    $byuser = 'NULL'; }
  if (defined($byhost))    {    $byhost = $dbh->quote($byhost);    } else {    $byhost = 'NULL'; }
  if (defined($bygecos))   {   $bygecos = $dbh->quote($bygecos);   } else {   $bygecos = 'NULL'; }
  if (defined($byaccount)) { $byaccount = $dbh->quote($byaccount); } else { $byaccount = 'NULL'; }
  my $sqlstr = "INSERT INTO $self->{ACTIONTABLE} " .
           "(action, reason, channel, " .
           "nick, user, host, gecos, account, ip, " .
           "bynick, byuser, byhost, bygecos, byaccount)" .
           " VALUES " .
           "($action, $reason, $channel, " .
           "$nick, $user, $host, $gecos, $account, $ip, " .
           "$bynick, $byuser, $byhost, $bygecos, $byaccount);";
  ASM::Util->dprint( $sqlstr, 'mysql' );
  $dbh->do( $sqlstr );
  return $dbh->last_insert_id(undef, undef, $self->{ACTIONTABLE}, undef);
# $::sn{ow} looks like:
#$VAR1 = { 
#          "account" => "afterdeath",
#          "gecos" => "William Athanasius Heimbigner",
#          "user" => "icxcnika",
#          "mship" => [ 
#                       "#baadf00d",
#                       "#antispammeta-debug",
#                       "#antispammeta"
#                     ],
#          "host" => "freenode/weird-exception/network-troll/afterdeath"
#        };

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
  return if (($table eq 'action') or ($table eq 'privmsg')); #Disabling logging of privmsg stuffs to mysql. no point.
  my $realtable = $table;
  $realtable = 'joins' if $realtable eq 'join'; #mysql doesn't like a table named join
  my $string = 'INSERT INTO `' . $realtable . '` (';
## begin saner code for this function
  if ($table eq 'quit') {
    $string = 'INSERT INTO `quit` (nick, user, host, geco, ip, account, content1) VALUES (' .
           $dbh->quote($event->{nick}) . ',' . $dbh->quote($event->{user}) . ',' .
           $dbh->quote($event->{host}) . ',' . $dbh->quote($::sn{lc $event->{nick}}->{gecos}) . ',';
    my $ip = ASM::Util->getNickIP(lc $event->{nick});
    if (defined($ip)) { $ip = $dbh->quote($ip); } else { $ip = 'NULL'; }
    my $account = $::sn{lc $event->{nick}}->{account};
    if (($account eq '0') or ($account eq '*')) {
      $account = 'NULL';
    } else {
      $account = $dbh->quote($account);
    }
    $string = $string . $ip . ',' . $account . ',' . $dbh->quote($event->{args}->[0]) . ');';
    $dbh->do($string);
    ASM::Util->dprint($string, 'mysql');
    return;
  } elsif ($table eq 'part') {
    $string = 'INSERT INTO `part` (channel, nick, user, host, geco, ip, account, content1) VALUES (' .
              $dbh->quote($event->{to}->[0]) . ',' .
              $dbh->quote($event->{nick}) . ',' . $dbh->quote($event->{user}) . ',' .
              $dbh->quote($event->{host}) . ',' . $dbh->quote($::sn{lc $event->{nick}}->{gecos}) . ',';
    my $ip = ASM::Util->getNickIP(lc $event->{nick});
    if (defined($ip)) { $ip = $dbh->quote($ip); } else { $ip = 'NULL'; }
    my $account = $::sn{lc $event->{nick}}->{account};
    if (($account eq '0') or ($account eq '*')) {
      $account = 'NULL';
    } else {
      $account = $dbh->quote($account);
    }
    $string = $string . $ip . ',' . $account . ',' . $dbh->quote($event->{args}->[0]) . ');';
    $dbh->do($string);
    ASM::Util->dprint($string, 'mysql');
    return;
  } elsif ($table eq 'kick') {
    $string = 'INSERT INTO `kick` (channel, nick, user, host, geco, ip, account, ' . 
                      'victim_nick, victim_user, victim_host, victim_geco, victim_ip, victim_account, content1) VALUES (' .
              $dbh->quote($event->{args}->[0]) . ',' .
              $dbh->quote($event->{nick}) . ',' . $dbh->quote($event->{user}) . ',' .
              $dbh->quote($event->{host}) . ',' . $dbh->quote($::sn{lc $event->{nick}}->{gecos}) . ',';
    my $ip = ASM::Util->getNickIP(lc $event->{nick});
    if (defined($ip)) { $ip = $dbh->quote($ip); } else { $ip = 'NULL'; }
    my $account = $::sn{lc $event->{nick}}->{account};
    if (($account eq '0') or ($account eq '*')) { $account = 'NULL'; } else { $account = $dbh->quote($account); }
    $string = $string . $ip . ',' . $account;
    $string = $string . ', ' . $dbh->quote($event->{to}->[0]);
    $string = $string . ', ' . $dbh->quote($::sn{lc $event->{to}->[0]}->{user});
    $string = $string . ', ' . $dbh->quote($::sn{lc $event->{to}->[0]}->{host});
    $string = $string . ', ' . $dbh->quote($::sn{lc $event->{to}->[0]}->{gecos});
    my $vic_ip = ASM::Util->getNickIP(lc $event->{to}->[0]);
    if (defined($vic_ip)) { $vic_ip = $dbh->quote($vic_ip); } else { $vic_ip = 'NULL'; }
    my $vic_account = $::sn{lc $event->{to}->[0]}->{account};
    if (($vic_account eq '0') or ($vic_account eq '*')) { $vic_account = 'NULL'; } else { $vic_account = $dbh->quote($vic_account); }
    $string = $string . ', ' . $vic_ip . ',' . $vic_account . ',' . $dbh->quote($event->{args}->[1]) . ');';
    $dbh->do($string);
    ASM::Util->dprint($string, 'mysql');
    return;
  }
## end saner code for this function
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
#  ASM::Util->dprint($string, "mysql");
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
  my $sth = $dbh->prepare("SELECT * from $self->{TABLE} WHERE channel like $channel and nick like $nick and user like $user and host like $host;");
  $sth->execute;
  my $i = 0;
  while (my $ref = $sth->fetchrow_arrayref) {
    $i++;
  }
  return $i;
}
  
1;
