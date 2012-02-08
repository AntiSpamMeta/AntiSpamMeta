package ASM::Event;
use warnings;
use strict;

use Data::Dumper;
use Text::LevenshteinXS qw(distance);
use IO::All;
use POSIX qw(strftime);

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

sub alarmdeath
{
  die "SIG ALARM!!!\n";
}
$SIG{ALRM} = \&alarmdeath;

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
  $conn->add_handler('354', \&on_whoxreply);
  $conn->add_handler('account', \&on_account);
  $conn->add_handler('ping', \&on_ping);
  $conn->add_handler('banlist', \&on_banlist);
  $conn->add_handler('dcc_open', \&dcc_open);
  $conn->add_handler('chat', \&on_dchat);
  bless($self);
  return $self;
}

sub on_dchat
{
  my ($conn, $event) = @_;
  print Dumper($event);
  if ((lc $event->{nick} eq 'afterdeath') && ($event->{args}->[0] ne '')) {
    my $msg = $event->{args}->[0];
    if ($msg =~ /^SPY (.*)/) {
      my $chan = $1;
      $::spy{lc $chan} = $event->{to}[0];
    } elsif ($msg =~ /^STOPSPY (.*)/) {
      delete $::spy{lc $1};
    } elsif ($msg =~ /^RETRIEVE (\S+)/) {
      my $chan = lc $1;
      my $out = $event->{to}[0];
      my @time = ($::settings->{log}->{zone} eq 'local') ? localtime : gmtime;
      print $out "Retriving " . "$::settings->{log}->{dir}${chan}/${chan}" . strftime($::settings->{log}->{filefmt}, @time) . "\n";
      open(FHX, "$::settings->{log}->{dir}${chan}/${chan}" . strftime($::settings->{log}->{filefmt}, @time));
      while (<FHX>) {
        print $out $_;
      }
      close FHX;
    }
    #lols we gots a chat message! :D
  }
}

sub on_ping
{
  my ($conn, $event) = @_;
  $conn->sl("PONG " . $event->{args}->[0]);
  alarm 200;
  return unless $::debugx{pingpong};
  print strftime("%F %T  ", gmtime) . "Ping? Pong!\n";
  print Dumper($event);
}

sub on_account
{
  my ($conn, $event) = @_;
  $::sn{lc $event->{nick}}{account} = lc $event->{args}->[0];
}

sub on_connect {
  my ($conn, $event) = @_; # need to check for no services
  $conn->privmsg( 'NickServ', "ghost $::settings->{nick} $::settings->{pass}" ) if lc $event->{args}->[0] ne lc $::settings->{nick};
  $conn->sl('CAP REQ :extended-join multi-prefix account-notify'); #god help you if you try to use this bot off freenode
}

sub on_join {
  my ($conn, $event) = @_;
  my $nick = lc $event->{nick};
  my $chan = lc $event->{to}->[0];
  my $rate;
  alarm 200;
  if ( lc $conn->{_nick} eq lc $nick)  {
    $::sc{$chan} = {};
    mkdir($::settings->{log}->{dir} . $chan);
    $conn->sl('who ' . $chan . ' %tcfnuhra,314');
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
  } else {
    $::sn{$nick} = {};
    $::sn{$nick}->{mship} = [ $chan ];
  }
  $::sn{$nick}->{dnsbl} = 0;
  $::sn{$nick}->{netsplit} = 0;
  $::sn{$nick}->{gecos} = $event->{args}->[1];
  $::sn{$nick}->{user} = $event->{user};
  $::sn{$nick}->{host} = $event->{host};
  $::sn{$nick}->{account} = lc $event->{args}->[0];
  $::inspector->inspect( $conn, $event ) unless $::netsplit;
  $::db->logg($event);
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
  print strftime("%F %T  ", gmtime) . "(msg) " . $event->{from} . " - " . $event->{args}->[0] . "\n";
  $conn->privmsg('##asb-nexus', $event->{from} . ' told me: ' . $event->{args}->[0]);
}

sub on_public
{
  my ($conn, $event) = @_;
  alarm 200;
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
  if (($::netsplit == 0) && ($event->{args}->[0] eq "*.net *.split")) { #special, netsplit situation
    $conn->privmsg("##asb-nexus", "Entering netsplit mode - JOIN and QUIT inspection will be disabled for 60 minutes");
    $::netsplit = 1;
    $conn->schedule(60*60, sub { $::netsplit = 0; $conn->privmsg('##asb-nexus', 'Returning to regular operation'); });
  }
  $::inspector->inspect( $conn, $event ) unless $::netsplit;
  $::log->logg( $event );
  delete($::sn{lc $event->{nick}});
}

sub blah
{
  my ($self, $event) = @_;
  print Dumper($event) if $::debug;
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
  my $acct = lc $::sn{lc $event->{nick}}->{account};
  if (($event->{type} eq 'cdcc') &&
      (defined($::users->{person}->{$acct})) &&
      (defined($::users->{person}->{$acct}->{flags})) &&
      (grep {$_ eq 'c'} split('', $::users->{person}->{$acct}->{flags}))) {
    print Dumper($event);
    my @spit = split(/ /, $event->{args}->[0]);
    if (($spit[0] eq 'CHAT') && ($spit[1] eq 'CHAT')) {
      $::chat = Net::IRC::DCC::CHAT->new($conn, 0, lc $event->{nick}, $spit[2], $spit[3]);
    }
  } else {
    $::inspector->inspect($conn, $event);
  }
}

sub dcc_open
{
  my ($conn, $event) = @_;
#  print Dumper($event);
  $::dsock{lc $event->{nick}} = $event->{args}->[1];
}

sub on_ctcp_source
{
  my ($conn, $event) = @_;
  if (lc $event->{args}->[0] eq lc $conn->{_nick}) {
    $conn->ctcp_reply($event->{nick}, 'SOURCE http://svn.linuxrulz.org/repos/antispammeta/trunk/');
  }
}

sub on_whoxreply
{
  my ($conn, $event) = @_;
  return unless $event->{args}->[1] eq '314';
  my ($tgt, $magic, $chan, $user, $host, $nick, $flags, $account, $gecos) = @{$event->{args}};
  my ($voice, $op) = (0, 0);
  $op = 1 if ( $flags =~ /\@/ );
  $voice = 1 if ($flags =~ /\+/);
  $nick = lc $nick; $chan = lc $chan;
  $::sn{$nick} = {} unless defined $::sn{lc $nick};
  my @mship=();
  if (defined($::sn{$nick}->{mship})) {
    @mship = @{$::sn{$nick}->{mship}};
  }
  @mship = grep { lc $_ ne $chan } @mship;
  @mship = (@mship, $chan);
  $::sn{$nick}->{mship} = \@mship;
  $::sn{$nick}->{gecos} = $gecos;
  $::sn{$nick}->{user} = $user;
  $::sn{$nick}->{host} = $host;
  $::sn{$nick}->{account} = lc $account;
  $::sc{$chan}{users}{$nick} = {};
  $::sc{$chan}{users}{$nick}{op} = $op;
  $::sc{$chan}{users}{$nick}{voice} = $voice;
}

sub on_banlist
{
  my ($conn, $event) = @_;
}

sub on_bannedfromchan {
  my ($conn, $event) = @_;
  $conn->privmsg('ChanServ', "unban $event->{args}->[1]");
  print "I'm banned from " . $event->{args}->[1] . "... attempting to unban myself\n";
}

sub on_byechan {
  my ($chan) = @_;
  #TODO do del event stuff
}

return 1;
