use strict;
use warnings;

#package Actions;

sub Actions::ban {
  our ($conn, $event, $unmode, $chan, %dct, $id);
  o_send( $conn, "mode $chan +b *!*\@$event->{host}" );
  $unmode="mode $chan -b *!*\@$event->{host}";
}

sub Actions::kban {
  our ($conn, $event, $unmode, $chan, %dct, $id);
  o_send($conn, "mode $chan +b *!*\@$event->{host}");
  o_send($conn, "kick $chan $event->{nick} :$dct{$id}{reason}");
  $unmode = "mode $chan -b *!*\@$event->{host}";
}

sub Actions::kick {
  our ($conn, $event, $unmode, $chan, %dct, $id);
  o_send($conn, "kick $chan $event->{nick} :$dct{$id}{reason}");
}

sub Actions::none {
  return;
}

sub Actions::quiet {
  our ($conn, $event, $unmode, $chan, %dct, $id);
  o_send( $conn, "mode $chan +b %*!*\@$event->{host}" );
  $unmode = "mode $chan -b %*!*\@$event->{host}";
}

sub Actions::fmod_wiki {
  our ($conn, $event, $unmode, $chan, %dct, $id);
  o_send( $conn, "mode $chan -b *!*\@$event->{host}" );
  o_send( $conn, "mode $chan +b *!*\@$event->{host}!#wikimedia-ops" );
}

sub Actions::killsub {
  undef &Actions::ban;
  undef &Actions::kban;
  undef &Actions::kick;
  undef &Actions::none;
  undef &Actions::quiet;
}

return 1;
