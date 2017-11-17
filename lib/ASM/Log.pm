package ASM::Log;
no autovivification;

use warnings;
use strict;

use ASM::Util;
use POSIX qw(strftime);
use Data::UUID;

no if $] >= 5.017011, warnings => 'experimental::smartmatch';

sub new
{
  my $module = shift;
  my ($conn) = @_;
  my $self = {};
  $self->{CONFIG} = $::settings->{log};
  $self->{backlog} = {};
  $self->{CONN} = $conn;
  $self->{UUID} = Data::UUID->new;
  bless($self);
  mkdir($self->{CONFIG}->{dir});
  $conn->add_handler('public',    sub { logg($self, @_); }, "before");
  $conn->add_handler('join',      sub { logg($self, @_); }, "before");
  $conn->add_handler('part',      sub { logg($self, @_); }, "before");
  $conn->add_handler('caction',   sub { logg($self, @_); }, "before");
  $conn->add_handler('nick',      sub { logg($self, @_); }, "after"); #allow state tracking to molest this
  $conn->add_handler('quit',      sub { logg($self, @_); }, "after"); #allow state tracking to molest this too
  $conn->add_handler('kick',      sub { logg($self, @_); }, "before");
  $conn->add_handler('notice',    sub { logg($self, @_); }, "before");
  $conn->add_handler('mode',      sub { logg($self, @_); }, "before");
  $conn->add_handler('topic',     sub { logg($self, @_); }, "before");
  return $self;
}

sub actionlog
{
  my ($self, $event, $modedata1, $modedata2) = @_;
  my ($action, $reason, $channel,
        $nick,   $user,   $host,   $gecos,   $account, $ip,
      $bynick, $byuser, $byhost, $bygecos, $byaccount);
  my ($lcnick, $lcbynick);

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
      return if (($reason // '') =~ /Nickname regained by services/);
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
    $reason = $2 unless (lc $2 eq lc $event->{nick});
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
  $lcbynick = lc $bynick if defined $bynick; #we will lowercase the NUHGA info later.
  if ( (defined($bynick)) && (defined($::sn{$lcbynick})) ) { #we have the nick taking the action available, fill in missing NUHGA info
    $byuser //= $::sn{$lcbynick}{user};
    $byhost //= $::sn{$lcbynick}{host};
    $bygecos //= $::sn{$lcbynick}{gecos};
    $byaccount //= $::sn{$lcbynick}{account};
    if (($byaccount eq '0') or ($byaccount eq '*')) {
      $byaccount = undef;
    }
  }
  $lcnick = lc $nick if defined $nick;
  if ( (defined($nick)) && (defined($::sn{$lcnick})) ) { #this should always be true, else something has gone FUBAR
    $user //= $::sn{$lcnick}{user};
    $host //= $::sn{$lcnick}{host};
    $gecos //= $::sn{$lcnick}{gecos};
    $account //= $::sn{$lcnick}{account};
    if (($account eq '0') or ($account eq '*')) {
      $account = undef;
    }
    $ip = ASM::Util->getNickIP($lcnick);
  }

  return $::db->resultset('Actionlog')->create({
      action => $action,
      reason => $reason,
      channel => $channel,

      nick    => $nick,
      user    => $user,
      host    => $host,
      gecos   => $gecos,
      account => $account,
      ip      => $ip,

      bynick    => $bynick,
      byuser    => $byuser,
      byhost    => $byhost,
      bygecos   => $bygecos,
      byaccount => $byaccount,
    })->id if defined $::db;
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

sub incident
{
  my $self = shift;
  my ($chan, $nick, $user, $host, $gecos, $risk, $id, $reason) = @_;
  $chan = lc $chan;
  my $uuid = $self->{UUID}->create_str();

  my $is_opalert = ($risk eq 'opalert');

  my $header;
  if ($is_opalert) {
    $header = "$chan: $nick requested op attention\n";
  }
  else {
    $header = "$chan: $risk risk: $nick - $reason\n";
  }

  open(FH, '>', $self->{CONFIG}->{detectdir} . $uuid . '.txt');
  print FH $header;
  if (defined($self->{backlog}->{$chan})) {
    print FH join('', @{$self->{backlog}->{$chan}});
  }
  print FH "\n\n";
  close(FH);

  return $uuid if $is_opalert;

  $gecos //= "NOT_DEFINED";

  $::db->resultset('Alertlog')->create({
      channel => $chan,
      nick    => $nick,
      user    => $user,
      host    => $host,
      gecos   => $gecos,
      level   => $risk,
      id      => $id,
      reason  => $reason,
    }) if defined $::db;

  return $uuid;
}

#writes out the backlog to a file which correlates to ASM's SQL actionlog table
sub sqlIncident
{
  my $self = shift;
  my ($channel, $index) = @_;
  $channel = lc $channel;
  my @chans = split(/,/, $channel);
  open(FH, '>', $self->{CONFIG}->{actiondir} . $index . '.txt');
  foreach my $chan (@chans) {
    if (defined($self->{backlog}->{$chan})) {
      say FH "$chan";
      say FH join('', @{$self->{backlog}->{$chan}});
    }
  }
  close(FH);
}

sub logg
{
  my $self = shift;
  my ($conn, $event) = @_;
  my $cfg = $self->{CONFIG};
  my @chans = @{$event->{to}};
  @chans = ( $event->{args}->[0] ) if ($event->{type} eq 'kick');
  my @time = ($cfg->{zone} eq 'local') ? localtime : gmtime;
  foreach my $chan ( @chans )
  {
    $chan = lc $chan;
    next if ($chan eq '$$*');
    $chan =~ s/^[@+]//;
    if ($chan eq '*') {
      ASM::Util->dprint("$event->{nick}: $event->{args}->[0]", 'snotice');
      next;
    }
    my $path = ">>$cfg->{dir}${chan}/${chan}" . strftime($cfg->{filefmt}, @time);
    $_ = '';
    $_ =    "<$event->{nick}> $event->{args}->[0]"                      if $event->{type} eq 'public';
    $_ = "*** $event->{nick} has joined $chan"                          if $event->{type} eq 'join';
    $_ = "*** $event->{nick} has left $chan ($event->{args}->[0])"      if $event->{type} eq 'part';
    $_ =   "* $event->{nick} $event->{args}->[0]"                       if $event->{type} eq 'caction';
    $_ = "*** $event->{nick} is now known as $event->{args}->[0]"       if $event->{type} eq 'nick';
    $_ = "*** $event->{nick} has quit ($event->{args}->[0])"            if $event->{type} eq 'quit';
    $_ = "*** $event->{to}->[0] was kicked by $event->{nick}"           if $event->{type} eq 'kick';
    $_ =    "-$event->{nick}- $event->{args}->[0]"                      if $event->{type} eq 'notice';
    $_ = "*** $event->{nick} sets mode: " . join(" ",@{$event->{args}}) if $event->{type} eq 'mode';
    $_ = "*** $event->{nick} changes topic to \"$event->{args}->[0]\""  if $event->{type} eq 'topic';
    my $nostamp = $_;
    $_ = strftime($cfg->{timefmt}, @time) . $_ . "\n";
    my $line = $_;
    my @backlog = ();
    if (defined($self->{backlog}->{$chan})) {
      @backlog = @{$self->{backlog}->{$chan}};
      if (scalar @backlog >= 30) {
        shift @backlog;
      }
    }
    push @backlog, $line;
    $self->{backlog}->{$chan} = \@backlog;
  }
}

1;
# vim: ts=2:sts=2:sw=2:expandtab
