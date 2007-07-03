use warnings;
use strict;

package ASM::Log;

#use String::Interpolate qw(interpolate);
use IO::All;
use POSIX qw(strftime);
use Data::Dumper;

sub new
{
  my $module = shift;
  my $config = shift;
  my $self = {};
  $self->{CONFIG} = $config;
  $self->{MD} = {};
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
    unless (defined($self->{MD}->{$chan}) && ($self->{MD}->{$chan} == 1)) {
      io($cfg->{dir} . $chan)->mkpath;
      $self->{MD}->{$chan} = 1;
    }
    $_='';
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
    print Dumper($event) if ($_ eq '');
    $_ = strftime($cfg->{timefmt}, @time) . $_ . "\n" unless $_ eq '';
    $_ >> io($cfg->{dir} . $chan . '/' . $chan . strftime($cfg->{filefmt}, @time)) unless ($_ eq '');
  }
}

return 1;
