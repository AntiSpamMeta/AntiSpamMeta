package ASM::Services;
no autovivification;
use warnings;
use strict;

use Data::Dumper;
$Data::Dumper::Useqq=1;
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

sub new
{
  my $module = shift;
  my ($conn) = @_;
  my $self = {};
  $self->{CONN} = $conn;
  bless($self);
  $conn->add_handler('notice', \&doServices, "after");
  return $self;
}

sub doServices {
  my ($conn, $event) = @_;
  my $i = 1;
  if ($event->{from} eq ($::settings->{nickserv} // 'NickServ!NickServ@services.'))
  {
    ASM::Util->dprint("NickServ: $event->{args}->[0]", 'snotice');
    if ( $event->{args}->[0] =~ /^Please identify/ || $event->{args}->[0] =~ /^This nickname is registered/ )
    {
      $::no_autojoins = 0;
      $conn->sl("NickServ identify $::settings->{nick} $::settings->{account_pass}" );
    }
    elsif ( $event->{args}->[0] =~ /^You are now identified/ )
    {
      my $joinstring = "";
      foreach my $autojoin (@{$::settings->{autojoins}})
      {
        if ( length($joinstring) + length($autojoin) > 504 )
        {
          $conn->join($joinstring);
          $joinstring = "";
        }
        $joinstring .= ',' if length($joinstring);
        $joinstring .= "$autojoin";
      }
      $conn->join($joinstring) if length($joinstring);
      $conn->sl("PING :" . time);
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
    elsif ($event->{args}->[0] =~ /Invalid password/ )
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
  elsif ($event->{from} eq ($::settings->{chanserv} // 'ChanServ!ChanServ@services.'))
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
# vim: ts=2:sts=2:sw=2:expandtab
