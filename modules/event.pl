use warnings;
use strict;

use Text::LevenshteinXS qw(distance);

sub on_connect {
  my ($conn, $event) = @_; # need to check for no services
  $conn->privmsg( 'NickServ', "ghost $::settings->{nick} $::pass" ) if lc $event->{args}->[0] ne lc $::settings->{nick};
}

my @leven = ();

sub on_join {
  my ($conn, $event) = @_;
  my %evcopyx = %{$event};
  my $evcopy = \%evcopyx;
  my $nick = lc $event->{nick};
  my $chan = lc $event->{to}->[0];
  if ( leq($conn->{_nick}, $nick) ) {
    $::sc{$chan} = {};
    $conn->sl("who $chan");
    $conn->privmsg('ChanServ', "op $chan" ) if (defined cs($chan)->{op}) && (cs($chan)->{op} eq 'yes');
  }
  $::sc{$chan}{users}{$nick} = {};
  $::sc{$chan}{users}{$nick}{hostmask} = $event->{userhost};
  $::sc{$chan}{users}{$nick}{op} = 0;
  $::sc{$chan}{users}{$nick}{voice} = 0;
  if (defined($::sn{$nick})) {
    my @mship = ();
    if (defined($::sn{$nick}->{mship})) {
      @mship = @{$::sn{$nick}->{mship}};
    }
    @mship = (@mship, $chan);
    $::sn{$nick}->{mship} = \@mship;
    inspect( $conn, $event );
  } else {
    $::sn{$nick} = {};
    $::sn{$nick}->{mship} = [ $chan ];
    if (defined($::needgeco{$nick})) {
      $::needgeco{$nick} = [ @{$::needgeco{$nick}}, $evcopy ];
    } else {
      $::needgeco{$nick} = [ $evcopy ];
      $conn->sl("whois $nick");
    }
  }   
  $::log->logg( $event );
  if ( $#leven ne -1 ) {
    my $ld = ( ( maxlen($nick, $leven[0]) - distance($nick, $leven[0]) ) / maxlen($nick, $leven[0]) );
    my $mx = $leven[0];
    foreach my $item ( @leven ) {
      next if $nick eq $item; # avoid dups
      my $tld = ( ( maxlen($nick, $item) - distance($nick, $item) ) / maxlen($nick, $item) );
      if ($tld > $ld) {
        $ld = $tld;
        $mx = $item;
      }
    }
    print "Best match for $nick was $mx with $ld\n"
  }
  push(@leven, $nick);
  shift @leven if $#leven > 5;
}
	
sub on_part
{
  my ($conn, $event) = @_;
  inspect( $conn, $event );
  my $nick = lc $event->{nick};
  $::log->logg( $event );
  if (defined($::sn{$nick}) && defined($::sn{$nick}->{mship})) {
    my @mship = @{$::sn{$nick}->{mship}};
    @mship = grep { lc $_ ne lc $event->{to}->[0] } @mship;
    if ( @mship ) {
      $::sn{$nick}->{mship} = \@mship;
    } else {
      delete($::sn{$nick});
    }
  }
  if ( leq( $conn->{_nick}, $nick ) )
  {
    delete( $::sc{lc $event->{to}->[0]} );
  }
  else
  {
    delete( $::sc{lc $event->{to}->[0]}{users}{$nick} );
  }
}

sub on_msg
{
  my ($conn, $event) = @_;
  do_command ($conn, $event)
}

sub on_public
{
  my ($conn, $event) = @_;
  inspect( $conn, $event );
  $::log->logg( $event );
  do_command( $conn, $event )
}

sub on_notice
{
  my ($conn, $event) = @_;
  inspect( $conn, $event );
  $::log->logg( $event );
  doServices($conn, $event);
}

sub on_errnickinuse
{
  my ($conn, $event) = @_;
  $_ = ${$::settings->{altnicks}}[rand @{$::settings->{altnicks}}];
  print "Nick is in use, trying $_\n";
  $conn->nick($_);
}

sub on_quit
{
  my ($conn, $event) = @_;
  my @channels=();
  for ( keys %::sc ) {
    push ( @channels, $_ ) if delete $::sc{lc $_}{users}{lc $event->{nick}};
  }
  $event->{to} = \@channels;
  delete($::sn{lc $event->{nick}});
  inspect( $conn, $event );
  $::log->logg ( $event );
}

sub blah
{
  my ($self, $event) = @_;
  inspect($self, $event);
}

sub irc_users
{
  my ( $channel, @users ) = @_;
  for (@users)
  {
    my ( $op, $voice );
    $op = 0; $voice = 0;
    $op = 1 if s/^\@//;
    $voice = 1 if s/^\+//;
    $::sc{lc $channel}{users}{lc $_} = {};
    $::sc{lc $channel}{users}{lc $_}{op} = $op;
    $::sc{lc $channel}{users}{lc $_}{voice} = $voice;
  }
}

sub on_names {
  my ($conn, $event) = @_;
  irc_users( $event->{args}->[2], split(/ /, $event->{args}->[3]) )  if ($event->{type} eq 'namreply');
}

sub irc_topic {
  my ($conn, $event) = @_;
  inspect($conn, $event) if ($event->{format} ne 'server');
  if ($event->{format} eq 'server')
  {
    if ($event->{type} eq 'topic')
    {
      $::sc{lc $event->{args}->[1]}{topic}{text} = $event->{args}->[2];
    }
    elsif ($event->{type} eq 'topicinfo')
    {
      $::sc{lc $event->{args}->[1]}{topic}{time} = $event->{args}->[3];
      $::sc{lc $event->{args}->[1]}{topic}{by} = $event->{args}->[2];
    }
  }
  else
  {
    if ($event->{type} eq 'topic')
    {
      $::sc{lc $event->{to}->[0]}{topic}{text} = $event->{args}->[0];
    }
    $::log->logg($event);
  }
}

sub on_nick {
  my ($conn, $event) = @_;
  my @channels=();
  for ( keys %::sc )
  {
    if ( defined $::sc{lc $_}{users}{lc $event->{nick}} )
    {
      $::sc{lc $_}{users}{lc $event->{args}->[0]} = $::sc{lc $_}{users}{lc $event->{nick}};
      delete( $::sc{lc $_}{users}{lc $event->{nick}} );
      push ( @channels, lc $_ );
    }
  }
  $::sn{lc $event->{args}->[0]} = $::sn{lc $event->{nick}};
  delete( $::sn{lc $event->{nick}});
  $event->{to} = \@channels;
  inspect($conn, $event);
  $::log->logg($event)
}

sub on_kick {
  my ($conn, $event) = @_;
  if (lc $event->{to}->[0] eq lc $::settings->{nick}) {
    $conn->join($event->{args}->[0]);
  }
  my $nick = lc $event->{to}->[0];
  $::log->logg( $event );
  my @mship = @{$::sn{$nick}->{mship}};
  @mship = grep { lc $_ ne lc $event->{args}->[0] } @mship;
  if ( @mship ) {
    $::sn{$nick}->{mship} = \@mship;
  } else {
    delete($::sn{$nick});
  }
  if ( leq( $conn->{_nick}, $nick ) )
  {
    delete( $::sc{lc $event->{args}->[0]} );
  }
  else
  {
    delete( $::sc{lc $event->{args}->[0]}{users}{$nick} );
  }
}

sub on_mode
{
  my ($conn, $event) = @_;
  my $chan = lc $event->{to}->[0];
  if ($chan =~ /^#/) {
    my @modes = @{parse_modes($event->{args})};
    foreach my $line ( @modes ) {
      my @ex = @{$line};
      if ( $ex[0] eq '+o' ) {
        $::sc{$chan}{users}{lc $ex[1]}{op}=1;
        if (lc $ex[1] eq lc $::settings->{nick}) {
          doQueue($conn, $chan);
          if ( $::channels->{channel}->{$chan}->{op} eq "when" ) {
            $conn->schedule(600, sub { print "Deop timer called!\n"; $conn->privmsg('ChanServ', "op $chan -". $::settings->{nick})});
          }
        }
      }
      elsif ( $ex[0] eq '-o' ) {
        $::sc{$chan}{users}{lc $ex[1]}{op}=0;
      }
      elsif ( $ex[0] eq '+v' ) {
        $::sc{$chan}{users}{lc $ex[1]}{voice}=1;
      }
      elsif ( $ex[0] eq '-v' ) {
        $::sc{$chan}{users}{lc $ex[1]}{voice}=0;
      }
    }
    $::log->logg($event);
  }
}

sub on_ctcp
{
  my ($conn, $event) = @_;
  inspect($conn, $event);
}

sub whois_identified {
  my ($conn, $event2) = @_;
  my $who = lc $event2->{args}->[1];
  if ( (defined( $::idqueue{$who} )) && ( @{$::idqueue{$who}} ) ) {
    foreach my $item (@{$::idqueue{$who}}) {
      my ($cmd, $command, $event) = @{$item};
      if ( $cmd =~ /$command->{cmd}/ ){
        print "$event->{from} told me $cmd \n";
        eval $command->{content};
	warn $@ if $@;
      }
    }
    $::idqueue{$who} = [];
  }
}

sub whois_end {
  my ($conn, $event) = @_;
  my $who = lc $event->{args}->[1];
  $::idqueue{$who} = [];
}

sub whois_user {
  my ($conn, $event2) = @_;
  my $lnick = lc $event2->{args}->[1];
  unless (defined($::sn{$lnick})) {
    $::sn{$lnick} = {};
  }
  $::sn{$lnick}->{gecos} = $event2->{args}->[5];
  $::sn{$lnick}->{user} = $event2->{args}->[2];
  $::sn{$lnick}->{host} = $event2->{args}->[3];
  if (defined( $::needgeco{$lnick} )) {
    foreach my $event (@{$::needgeco{$lnick}}) {
      inspect($conn, $event);
    }
    delete $::needgeco{$lnick};
  }
}

sub on_whoreply
{
  my ($conn, $event) = @_;
  my ($tgt, $chan, $user, $host, $server, $nick, $flags, $hops_and_gecos) = @{$event->{args}};
  my ($voice, $op) = (0, 0);
  my ($hops, $gecos);
  $op = 1 if ( $flags =~ /\@/ );
  $voice = 1 if ($flags =~ /\+/);
  if ($hops_and_gecos =~ /^(\d+) (.*)$/) {
    $hops = $1;
    $gecos = $2;
  } else {
    $hops = "0";
    $gecos = "";
  }
  $::sn{lc $nick} = {} unless defined $::sn{lc $nick};
  my @mship=();
  if (defined($::sn{lc $nick}->{mship})) {
    @mship = @{$::sn{lc $nick}->{mship}};
  }
  @mship = grep { lc $_ ne lc $chan } @mship;
  @mship = (@mship, $chan);
  $::sn{lc $nick}->{mship} = \@mship;
  $::sn{lc $nick}->{gecos} = $gecos;
  $::sn{lc $nick}->{user} = $user;
  $::sn{lc $nick}->{host} = $host;
  $::sc{lc $chan}{users}{lc $nick} = {};
  $::sc{lc $chan}{users}{lc $nick}{op} = $op;
  $::sc{lc $chan}{users}{lc $nick}{voice} = $voice;
}

sub on_bannedfromchan {
  my ($conn, $event) = @_;
  $conn->privmsg('ChanServ', "unban $event->{args}->[1]");
}

return 1;
