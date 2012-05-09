package ASM::Services;
use warnings;
use strict;

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
    print "NickServ: $event->{args}->[0]\n";
    if ( $event->{args}->[0] eq 'This nickname is registered' )
    {
      $conn->privmsg( 'NickServ', "identify $::settings->{pass}" );
    }
    elsif ( $event->{args}->[0] =~ /^You are now identified/ )
    {
      my @autojoins = @{$::settings->{autojoins}};
      while (@autojoins) {
        my $joinstr = join (',', shift @autojoins, shift @autojoins, shift @autojoins, shift @autojoins);
        $conn->schedule($i, sub { $conn->join($joinstr); });
        $i += 7;
      }
      $conn->schedule($i-6, sub { $conn->privmsg('#antispammeta', 'Now joined to all channels in '. (time - $::starttime) . " seconds."); });
    }
    elsif ($event->{args}->[0] =~ /has been killed$/ )
    {
      $conn->nick( $::settings->{nick} );
    }
    elsif ($event->{args}->[0] =~ /Password Incorrect/ )
    {
      die("NickServ password invalid.")
    }
  }
  elsif ($event->{from} eq 'ChanServ!ChanServ@services.')
  {
    print "ChanServ: $event->{args}->[0] \n";
    if ( $event->{args}->[0] =~ /^All.*bans matching.*have been cleared on(.*)/)
    {
      $conn->join($1);
    }
  }
}

return 1;
