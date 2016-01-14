package ASM::Event;
no autovivification;
use warnings;
use strict;

use Data::Dumper;
use IO::All;
use POSIX qw(strftime);
use Regexp::Wildcards;
use HTTP::Request;
use Array::Utils qw(:all);
use Net::DNS::Async;
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

sub new
{
  my $module = shift;
  my ($conn, $inspector) = @_;
  my $self = {};
  $self->{DNS} = Net::DNS::Async->new(QueueSize => 5000, Retries => 3);
  $self->{CONN} = $conn;
  $self->{INSPECTOR} = $inspector;
  ASM::Util->dprint('Installing handler routines...', 'startup');
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
  $conn->add_handler('bannickchange', \&on_bannickchange);
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
  $conn->add_handler('315', \&on_whoxover);
  $conn->add_handler('263', \&on_whofuckedup);
  $conn->add_handler('account', \&on_account);
  $conn->add_handler('ping', \&on_ping);
  $conn->add_handler('banlist', \&on_banlist);
  $conn->add_handler('dcc_open', \&dcc_open);
  $conn->add_handler('chat', \&on_dchat);
  $conn->add_handler('channelmodeis', \&on_channelmodeis);
  $conn->add_handler('quietlist', \&on_quietlist);
  $conn->add_handler('pong', \&on_pong);
  $conn->add_handler('statsdebug', \&on_statsdebug);
  $conn->add_handler('endofstats', \&on_endofstats);
  $conn->add_handler('channelurlis', \&on_channelurlis);
  $conn->add_handler('480', \&on_jointhrottled);
  $conn->add_handler('invite', \&blah); # This doesn't need to be fancy; I just need it to go through inspect
  $conn->add_handler('servicesdown', \&on_servicesdown);
  $conn->add_handler('endofbanlist', \&on_banlistend);
  $conn->add_handler('quietlistend', \&on_quietlistend);
  bless($self);
  return $self;
}

my $clearstatsp = 1;
my %statsp = ();
my %oldstatsp = ();

sub on_jointhrottled
{
  my ($conn, $event) = @_;
  my $chan = $event->{args}->[1];
  ASM::Util->dprint("$event->{nick}: $chan: $event->{args}->[2]", 'snotice');
  if ($event->{args}->[2] =~ /throttle exceeded, try again later/) {
    $conn->schedule(5, sub { $conn->join($chan); });
  }
}

sub on_statsdebug
{
  my ($conn, $event) = @_;
  my ($char, $line) = ($event->{args}->[1], $event->{args}->[2]);
  if ($char eq 'p') {
    if ($clearstatsp) {
      $clearstatsp = 0;
      %oldstatsp = %statsp;
      %statsp = ();
    }
    if ($line =~ /^(\d+) staff members$/) {
      #this is the end of the report
    } else {
      my ($nick, $userhost) = split(" ", $line);
      $userhost =~ s/\((.*)\)/$1/;
      my ($user, $host) = split("@", $userhost);
      $statsp{$nick}= [$user, $host];
    }
  }
}

sub on_endofstats
{
  my ($conn, $event) = @_;
  if ($event->{args}->[1] eq 'p') {
    $clearstatsp=1;
    my $tmp = Dumper(\%statsp); chomp $tmp;
    if ( join(',', sort(keys %oldstatsp)) ne join(',', sort(keys %statsp)) ) {
      open(FH, '>>', 'statsplog.txt');
      say FH strftime('%F %T ', gmtime) . join(',', sort(keys %statsp));
      close(FH);
      ASM::Util->dprint(join(",", keys %statsp), 'statsp');
    }
    # $event->{args}->[2] == "End of /STATS report"
    #end of /stats p
  }
}

my $lagcycles = 0;
my $pongcount = 0;

sub on_pong
{
  my ($conn, $event) = @_;
  alarm 120;
  $conn->schedule( 30, sub { $conn->sl("PING :" . time); } );
  ASM::Util->dprint('Pong? ... Ping!', 'pingpong');
  my $lag = time - $event->{args}->[0];
  my @changes = $::fm->scan();
  if (@changes) {
    if ($::settingschanged) {
      $::settingschanged = 0;
    } else {
      $conn->privmsg($::settings->{masterchan}, "Config files changed, auto rehash triggered. Check console for possible errors.");
      ASM::XML->readXML();
    }
  }
  if ($lag > 1) {
    ASM::Util->dprint("Latency: $lag", 'latency');
  }
  if (($pongcount++ % 3) == 0) { #easiest way to do something roughly every 90 seconds
    $conn->sl('STATS p');
  }
  if ( @::syncqueue || $::netsplit_ignore_lag || $::pendingsync) {
    return; #we don't worry about lag if we've just started up and are still syncing, or just experienced a netsplit
  }
  if (($lag > 2) && ($lag < 5)) {
    $conn->privmsg( $::settings->{masterchan}, "Warning: I'm currently lagging by $lag seconds.");
  }
  if ($lag >= 5) {
    $lagcycles++;
    if ($lagcycles >= 3) {
      $conn->quit("Automatic restart triggered due to persistent lag. Freenode staff: If this is happening too frequently, please " .
                  "set a nickserv freeze on my account, and once my connection is stable, unfreeze the account and /kill me to tri" .
                  "gger a reconnect.");
    } else {
      $conn->privmsg( $::settings->{masterchan}, "Warning: I'm currently lagging by $lag seconds. This marks heavy lag cycle " .
                      "$lagcycles - automatic restart will be triggered after 3 lag cycles." );
    }
  }
  if (($lag <= 5) && ($lagcycles > 0)) {
    $lagcycles--;
#    $conn->privmsg( $::settings->{masterchan}, "Warning: Heavy lag cycle count has been reduced to $lagcycles" );
    ASM::Util->dprint('$lag = ' . $lag . '; $lagcycles = ' . $lagcycles, 'latency');
  }
}

sub on_dchat
{
  my ($conn, $event) = @_;
  ASM::Util->dprint(Dumper($event), 'dcc');
  if ( #(lc $event->{nick} eq 'afterdeath') && 
      ($event->{args}->[0] ne '')) {
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
      say $out 'Retrieving ' . "$::settings->{log}->{dir}${chan}/${chan}" . strftime($::settings->{log}->{filefmt}, @time);
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
#  alarm 200;
  ASM::Util->dprint('Ping? Pong!', 'pingpong');
#  ASM::Util->dprint(Dumper($event), 'pingpong');
}

sub on_account
{
  my ($conn, $event) = @_;
  $::sn{lc $event->{nick}}{account} = lc $event->{args}->[0];
}

sub on_connect {
  my ($conn, $event) = @_; # need to check for no services
  $conn->sl("MODE $event->{args}->[0] +Q");
  if (lc $event->{args}->[0] ne lc $::settings->{nick}) {
    ASM::Util->dprint('Attempting to regain my main nick', 'startup');
    $conn->sl("NickServ regain $::settings->{nick} $::settings->{pass}");
  }# else {
#    $conn->sl("NickServ identify $::settings->{nick} $::settings->{pass}");
#  }
  $conn->sl('CAP REQ :extended-join multi-prefix account-notify'); #god help you if you try to use this bot off freenode
}

sub on_join {
  my ($conn, $event) = @_;
  my $nick = lc $event->{nick};
  my $chan = lc $event->{to}->[0];
  my $rate;
#  alarm 200;
  if ( lc $conn->{_nick} eq lc $nick)  {
    $::sc{$chan} = {};
    mkdir($::settings->{log}->{dir} . $chan);
    $::synced{$chan} = 0;
    $::pendingsync++;
    unless ( scalar @::syncqueue ) {
      ASM::Util->dprint("Syncing $chan", "sync");
      $conn->sl('who ' . $chan . ' %tcuihnar,314');
      $conn->sl('mode ' . $chan);
    }
    push @::syncqueue, $chan;
  }
  $::sc{$chan}{users}{$nick} = {};
  $::sc{$chan}{users}{$nick}{hostmask} = $event->{userhost};
  $::sc{$chan}{users}{$nick}{op} = 0;
  $::sc{$chan}{users}{$nick}{voice} = 0;
  $::sc{$chan}{users}{$nick}{jointime} = time;
  $::sc{$chan}{users}{$nick}{msgtime} = 0;
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
  $::db->logg($event) if defined $::db;
  $::log->logg( $event );
  $::inspector->inspect( $conn, $event ) unless $::netsplit;
}

sub on_part
{
  my ($conn, $event) = @_;
  my $nick = lc $event->{nick};
  my $chan = lc $event->{to}->[0];
  $::log->logg( $event );
  $::db->logg( $event ) if defined $::db;
  # Ignore channels that are +s and not monitored
  if (defined $::db and $event->{args}->[0] =~ /^requested by/ and (not ((grep { /^s$/ } @{$::sc{$chan}{modes}} ) && ($::channels->{channel}->{$chan}->{monitor} eq "no"))) ) {
    my $idx = $::db->actionlog( $event);
    $::log->sqlIncident($chan, $idx) if $idx;
  }
#                 "to" => [ "#antispammeta" ],
#                 "args" => [ "requested by ow (test)" ],
#                 "nick" => "aoregcdu",
  $::inspector->inspect( $conn, $event );
  if (defined($::sn{$nick}) && defined($::sn{$nick}->{mship})) {
    my @mship = @{$::sn{$nick}->{mship}};
    @mship = grep { lc $_ ne $chan } @mship;
    if ( @mship ) {
      $::sn{$nick}->{mship} = \@mship;
    } else {
      delete($::sn{$nick});
    }
  }
  if ( lc $conn->{_nick} eq $nick )
  {
    delete( $::sc{$chan} );
    on_byechan($chan);
  }
  else
  {
    delete( $::sc{$chan}{users}{$nick} );
  }
}

sub on_msg
{
  my ($conn, $event) = @_;
  $::commander->command($conn, $event);
  ASM::Util->dprint($event->{from} . " - " . $event->{args}->[0], 'msg');
  if ((ASM::Util->notRestricted($event->{nick}, "nomsgs")) && ($event->{args}->[0] !~ /^;;/)) {
# disabled by DL 130513 due to spammer abuse
#    $conn->privmsg($::settings->{masterchan}, $event->{from} . ' told me: ' . $event->{args}->[0]);
  }
}

sub on_public
{
  my ($conn, $event) = @_;
#  alarm 200;
  my $chan = lc $event->{to}[0];
  $chan =~ s/^[+@]//;
  $::log->logg( $event );
  $::db->logg( $event ) if defined $::db;
  if ($event->{args}->[0] =~ /(https?:\/\/bitly.com\/\w+|https?:\/\/bit.ly\/\w+|https?:\/\/j.mp\/\w+|https?:\/\/tinyurl.com\/\w+)/i) {
    my $reqid = $::async->add( HTTP::Request->new( GET => $1 ) );
    $::httpRequests{$reqid} = $event;
    my ($response, $id) = $::async->wait_for_next_response( 1 );
    if (defined($response)) {
      on_httpResponse($conn, $id, $response);
    }
    else { $conn->schedule( 1, sub { checkHTTP($conn); } ); }
  }
  $::inspector->inspect( $conn, $event );
  $::commander->command( $conn, $event );
  $::sc{$chan}{users}{lc $event->{nick}}{msgtime} = time;
}

sub checkHTTP
{
    my ($conn) = @_;
    my ($response, $id) = $::async->next_response();
    if (defined ($response)) {
      on_httpResponse($conn, $id, $response);
    }
    $conn->schedule( 1, sub { checkHTTP($conn); } );
}

sub on_httpResponse
{
  my ($conn, $id, $response) = @_;
  my $event = $::httpRequests{$id};
  delete $::httpRequests{$id};
  $::inspector->inspect( $conn, $event, $response );
}
#  if ($response->{_previous}->{_headers}->{location} =~ /^https?:\/\/bitly.com\/a\/warning/)

sub on_notice
{
  my ($conn, $event) = @_;
  return if ( $event->{to}->[0] eq '$*' ); # if this is a global notice FUCK THAT SHIT
  $::log->logg( $event );
  $::db->logg( $event ) if defined $::db;
  $::inspector->inspect( $conn, $event );
  $::services->doServices($conn, $event);
}

sub on_errnickinuse
{
  my ($conn, $event) = @_;
  $_ = ${$::settings->{altnicks}}[rand @{$::settings->{altnicks}}];
  ASM::Util->dprint("Nick is in use, trying $_", 'startup');
  $conn->nick($_);
}

sub on_bannickchange
{
  my ($conn, $event) = @_;
  $_ = ${$::settings->{altnicks}}[rand @{$::settings->{altnicks}}];
  ASM::Util->dprint("Nick is in use, trying $_", 'startup');
  $conn->nick($_);
}

sub on_quit
{
  my ($conn, $event) = @_;
  my @channels=();
  for ( keys %::sc ) {
    push ( @channels, lc $_ ) if delete $::sc{lc $_}{users}{lc $event->{nick}};
  }
  $event->{to} = \@channels;
  if (defined $::db) {
      my $idx = $::db->actionlog($event);
      # Ignore channels that are +s and not monitored
      my @actionlog_channels = grep { not ((grep { /^s$/ } @{$::sc{$_}{modes}}) && ($::channels->{channel}->{$_}->{monitor} eq "no")) } @channels;
      $::log->sqlIncident( join(',', @actionlog_channels), $idx ) if $idx;
      $::db->logg( $event );
  }
  $::log->logg( $event );

  if (($event->{args}->[0] eq "*.net *.split") && (lc $event->{nick} ne 'chanserv')) { #special, netsplit situation
    if ($::netsplit == 0){
      $conn->privmsg($::settings->{masterchan}, "Entering netsplit mode - JOIN and QUIT inspection will be disabled for 60 minutes");
      $::netsplit = 1;
      $conn->schedule(60*60, sub { $::netsplit = 0; $conn->privmsg($::settings->{masterchan}, 'Returning to regular operation'); });
    }
    if ($::netsplit_ignore_lag == 0){
      $::netsplit_ignore_lag = 1;
      $conn->schedule(2*60, sub { $::netsplit_ignore_lag = 0; });
    }
  }
  $::inspector->inspect( $conn, $event ) unless $::netsplit;
  #ugh. Repurge some shit, hopefully this will fix some stuff where things are going wrong
  foreach my $chan ( keys %::sc ) {
    delete $::sc{$chan}{users}{lc $event->{nick}};
  }
  delete($::sn{lc $event->{nick}});
}

sub blah
{
  my ($self, $event) = @_;
  ASM::Util->dprint(Dumper($event), 'misc');
  return if ($event->{nick} =~ /\./);
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
    $::sc{lc $channel}{users}{lc $_}{jointime} = 0;
  }
}

sub on_names {
  my ($conn, $event) = @_;
  irc_users( $event->{args}->[2], split(/ /, $event->{args}->[3]) )  if ($event->{type} eq 'namreply');
}

sub irc_topic {
  my ($conn, $event) = @_;
  if ($event->{format} eq 'server')
  {
    my $chan = lc $event->{args}->[1];
    if ($event->{type} eq 'topic')
    {
      $::sc{$chan}{topic}{text} = $event->{args}->[2];
    }
    elsif ($event->{type} eq 'topicinfo')
    {
      $::sc{$chan}{topic}{time} = $event->{args}->[3];
      $::sc{$chan}{topic}{by} = $event->{args}->[2];
    }
  }
  else
  {
    if ($event->{type} eq 'topic')
    {
      my $chan = lc $event->{to}->[0];
      $::sc{$chan}{topic}{text} = $event->{args}->[0];
      $::sc{$chan}{topic}{time} = time;
      $::sc{$chan}{topic}{by} = $event->{from};
    }
    $::log->logg($event);
    $::db->logg( $event ) if defined $::db;
    $::inspector->inspect($conn, $event);
  }
}

sub on_nick {
  my ($conn, $event) = @_;
  my @channels=();
  my $oldnick = lc $event->{nick};
  my $newnick = lc $event->{args}->[0];
  foreach my $chan ( keys %::sc )
  {
    $chan = lc $chan;
    if ( defined $::sc{$chan}{users}{$oldnick} )
    {
      if ($oldnick ne $newnick) { #otherwise a nick change where they're only
                                  #changing the case of their nick means that
                                  #ASM forgets about them.
        $::sc{$chan}{users}{$newnick} = $::sc{$chan}{users}{$oldnick};
        delete( $::sc{$chan}{users}{$oldnick} );
      }
      push ( @channels, $chan );
    }
  }

  # unfortunately Net::IRC sucks at IRC so we have to implement this ourselves
  if ($oldnick eq lc $conn->{_nick}) {
    $conn->{_nick} = $event->{args}[0];
  }
 
  $::sn{$newnick} = $::sn{$oldnick} if ($oldnick ne $newnick);
  $::db->logg( $event ) if defined $::db;
  delete( $::sn{$oldnick}) if ($oldnick ne $newnick);
  $event->{to} = \@channels;
  $::log->logg($event);
  # Well, the nick change actually was done from the old nick ... but
  # by the time we process it, they already changed nicks. Therefore
  # we'll pretend it's the *new* nick that generated the event.
  $event->{nick} = $event->{args}[0];
  $::inspector->inspect($conn, $event);
}

sub on_kick {
  my ($conn, $event) = @_;
  if (lc $event->{to}->[0] eq lc $conn->{_nick}) {
    $conn->privmsg($::settings->{masterchan}, "I've been kicked from " . $event->{args}->[0] . ": " . $event->{args}->[1]);
#    $conn->join($event->{args}->[0]);
  }
  my $nick = lc $event->{to}->[0];
  my $chan = lc $event->{args}->[0];
  $::log->logg( $event );
  if (defined $::db) {
      $::db->logg( $event );
      # Ignore channels that are +s and not monitored
      if ( not ((grep { /^s$/ } @{$::sc{$chan}{modes}}) && ($::channels->{channel}->{$chan}->{monitor} eq "no")) ) {
          my $idx = $::db->actionlog($event);
          $::log->sqlIncident($chan, $idx) if $idx;
      }
  }
  if (defined($::sn{$nick}) && defined($::sn{$nick}->{mship})) {
    my @mship = @{$::sn{$nick}->{mship}};
    @mship = grep { lc $_ ne $chan } @mship;
    if ( @mship ) {
      $::sn{$nick}->{mship} = \@mship;
    } else {
      delete($::sn{$nick});
    }
  }
  if ( lc $conn->{_nick} eq $nick )
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
    else { #eIbq,k,flj,CFLMPQScgimnprstz
      if ($t eq '+') {
        if ( grep( /[eIbqkfljov]/,($c) ) ) { #modes that take args WHEN BEING ADDED
          push (@new_modes, [$t.$c, shift @args]);
        }
        elsif ( grep( /[CFLMPQScgimnprstz]/, ($c) ) ) {
          push (@new_modes, [$t.$c]);
        }
        else {
          die "Unknown mode $c !\n";
        }
      } else {
        if ( grep( /[eIbqov]/,($c) ) ) { #modes that take args WHEN BEING REMOVED
          push (@new_modes, [$t.$c, shift @args]);
        }
        elsif ( grep( /[CFLMPQScgimnprstzkflj]/, ($c) ) ) {
          push (@new_modes, [$t.$c]);
        }
        else {
          die "Unknown mode $c !\n";
        }
      }
    }
  }
  return \@new_modes;
}

sub on_channelmodeis
{
  my ($conn, $event) = @_;
  my $chan = lc $event->{args}->[1];
  my @temp = @{$event->{args}};
  shift @temp; shift @temp;
  my @modes = @{parse_modes(\@temp)};
  foreach my $line ( @modes ) {
    my @ex = @{$line};
    my ($what, $mode) = split (//, $ex[0]);
    if ($what eq '+') {
      if (defined($ex[1])) {
        push @{$::sc{$chan}{modes}}, $mode . ' ' . $ex[1];
      } else {
        push @{$::sc{$chan}{modes}}, $mode;
      }
    } else {
      my @modes = grep {!/^$mode/} @{$::sc{$chan}{modes}};
      $::sc{$chan}{modes} = \@modes;
    }
  }
}

sub whoGotHit
{
  my ($chan, $mask) = @_;
  my $cvt = Regexp::Wildcards->new(type => 'jokers');
  my @affected = ();
  if ($mask !~ /^\$/) {
    my @div = split(/\$/, $mask);
    my $regex = $cvt->convert($div[0]);
    foreach my $nick (keys %::sn) { 
      next unless defined($::sn{$nick}{user});
      if (lc ($nick.'!'.$::sn{$nick}{user}.'@'.$::sn{$nick}{host}) =~ /^$regex$/i) {
        push @affected, $nick if defined($::sc{$chan}{users}{$nick});
      }
    }
  } elsif ($mask =~ /^\$a:(.*)/) {
    my @div = split(/\$/, $1);
    my $regex = $cvt->convert($div[0]);
    foreach my $nick (keys %::sn) {
      next unless defined($::sn{$nick}{account});
      if (lc ($::sn{$nick}{account}) =~ /^$regex$/i) {
        push @affected, $nick if defined($::sc{$chan}{users}{$nick});
      }
    }
  }
  return @affected;
}

sub on_mode
{
  my ($conn, $event) = @_;
  return if ($event->{nick} =~ /\./); #if I ever want to track what modes ASM has on itself, this will have to die
  my $chan = lc $event->{to}->[0];
# holy shit, I feel so bad doing this
# I have no idea how or why Net::IRC fucks up modes if they've got a ':' in one of the args
# but you do what you must...
  my @splitted = split(/ /, $::lastline); shift @splitted; shift @splitted; shift @splitted;
  $event->{args}=\@splitted;
  if ($chan =~ /^#/) {
    my @modes = @{parse_modes($event->{args})};
    ASM::Util->dprint(Dumper(\@modes), 'misc');
    foreach my $line ( @modes ) {
      my @ex = @{$line};

      if    ( $ex[0] eq '+o' ) { $::sc{$chan}{users}{lc $ex[1]}{op}    = 1; }
      elsif ( $ex[0] eq '-o' ) { $::sc{$chan}{users}{lc $ex[1]}{op}    = 0; }
      elsif ( $ex[0] eq '+v' ) { $::sc{$chan}{users}{lc $ex[1]}{voice} = 1; }
      elsif ( $ex[0] eq '-v' ) { $::sc{$chan}{users}{lc $ex[1]}{voice} = 0; }

      elsif ( $ex[0] eq '+b' ) { 
        $::sc{$chan}{bans}{$ex[1]} = { bannedBy => $event->{from}, bannedOn => time };
        if (lc $event->{nick} !~ /^(floodbot)/) { #ignore the ubuntu floodbots 'cause they quiet people a lot
          my @affected = whoGotHit($chan, $ex[1]);
          if ( defined($::db) && (@affected) && (scalar @affected <= 4) ) {
            foreach my $victim (@affected) {
              # Ignore channels that are +s and not monitored
              if ( not ((grep { /^s$/ } @{$::sc{$chan}{modes}}) && ($::channels->{channel}->{$chan}->{monitor} eq "no")) ) {
                my $idx = $::db->actionlog($event, 'ban', $victim);
                $::log->sqlIncident( $chan, $idx ) if $idx;
              }
            }
          }
          if ($ex[1] =~ /^\*\!\*\@(.*)$/) {
            my $ip = ASM::Util->getHostIP($1);
            $::sc{$chan}{ipbans}{$ip} = { bannedBy => $event->{from}, bannedOn => time } if defined($ip);
          }
        }
      }
      elsif ( $ex[0] eq '-b' ) { 
        delete $::sc{$chan}{bans}{$ex[1]};
        if ($ex[1] =~ /^\*\!\*\@(.*)$/) {
          my $ip = ASM::Util->getHostIP($1);
          delete $::sc{$chan}{ipbans}{$ip} if defined($ip);
        }
      }

      elsif ( $ex[0] eq '+q' ) {
        $::sc{$chan}{quiets}{$ex[1]} = { bannedBy => $event->{from}, bannedOn => time };
        if (lc $event->{nick} !~ /^(floodbot)/) {
          my @affected = whoGotHit($chan, $ex[1]);
          if ( defined($::db) && (@affected) && (scalar @affected <= 4) ) {
            foreach my $victim (@affected) {
              # Ignore channels that are +s and not monitored
              if ( not ((grep { /^s$/ } @{$::sc{$chan}{modes}}) && ($::channels->{channel}->{$chan}->{monitor} eq "no")) ) {
                my $idx = $::db->actionlog($event, 'quiet', $victim);
                $::log->sqlIncident( $chan, $idx ) if $idx;
              }
            }
          }
          if ($ex[1] =~ /^\*\!\*\@(.*)$/) {
            my $ip = ASM::Util->getHostIP($1);
            $::sc{$chan}{ipquiets}{$ip} = { bannedBy => $event->{from}, bannedOn => time } if defined($ip);
          }
        }
      }
      elsif ( $ex[0] eq '-q' ) {
        delete $::sc{$chan}{quiets}{$ex[1]};
        if ($ex[1] =~ /^\*\!\*\@(.*)$/) {
          my $ip = ASM::Util->getHostIP($1);
          delete $::sc{$chan}{ipquiets}{$ip} if defined($ip);
        }
      }

      else {
        my ($what, $mode) = split (//, $ex[0]);
        if ($what eq '+') {
          if (defined($ex[1])) { push @{$::sc{$chan}{modes}}, $mode . ' ' . $ex[1]; }
          else                 { push @{$::sc{$chan}{modes}}, $mode; }
        } else {
          my @modes = grep {!/^$mode/} @{$::sc{$chan}{modes}};
          $::sc{$chan}{modes} = \@modes;
        }
        if ( ($ex[0] eq '+r') && (! defined($::watchRegged{$chan})) ) {
          $::watchRegged{$chan} = 1;
          $conn->schedule(60*45, sub { checkRegged($conn, $chan); });
        }
      }
    }
    $::log->logg($event);
  }
}

sub checkRegged
{
  my ($conn, $chan) = @_;
  if (grep {/^r/} @{$::sc{$chan}{modes}}
        and not ((defined($::channels->{channel}{$chan}{monitor})) and ($::channels->{channel}{$chan}{monitor} eq "no")) )
  {
    my $tgt = $chan;
    my $risk = "debug";
    my $hilite=ASM::Util->commaAndify(ASM::Util->getAlert($tgt, $risk, 'hilights'));
    my $txtz  ="\x03" . $::RCOLOR{$::RISKS{$risk}} . "\u$risk\x03 risk threat [\x02$chan\x02] - channel appears to still be +r after 45 minutes; ping $hilite !att-$chan-$risk";
    my @tgts = ASM::Util->getAlert($tgt, $risk, 'msgs');
    ASM::Util->sendLongMsg($conn, \@tgts, $txtz)
  }
  delete $::watchRegged{$chan};
}

sub on_banlist
{
  my ($conn, $event) = @_;
  my ($me, $chan, $ban, $banner, $bantime) = @{$event->{args}};
  $chan = lc $chan;
  if ($chan ~~ @::bansyncqueue) {
    my @diff = ($chan);
    @::bansyncqueue = array_diff(@::bansyncqueue, @diff);
    push @::quietsyncqueue, $chan;
    my $nextchan = $::bansyncqueue[0];
    if (defined($nextchan) ){
      ASM::Util->dprint("Syncing $nextchan bans", "sync");
      $conn->sl('mode ' . $nextchan . ' b');
    } else {
      $nextchan = $::quietsyncqueue[0];
      ASM::Util->dprint("Syncing $nextchan quiets", "sync");
      $conn->sl('mode ' . $nextchan . ' q');
    }
  }
  $::sc{$chan}{bans}{$ban} = { bannedBy => $banner, bannedOn => $bantime };
  if ($ban =~ /^\*\!\*\@(.*)$/) {
    my $host = $1;
    my $ip = ASM::Util->getHostIPFast($host);
    if (defined($ip)) {
      $::sc{$chan}{ipbans}{$ip} = { bannedBy => $banner, bannedOn => $bantime };
    } elsif ( $host =~ /^(([a-z0-9]([a-z0-9\-]*[a-z0-9])?\.)*([a-z0-9]([a-z0-9\-]*[a-z0-9])?\.?))$/i) {
      ASM::Util->dprint("banlist hostname $chan $host", 'dns');
      $::event->{DNS}->add(
        sub {
          my ($packet) = @_;
          $ip = ASM::Util->stripResp($packet);
          $::sc{$chan}{ipbans}{$ip} = { bannedBy => $banner, bannedOn => $bantime } if defined($ip);
        }, $host, 'A');
    }
  }
}

sub on_quietlist
{
  my ($conn, $event) = @_;
  my ($me, $chan, $mode, $ban, $banner, $bantime) = @{$event->{args}};
  $chan = lc $chan;
  if ($chan ~~ @::quietsyncqueue) {
    my @diff = ($chan);
    @::quietsyncqueue = array_diff(@::quietsyncqueue, @diff);
    my $nextchan = $::quietsyncqueue[0];
    if (defined($nextchan) ){
      ASM::Util->dprint("Syncing $nextchan quiets", "sync");
      $conn->sl('mode ' . $nextchan . ' q');
    }
  }
  $::sc{$chan}{quiets}{$ban} = { bannedBy => $banner, bannedOn => $bantime };
  if ($ban =~ /^\*\!\*\@(.*)$/) {
    my $host = $1;
    my $ip = ASM::Util->getHostIPFast($host);
    if (defined($ip)) {
      $::sc{$chan}{ipquiets}{$ip} = { bannedBy => $banner, bannedOn => $bantime };
    } elsif ( $host =~ /^(([a-z0-9]([a-z0-9\-]*[a-z0-9])?\.)*([a-z0-9]([a-z0-9\-]*[a-z0-9])?\.?))$/i) {
      ASM::Util->dprint("quietlist hostname $chan $host", 'dns');
      $::event->{DNS}->add(
        sub {
          my ($packet) = @_;
          $ip = ASM::Util->stripResp($packet);
          $::sc{$chan}{ipquiets}{$ip} = { bannedBy => $banner, bannedOn => $bantime } if defined($ip);
        }, $host, 'A');
    }
  }
}

sub on_channelurlis
{
  my ($conn, $event) = @_;
  $::sc{lc $event->{args}->[1]}{url} = $event->{args}->[2];
}

sub on_ctcp
{
  my ($conn, $event) = @_;
  my $acct = lc $::sn{lc $event->{nick}}->{account};
  ASM::Util->dprint(Dumper($event), 'ctcp');
  if (($event->{type} eq 'cdcc') &&
      (defined($::users->{person}->{$acct})) &&
      (defined($::users->{person}->{$acct}->{flags})) &&
      (grep {$_ eq 'c'} split('', $::users->{person}->{$acct}->{flags}))) {
    ASM::Util->dprint(Dumper($event), 'dcc');
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
  $::dsock{lc $event->{nick}} = $event->{args}->[1];
}

sub on_ctcp_source
{
  my ($conn, $event) = @_;
  $conn->ctcp_reply($event->{nick}, 'SOURCE https://gitlab.devlabs.linuxassist.net/asm/antispammeta/');
}

sub on_whoxreply
{
  my ($conn, $event) = @_;
  my ($tgt, $magic, $chan, $user, $realip, $host, $nick, $account, $gecos) = @{$event->{args}};
  return unless $magic eq '314';
  $nick = lc $nick; $chan = lc $chan;
  if (!defined $::sn{lc $nick}) {
    $::sn{$nick} = {};
    $::sn{$nick}->{mship} = [$chan];
  } else {
    $::sn{$nick}->{mship} = [grep { lc $_ ne $chan } @{$::sn{$nick}->{mship}}];
    push @{$::sn{$nick}->{mship}}, $chan;
  }
  $::sn{$nick}->{gecos} = $gecos;
  $::sn{$nick}->{user} = $user;
  $::sn{$nick}->{host} = $host;
  $::sn{$nick}->{account} = lc $account;
  if ( $realip ne '255.255.255.255' && index($realip, ':') == -1 ) # some day I dream of ASM handling IPv6
  {
    $::sn{$nick}->{ip} = ASM::Util->dottedQuadToInt($realip);
  }
}

sub on_whoxover
{
  my ($conn, $event) = @_;
  my $syncedchan = lc $event->{args}->[1];
  $::synced{$syncedchan} = 1;
  if ($syncedchan ~~ @::syncqueue) {
    my @diff = ($syncedchan);
    @::syncqueue = array_diff(@::syncqueue, @diff);
    push @::bansyncqueue, $syncedchan;
  }
  my $chan = $::syncqueue[0];
  if (defined($chan) ){
    ASM::Util->dprint("Syncing $chan", "sync");
    $conn->sl('who ' . $chan . ' %tcuihnar,314');
    $conn->sl('mode ' . $chan);
  } else {
    $chan = $::bansyncqueue[0];
    ASM::Util->dprint("Syncing $chan bans", "sync");
    $conn->sl('mode ' . $chan . ' b');
  }
}

sub on_whofuckedup
{
  my ($conn, $event) = @_;
  if ($event->{args}->[1] eq "STATS") { 
#most likely this is getting called because we did stats p too often.
#unfortunately the server doesn't let us know what exactly we called stats for.
#anyways, we don't need to do anything for this
  } else { #dunno why it got called, print the data and I'll add a handler for it.
    ASM::Util->dprint('on_whofuckedup called!', 'sync');
    ASM::Util->dprint(Dumper($event), 'sync');
  }
}

sub on_bannedfromchan {
  my ($conn, $event) = @_;
  ASM::Util->dprint("I'm banned from " . $event->{args}->[1], 'startup');
}

sub on_byechan {
  my ($chan) = @_;
  #TODO do del event stuff
}

sub on_servicesdown
{
  my ($conn, $event) = @_;
  if ($event->{args}->[1] eq 'NickServ') {
    $::no_autojoins = 1;
    $conn->join($::settings->{masterchan}); # always join masterchan, so we can find you
    $conn->sl("PING :" . time);
  }
}

sub on_banlistend
{
  my ($conn, $event) = @_;
  my $chan = lc $event->{args}->[1];
  if ($chan ~~ @::bansyncqueue) {
    my @diff = ($chan);
    @::bansyncqueue = array_diff(@::bansyncqueue, @diff);
    push @::quietsyncqueue, $chan;
    my $nextchan = $::bansyncqueue[0];
    if (defined($nextchan) ){
      ASM::Util->dprint("Syncing $nextchan bans", "sync");
      $conn->sl('mode ' . $nextchan . ' b');
    } else {
      $nextchan = $::quietsyncqueue[0];
      ASM::Util->dprint("Syncing $nextchan quiets", "sync");
      $conn->sl('mode ' . $nextchan . ' q');
    }
  }
}

sub on_quietlistend
{
  my ($conn, $event) = @_;
  my $chan = lc $event->{args}->[1];
  if ($chan ~~ @::quietsyncqueue) {
    my @diff = ($chan);
    @::quietsyncqueue = array_diff(@::quietsyncqueue, @diff);
    my $nextchan = $::quietsyncqueue[0];
    if (defined($nextchan) ){
      ASM::Util->dprint("Syncing $nextchan quiets", "sync");
      $conn->sl('mode ' . $nextchan . ' q');
    }
  }
  $::pendingsync--;
  if ($::pendingsync == 0) {
    my $size = `ps -p $$ h -o size`;
    my $cputime = `ps -p $$ h -o time`;
    chomp $size; chomp $cputime;
    my ($tx, $rx);
    if ($conn->{_tx}/1024 > 1024) {
      $tx = sprintf("%.2fMB", $conn->{_tx}/(1024*1024));
    } else {
      $tx = sprintf("%.2fKB", $conn->{_tx}/1024);
    }
    if ($conn->{_rx}/1024 > 1024) {
      $rx = sprintf("%.2fMB", $conn->{_rx}/(1024*1024));
    } else {
      $rx = sprintf("%.2fKB", $conn->{_rx}/1024);
    }
    $::event->{DNS}->await();
    $conn->privmsg($::settings->{masterchan}, "Finished syncing after " . (time - $::starttime) . " seconds. " .
      "I'm tracking " . (scalar (keys %::sn)) . " nicks" .
      " across " . (scalar (keys %::sc)) . " tracked channels." .
      " I'm using " . $size . "KB of RAM" .
      ", have used " . $cputime . " of CPU time" .
      ", have sent $tx of data, and received $rx of data.");
    my %x = ();
    foreach my $c (@{$::settings->{autojoins}}) { $x{$c} = 1; }
    foreach my $cx (keys %::sc) { delete $x{$cx}; }
    if (scalar (keys %x)) {
      $conn->privmsg($::settings->{masterchan}, "Syncing appears to have failed for " . ASM::Util->commaAndify(keys %x)) unless $::no_autojoins;
    }
  }
}

return 1;
