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

sub incident
{
  my $self = shift;
  my ($chan, $header) = @_;
  $chan = lc $chan;
  my $uuid = $self->{UUID}->create_str();
  open(FH, '>', $self->{CONFIG}->{detectdir} . $uuid . '.txt');
  print FH $header;
  if (defined($self->{backlog}->{$chan})) {
    print FH join('', @{$self->{backlog}->{$chan}});
  }
  print FH "\n\n";
  close(FH);
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
    if (open(FH, $path)) { # or die "Can't open $path: $!";
      print FH $line;
      ASM::Util->dprint($line, 'logger');
      close(FH);
    } else {
      print "COULDN'T PRINT TO $path - $line";
    }
    my $spy;
    if (defined($::spy{$chan})) {
      $spy = $::spy{$chan};
    } elsif (defined($::spy{lc $event->{nick}})) {
      $spy = $::spy{lc $event->{nick}};
    }
    if (defined($spy)) {
      say $spy "$chan: $nostamp";
    }
  }
}

1;
# vim: ts=2:sts=2:sw=2:expandtab
