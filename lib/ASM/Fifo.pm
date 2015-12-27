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
  sysopen( my $fifo, "fifo", O_NONBLOCK );
  $self->{fifo} = $fifo;
  bless($self);
  $self->{irc}->addfh( $self->{fifo}, sub { $self->process(@_); }, 'r' );
  return $self;
}

sub process
{
  my ($self, $fifo) = @_;
  my $line = readline($fifo);
  return unless defined($line);
  chomp $line;
  $self->{conn}->privmsg($::settings->{masterchan}, $line);
}

1;
