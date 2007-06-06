use warnings;
use strict;

use String::Interpolate qw(interpolate);

sub logg
{
  my ($event) = @_;
  my @chans = @{$event->{to}};
  my $fh;
  @chans = ( $event->{args}->[0] ) if ($event->{type} eq 'kick');
  my @time = ($::settings->{log}->{zone} eq 'local') ? localtime : gmtime;
  foreach my $chan ( @chans)
  {
    $chan = lc $chan;
    io(interpolate($::settings->{log}->{dir}))->mkpath;
    $_='';
    $_ =    "<$event->{nick}> $event->{args}->[0]"                     if $event->{type} eq 'public';
    $_ = "*** $event->{nick} has joined $chan"                         if $event->{type} eq 'join';
    $_ = "*** $event->{nick} has left $chan"                           if $event->{type} eq 'part';
    $_ =   "* $event->{nick} $event->{args}->[0]"                      if $event->{type} eq 'caction';
    $_ = "*** $event->{nick} is now known as $event->{args}->[0]"      if $event->{type} eq 'nick';
    $_ = "*** $event->{nick} has quit IRC"                             if $event->{type} eq 'quit';
    $_ = "*** $event->{to}->[0] was kicked by $event->{nick}"          if $event->{type} eq 'kick';
    $_ =    "-$event->{nick}- $event->{args}->[0]"                     if $event->{type} eq 'notice';
    $_ = "*** $event->{nick} sets mode: ".join(" ",@{$event->{args}})  if $event->{type} eq 'mode';
    $_ = "*** $event->{nick} changes topic to \"$event->{args}->[0]\"" if $event->{type} eq 'topic';
    print Dumper($event) if ($_ eq '');
    $_ = interpolate(strftime($::settings->{log}->{timefmt}, @time)) . $_ . "\n" unless $_ eq '';
    $_ >> io(interpolate($::settings->{log}->{dir}).'/'.interpolate(strftime($::settings->{log}->{filefmt}, @time))) unless ($_ eq '');
  }
}

sub Log::killsub {
  undef &logg;
}

return 1;
