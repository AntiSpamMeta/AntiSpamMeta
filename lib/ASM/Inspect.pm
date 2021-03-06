package ASM::Inspect;
no autovivification;
use warnings;
use strict;

use Data::Dumper;
use String::Interpolate qw(interpolate);
use HTTP::Request;
use ASM::Shortener;

no if $] >= 5.017011, warnings => 'experimental::smartmatch';

%::ignored = ();
sub new
{
  my $module = shift;
  my ($conn) = @_;
  my $self = {};
  $self->{CONN} = $conn;
  bless($self);
  $conn->add_handler('join', sub { inspect(@_) unless $::netsplit; }, "after"); #allow state tracking to molest this too
  $conn->add_handler('quit', sub { inspect(@_) unless $::netsplit; }, "after"); #allow state tracking to molest this too
  $conn->add_handler('part', \&inspect, "before"); #state tracking will break this if done after
  $conn->add_handler('notice', \&inspect, "after");
  $conn->add_handler('nick', \&inspect, "after");
  $conn->add_handler('cping', \&inspect, "after");
  $conn->add_handler('cversion', \&inspect, "after");
  $conn->add_handler('cdcc', \&inspect, "after");
  $conn->add_handler('csource', \&inspect, "after");
  $conn->add_handler('ctime', \&inspect, "after");
  $conn->add_handler('cuserinfo', \&inspect, "after");
  $conn->add_handler('cclientinfo', \&inspect, "after");
  $conn->add_handler('cfinger', \&inspect, "after");
  $conn->add_handler('invite', \&inspect, "after");
  $conn->add_handler('public', \&on_public, "after");
  return $self;
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
  inspect( $conn, $event, $response );
}

sub on_public
{
  my ($conn, $event) = @_;
  my $chan = lc $event->{to}[0];
  $chan =~ s/^[+@]//;
  if ($event->{args}->[0] =~ /(https?:\/\/bitly.com\/\w+|https?:\/\/bit.ly\/\w+|https?:\/\/j.mp\/\w+|https?:\/\/tinyurl.com\/\w+)/i) {
    my $reqid = $::async->add( HTTP::Request->new( GET => $1 ) );
    $::httpRequests{$reqid} = $event;
    my ($response, $id) = $::async->wait_for_next_response( 1 );
    if (defined($response)) {
      on_httpResponse($conn, $id, $response);
    }
    else { $conn->schedule( 1, sub { checkHTTP($conn); } ); }
  }
  inspect( $conn, $event );
}

sub inspect {
  our ($conn, $event, $response) = @_;
  my (%aonx, %dct, $rev, $chan, $id);
  %aonx=(); %dct=(); $chan=""; $id="";
  my (@dnsbl, @uniq);
  my ($match, $txtz, $iaddr);
  my @override = [];
  my $displaynick = ($event->{type} eq 'nick') ? $event->{args}->[0] : $event->{nick};
  my $nick = lc $displaynick;
  my $xresult;
  return if (index($nick, ".") != -1);
  if ( $event->{type} eq 'join' ) {
# Only doing DNS lookups for join events will mean that DNSBL will break if we try to do it on something other than joins,
# But it also means we cut back on the DNS lookups by a metric shitton
    $iaddr = ASM::Util->getHostIP($event->{host});
    $rev = join('.', reverse(unpack('C4', $iaddr))).'.' if (defined $iaddr);
  }
  ## NB: isn't there a better way to do this with grep, somehow?
  %aonx = %{$::rules->{event}};
  foreach $chan ( @{$event->{to}} ) {
    # don't do anything for channels we haven't synced yet
    # because we can't yet respect stuff like notrigger for these
    next unless $::synced{lc $chan};
    next unless $chan =~ /^#/;
    next unless ASM::Util->mayAlert($chan);
    foreach $id (keys %aonx) {
      next unless ( grep { $event->{type} eq $_ } split(/[,:; ]+/, $aonx{$id}{type}) );
      next if exists $::channels->{channel}{$chan}{disable_rules}{$id};
      if (defined($response)) {
        if ($aonx{$id}{class} ne 'urlcrunch') { next; } #don't run our regular checks if this is being called from a URL checking function
        else { $xresult = $::classes->check($aonx{$id}{class}, $aonx{$id}, $id, $event, $chan, $response); }
      }
      else {
        $xresult = $::classes->check($aonx{$id}{class}, $aonx{$id}, $id, $event, $chan, $rev); # this is another bad hack done for dnsbl-related stuff
      }
      next unless (defined($xresult)) && ($xresult ne 0);
      ASM::Util->dprint(Dumper($xresult), 'inspector');
      $dct{$id} = $aonx{$id};
      $dct{$id}{xresult} = $xresult;
    }
  }
  foreach ( keys %dct ) {
    if ( defined $dct{$_}{override} ) {
      push( @override, split( /[ ,;]+/, $dct{$_}{override} ) );
    }
  }
  delete $dct{$_} foreach @override;
  my $evcontent = $event->{args}->[0];
  my $evhost = $event->{host};
  foreach $chan (@{$event->{to}}) {
    $chan = lc $chan;
    foreach $id ( keys %dct ) {
      return unless (ASM::Util->notRestricted($nick, "notrigger") && ASM::Util->notRestricted($nick, "no$id"));
      $xresult = $dct{$id}{xresult};
      my $nicereason = interpolate($dct{$id}{reason});
      $txtz = "\x03" . $::RCOLOR{$::RISKS{$dct{$id}{risk}}} . "\u$dct{$id}{risk}\x03 risk threat [\x02$chan\x02] - ".
              "\x02$displaynick\x02 - ${nicereason}; ping ";
      $txtz = $txtz . ASM::Util->commaAndify(ASM::Util->getAlert($chan, $dct{$id}{risk}, 'hilights')) if (ASM::Util->getAlert($chan, $dct{$id}{risk}, 'hilights'));
      $txtz = $txtz . ' !att-' . $chan . '-' . $dct{$id}{risk};
      my $uuid = $::log->incident($chan, $displaynick, $event->{user}, $event->{host}, $::sn{lc $nick}->{gecos}, $dct{$id}{risk}, $id, $nicereason);
      $txtz = $txtz . ' ' . ASM::Shortener->shorturl($::settings->{web}->{detectdir} . $uuid . '.txt');
      if ($id eq 'last_measure_regex') { #TODO: Note that this is another example of things that shouldn't be hardcoded, but are.

      }
      if (
          (!(defined($::ignored{$chan}) && ($::ignored{$chan} >= $::RISKS{$dct{$id}{risk}}))) ||
          (($::pacealerts == 0) && ($dct{$id}{risk} eq 'info'))
         ) {
        my @tgts = ASM::Util->getAlert($chan, $dct{$id}{risk}, 'msgs');
        ASM::Util->sendLongMsg($conn, \@tgts, $txtz);
        $conn->schedule(45, sub { delete($::ignored{$chan}) if $::ignored{$chan} == $::RISKS{$dct{$id}{risk}} });
        $::ignored{$chan} = $::RISKS{$dct{$id}{risk}};
      }
    }
  }
}

1;
# vim: ts=2:sts=2:sw=2:expandtab
