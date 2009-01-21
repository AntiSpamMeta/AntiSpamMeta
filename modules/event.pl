package ASM::Event;
use warnings;
use strict;

use Data::Dumper;
use Text::LevenshteinXS qw(distance);
use IO::All;

sub cs {
  my ($chan) = @_;
  $chan = lc $chan;
  return $::channels->{channel}->{$chan} if ( defined($::channels->{channel}->{$chan}) );
  return $::channels->{channel}->{default};
}

sub maxlen {
  my ($a, $b) = @_;
  my ($la, $lb) = (length($a), length($b));
  return $la if ($la > $lb);
  return $lb;
}

sub new
{
  my $module = shift;
  my ($conn, $inspector) = @_;
  my $self = {};
  $self->{CONN} = $conn;
  $self->{INSPECTOR} = $inspector;
  print "Installing handler routines...\n";
  $conn->add_default_handler(\&blah);
  $conn->add_handler('bannedfromchan', \&on_bannedfromchan);
  $conn->add_handler('mode', \&on_mode);
  $conn->add_handler('join', \&on_join);
  $conn->add_handler('part', \&on_part);
  $conn->add_handler('quit', \&on_quit);
  $conn->add_handler('nick', \&on_nick);
  $conn->add_handler('notice', \&on_notice);
  $conn->add_handler('caction', \&on_public);
  $conn->add_handler('msg', \&on_msg);
  $conn->add_handler('namreply', \&on_names);
  $conn->add_handler('endofnames', \&on_names);
  $conn->add_handler('public', \&on_public);
  $conn->add_handler('376', \&on_connect);
  $conn->add_handler('topic', \&irc_topic);
  $conn->add_handler('topicinfo', \&irc_topic);
  $conn->add_handler('nicknameinuse', \&on_errnickinuse);
  $conn->add_handler('kick', \&on_kick);
  $conn->add_handler('cping', \&on_ctcp);
  $conn->add_handler('cversion', \&on_ctcp);
  $conn->add_handler('csource', \&on_ctcp_source);
  $conn->add_handler('ctime', \&on_ctcp);
  $conn->add_handler('cdcc', \&on_ctcp);
  $conn->add_handler('cuserinfo', \&on_ctcp);
  $conn->add_handler('cclientinfo', \&on_ctcp);
  $conn->add_handler('cfinger', \&on_ctcp);
  $conn->add_handler('320', \&whois_identified);
  $conn->add_handler('318', \&whois_end);
  $conn->add_handler('311', \&whois_user);
  $conn->add_handler('352', \&on_whoreply);
  bless($self);
  return $self;
}
  
sub on_connect {
  my ($conn, $event) = @_; # need to check for no services
  $conn->privmsg( 'NickServ', "ghost $::settings->{nick} $::settings->{pass}" ) if lc $event->{args}->[0] ne lc $::settings->{nick};
}

sub on_join {
  my ($conn, $event) = @_;
  my %evcopyx = %{$event};
  my $evcopy = \%evcopyx;
  my $nick = lc $event->{nick};
  my $chan = lc $event->{to}->[0];
  if ( lc $conn->{_nick} eq lc $nick)  {
    $::sc{$chan} = {};
    mkdir($::settings->{log}->{dir} . $chan);
    $conn->sl("who $chan");
    $conn->privmsg('ChanServ', "op $chan" ) if (defined cs($chan)->{op}) && (cs($chan)->{op} eq 'yes');
    #TODO: make it settable via config. Hardcoded channames ftl.
    if ($chan eq '##linux') {
      $conn->schedule(300, \&do_chancount, $chan, 300);
      #TODO: mark this as a channel we're watching so we don't schedule this multiple times
    }
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
    $::inspector->inspect( $conn, $event );
    $::db->logg($event);
  } else {
    $::sn{$nick} = {};
    $::sn{$nick}->{mship} = [ $chan ];
    if (defined($::needgeco{$nick})) {
      $::needgeco{$nick} = [ @{$::needgeco{$nick}}, $evcopy ];
      $::db->logg($event);
    } else {
      $::needgeco{$nick} = [ $evcopy ];
      $conn->sl("whois $nick");
    }
  }   
  $::log->logg( $event );
}
	
sub on_part
{
  my ($conn, $event) = @_;
  $::inspector->inspect( $conn, $event );
  my $nick = lc $event->{nick};
  $::log->logg( $event );
  $::db->logg( $event );
  if (defined($::sn{$nick}) && defined($::sn{$nick}->{mship})) {
    my @mship = @{$::sn{$nick}->{mship}};
    @mship = grep { lc $_ ne lc $event->{to}->[0] } @mship;
    if ( @mship ) {
      $::sn{$nick}->{mship} = \@mship;
    } else {
      delete($::sn{$nick});
    }
  }
  if ( lc $conn->{_nick} eq lc $nick )
  {
    delete( $::sc{lc $event->{to}->[0]} );
    on_byechan(lc $event->{to}->[0]);
  }
  else
  {
    delete( $::sc{lc $event->{to}->[0]}{users}{$nick} );
  }
}

sub on_msg
{
  my ($conn, $event) = @_;
  $::commander->command($conn, $event);
}

sub on_public
{
  my ($conn, $event) = @_;
  $::inspector->inspect( $conn, $event );
  $::log->logg( $event );
  $::db->logg( $event );
  $::commander->command( $conn, $event );
}

sub on_notice
{
  my ($conn, $event) = @_;
  return if ( $event->{to}->[0] eq '$*' );
  $::inspector->inspect( $conn, $event );
  $::log->logg( $event );
  $::db->logg( $event );
  $::services->doServices($conn, $event);
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
  $::db->logg( $event );
  delete($::sn{lc $event->{nick}});
  $::inspector->inspect( $conn, $event );
  $::log->logg( $event );
}

sub blah
{
  my ($self, $event) = @_;
  $::inspector->inspect($self, $event);
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
  $::inspector->inspect($conn, $event) if ($event->{format} ne 'server');
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
    $::db->logg( $event );
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
  $::db->logg( $event );
  delete( $::sn{lc $event->{nick}});
  $event->{to} = \@channels;
  $::inspector->inspect($conn, $event);
  $::log->logg($event);
}

sub on_kick {
  my ($conn, $event) = @_;
  if (lc $event->{to}->[0] eq lc $::settings->{nick}) {
    $conn->join($event->{args}->[0]);
  }
  my $nick = lc $event->{to}->[0];
  $::log->logg( $event );
  $::db->logg( $event );
  if (defined($::sn{$nick}) && defined($::sn{$nick}->{mship})) {
    my @mship = @{$::sn{$nick}->{mship}};
    @mship = grep { lc $_ ne lc $event->{to}->[0] } @mship;
    if ( @mship ) {
      $::sn{$nick}->{mship} = \@mship;
    } else {
      delete($::sn{$nick});
    }
  }
  if ( lc $conn->{_nick} eq lc $nick )
  {
    delete( $::sc{lc $event->{args}->[0]} );
    on_byechan(lc $event->{to}->[0]);
  }
  else
  {
    delete( $::sc{lc $event->{args}->[0]}{users}{$nick} );
  }
}

sub parse_modes
{
  my ( $n ) = @_;
  my @args = @{$n};
  my @modes = split '', shift @args;
  my @new_modes=();
  my $t;
  foreach my $c ( @modes ) {
    if (($c eq '-') || ($c eq '+')) {
      $t=$c;
    }
    else {
      if ( defined( grep( /[abdefhIJkloqv]/,($c) ) ) ) { #modes that take args
        push (@new_modes, [$t.$c, shift @args]);
      }
      elsif ( defined( grep( /[cgijLmnpPQrRstz]/, ($c) ) ) ) {
        push (@new_modes, [$t.$c]);
      }
      else {
        die "Unknown mode $c !\n";
      }
    }
  }
  return \@new_modes;
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
          $::oq->doQueue($conn, $chan);
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
  $::inspector->inspect($conn, $event);
}

sub on_ctcp_source
{
  my ($conn, $event) = @_;
  if (lc $event->{args}->[0] eq lc $conn->{_nick}) {
    $conn->ctcp_reply($event->{nick}, 'SOURCE http://svn.linuxrulz.org/repos/antispammeta/trunk/');
  }
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
      $::inspector->inspect($conn, $event);
      $::db->logg( $event );
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

sub on_byechan {
  my ($chan) = @_;
  #TODO do del event stuff
}

sub do_chancount {
  my ($conn, $chan, $repeat) = @_;
  my @users = keys(%{$::sc{$chan}{users}});
  my $count = @users;
  system('/home/icxcnika/AntiSpamMeta/chancount.pl ' . $chan . sprintf(' %d', $count));
  $conn->schedule($repeat, \&do_chancount, $chan, $repeat);
}

return 1;
