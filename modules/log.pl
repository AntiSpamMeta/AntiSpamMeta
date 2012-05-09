package ASM::Log;

use warnings;
use strict;

#use IO::All;
use POSIX qw(strftime);

sub new
{
  my $module = shift;
  my $config = shift;
  my $self = {};
  $self->{CONFIG} = $config;
  bless($self);
  return $self;
}

sub logg
{
  my $self = shift;
  my ($event) = @_;
  my $cfg = $self->{CONFIG};
  my @chans = @{$event->{to}};
  @chans = ( $event->{args}->[0] ) if ($event->{type} eq 'kick');
  my @time = ($cfg->{zone} eq 'local') ? localtime : gmtime;
  foreach my $chan ( @chans )
  {
    $chan = lc $chan;
    next if ($chan eq '$$*');
    if (substr($chan, 0, 1) eq '@') {
      $chan = substr($chan, 1);
    }
    my $path = ">>$cfg->{dir}${chan}/${chan}" . strftime($cfg->{filefmt}, @time);
    $_ = '';
    $_ =    "<$event->{nick}> $event->{args}->[0]"                      if $event->{type} eq 'public';
    $_ = "*** $event->{nick} has joined $chan"                          if $event->{type} eq 'join';
    $_ = "*** $event->{nick} has left $chan"                            if $event->{type} eq 'part';
    $_ =   "* $event->{nick} $event->{args}->[0]"                       if $event->{type} eq 'caction';
    $_ = "*** $event->{nick} is now known as $event->{args}->[0]"       if $event->{type} eq 'nick';
    $_ = "*** $event->{nick} has quit IRC"                              if $event->{type} eq 'quit';
    $_ = "*** $event->{to}->[0] was kicked by $event->{nick}"           if $event->{type} eq 'kick';
    $_ =    "-$event->{nick}- $event->{args}->[0]"                      if $event->{type} eq 'notice';
    $_ = "*** $event->{nick} sets mode: " . join(" ",@{$event->{args}}) if $event->{type} eq 'mode';
    $_ = "*** $event->{nick} changes topic to \"$event->{args}->[0]\""  if $event->{type} eq 'topic';
    my $nostamp = $_;
    $_ = strftime($cfg->{timefmt}, @time) . $_ . "\n";
    my $line = $_;
    if (open(FH, $path)) { # or die "Can't open $path: $!";
      print FH $line;
      close(FH);
    } else {
      print "COULDN'T PRINT TO $path - $line";
    }
    if (defined($::spy{$chan})) {
      my $spy = $::spy{$chan};
      print $spy $chan .": " . $nostamp . "\n";
    }
    if (defined($::spy{lc $event->{nick}})) {
      my $spy = $::spy{lc $event->{nick}};
      print $spy $chan .": " . $nostamp . "\n";
    }
#    $_ >> io($path);
  }
}

1;
