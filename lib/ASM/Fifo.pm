package ASM::Fifo;

use warnings;
use strict;
use POSIX qw(mkfifo);
use Fcntl;

sub new
{
  my $module = shift;
  my @args = @_;
  my $self = {
               "irc" => $args[0],
               "conn" => $args[1]
  };
  mkfifo("fifo", 0777);
  open( my $fifo, "+<", "fifo" );
  $self->{fifo} = $fifo;
  bless($self);
  $self->{irc}->addfh( $self->{fifo}, $self->can('process'), 'r', $self );
  return $self;
}

sub process
{
  my ($self, $fifo) = @_;
  my $lines;
  $fifo->sysread($lines, 10240);
  foreach my $line (split /\n/, $lines) {
  $self->{conn}->privmsg($::settings->{masterchan}, $line); }
  return 0;
}

1;
