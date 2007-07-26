package ASM::Actions;
use strict;
use warnings;

sub new
{
  my $module = shift;
  my $self = {};
  my $tbl = {
    "ban" => \&ban,
    "kban" => \&kban,
    "kick" => \&kick,
    "none" => \&none,
   "quiet" => \&quiet,
  };
  $self->{ftbl} = $tbl;
  bless($self);
  return $self;
}

sub do
{
  my $self = shift;
  my $item = shift;
  return $self->{ftbl}->{$item}->(@_);
}

sub ban {
  my ($conn, $event, $chan) = @_;
  $::oq->o_send( $conn, "mode $chan +b *!*\@$event->{host}" );
  return "mode $chan -b *!*\@$event->{host}";
}

sub kban {
  my ($conn, $event, $chan) = @_;
  $::oq->o_send($conn, "mode $chan +b *!*\@$event->{host}");
  $::oq->o_send($conn, "kick $chan $event->{nick} :Spamming");
  return "mode $chan -b *!*\@$event->{host}";
}

sub kick {
  my ($conn, $event, $chan) = @_;
  $::oq->o_send($conn, "kick $chan $event->{nick} :Spamming");
  return "";
}

sub none {
  return "";
}

sub quiet {
  my ($conn, $event, $chan) = @_;
  $::oq->o_send( $conn, "mode $chan +b %*!*\@$event->{host}" );
  return "mode $chan -b %*!*\@$event->{host}";
}

1;
