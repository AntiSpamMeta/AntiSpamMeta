package ASM::Services;
use warnings;
use strict;

use Data::Dumper;
$Data::Dumper::Useqq=1;

sub new
{
  my $self = {};
  bless($self);
  return $self;
}

sub doServices {
  my ($self, $conn, $event) = @_;
  my $i = 1;
  if ($event->{from} eq 'NickServ!NickServ@services.')
  {
    ASM::Util->dprint("NickServ: $event->{args}->[0]", 'snotice');
    if ( $::no_autojoins && $event->{args}->[0] =~ /^Please identify/ )
    {
      $::no_autojoins = 0;
      $conn->sl("NickServ identify $::settings->{nick} $::settings->{pass}" );
    }
    elsif ( $event->{args}->[0] =~ /^You are now identified/ )
    {
      my @autojoins = @{$::settings->{autojoins}};
      if (defined($autojoins[30])) {
        $conn->join(join(',', @autojoins[0..30]));
        if (defined($autojoins[60])) {
          $conn->join(join(',', @autojoins[30..60]));
          $conn->join(join(',', @autojoins[60..$#autojoins]));
        } else {
          $conn->join(join(',', @autojoins[30..$#autojoins]));
        }
      } else {
        $conn->join(join(',', @autojoins));
      }
      $conn->sl("PING :" . time);
      foreach my $chan (@autojoins[0..1]) {
        ASM::Util->dprint("Syncing $chan", "sync");
        $conn->sl('who ' . $chan . ' %tcnuhra,314');
        $conn->sl('mode ' . $chan);
        $conn->sl('mode ' . $chan . ' b');
      }
        @::syncqueue = @autojoins[1..$#autojoins];
#      $conn->schedule(2, sub { $conn->privmsg($::settings->{masterchan}, 'Now joined to all channels in '. (time - $::starttime) . " seconds."); });
    }
    elsif ($event->{args}->[0] =~ /has been (killed|released)/ )
    {
      ASM::Util->dprint('Got kill/release successful from NickServ!', 'snotice');
      $conn->nick( $::settings->{nick} );
    }
    elsif ($event->{args}->[0] =~ /has been regained/ )
    {
      ASM::Util->dprint('Got regain successful from nickserv!', 'snotice');
    }
    elsif ($event->{args}->[0] =~ /Password Incorrect/ )
    {
      die("NickServ password invalid.")
    }
    elsif ($event->{args}->[0] =~ /frozen/ )
    {
      $::no_autojoins = 1;
      $conn->join($::settings->{masterchan}); # always join masterchan, so we can find you
      $conn->sl("PING :" . time);
    }
  }
  elsif ($event->{from} eq 'ChanServ!ChanServ@services.')
  {
    if ( $event->{args}->[0] =~ /^\[#/ ) {
      return;
    }
    ASM::Util->dprint("ChanServ: $event->{args}->[0]", 'snotice');
    if ( $event->{args}->[0] =~ /^All.*bans matching.*have been cleared on(.*)/)
    {
      $conn->join($1);
    }
  }
}

return 1;
