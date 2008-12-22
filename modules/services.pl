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
  if ($event->{from} eq 'NickServ!NickServ@services.')
  {
    print "NickServ: $event->{args}->[0]\n";
    if ( $event->{args}->[0] eq 'This nickname is registered' )
    {
      $conn->privmsg( 'NickServ', "identify $::settings->{pass}" );
    }
    elsif ( $event->{args}->[0] =~ /^You are now identified/ )
    {
      $conn->join($_) foreach ( @{$::settings->{autojoins}} );
    }
    elsif ($event->{args}->[0] =~ /has been killed$/ )
    {
      $conn->nick( $::settings->{nick} );
    }
    elsif ($event->{args}->[0] =~ /Password Incorrect/ )
    {
      $conn->join($_) foreach ( @{$::settings->{autojoins}} );
    }
  }
  elsif ($event->{from} eq 'ChanServ!ChanServ@services.')
  {
    print "ChanServ: $event->{args}->[0] \n";
    if ($event->{args}->[0] =~ /You are already opped on \[.(.*).\]/)
    {
      $::oq->doQueue($conn, $1);
    }
    elsif ( $event->{args}->[0] =~ /^All.*bans matching.*have been cleared on(.*)/)
    {
      $conn->join($1);
    }
  }
}

sub Services::killsub {
  undef &doServices;
}

return 1;
