use strict;
use warnings;

#package Actions;

sub Actions::ban {
  my ($conn, $event, $chan) = @_;
  $::oq->o_send( $conn, "mode $chan +b *!*\@$event->{host}" );
  return "mode $chan -b *!*\@$event->{host}";
}

sub Actions::kban {
  my ($conn, $event, $chan) = @_;
  $::oq->o_send($conn, "mode $chan +b *!*\@$event->{host}");
  $::oq->o_send($conn, "kick $chan $event->{nick} :Spamming");
  return "mode $chan -b *!*\@$event->{host}";
}

sub Actions::kick {
  my ($conn, $event, $chan) = @_;
  $::oq->o_send($conn, "kick $chan $event->{nick} :Spamming");
  return "";
}

sub Actions::none {
  return "";
}

sub Actions::quiet {
  my ($conn, $event, $chan) = @_;
  $::oq->o_send( $conn, "mode $chan +b %*!*\@$event->{host}" );
  return "mode $chan -b %*!*\@$event->{host}";
}

return 1;
