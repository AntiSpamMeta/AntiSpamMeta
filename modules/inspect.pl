package ASM::Inspect;
use warnings;
use strict;

#use Data::Dumper;
#use List::Util qw(first);

%::ignored = ();
sub new
{
  my $module = shift;
  my $self = {};
  bless($self);
  return $self;
}

sub inspect {
  our ($self, $conn, $event) = @_;
  my (%conx, %monx);
  my (%aonx, %dct, $rev, $chan, $id);
  %aonx=(); %dct=(); $chan=""; $id="";
  my (@dnsbl, @unpakt, @uniq, @cut);
  my ($match, $txtz, $iaddr);
  my @override = [];
  our $unmode='';
  my $nick = lc $event->{nick};
  return if (defined($::eline{$nick}) || defined($::eline{lc $event->{user}}) || defined($::eline{lc $event->{host}}));
  $iaddr = gethostbyname($event->{host});
  $rev = join('.', reverse(unpack('C4', $iaddr))).'.' if (defined $iaddr);
#  %monx = defined($::channels->{channel}->{master}->{event}) ? %{$::channels->{channel}->{master}->{event}} : ();
  ## NB: isn't there a better way to do this with grep, somehow?
  %aonx = %{$::channels->{channel}->{master}->{event}};
  foreach $chan ( @{$event->{to}} ) {
    next unless $chan =~ /^#/;
#    %conx = defined($::channels->{channel}->{lc $chan}->{event}) ? %{$::channels->{channel}->{lc $chan}->{event}} : ();
#    %aonx = (%monx, %conx);
    foreach $id (keys %aonx) {
      next unless ( grep { $event->{type} eq $_ } split(/[,:; ]+/, $aonx{$id}{type}) );
      $dct{$id} = $aonx{$id} if $::classes->check($aonx{$id}{class}, $aonx{$id}, $id, $event, $chan, $rev);
    }
  }
  foreach ( keys %dct ) {
    if ( defined $dct{$_}{override} ) {
      push( @override, split( /[ ,;]+/, $dct{$_}{override} ) );
    }
  }
  delete $dct{$_} foreach @override;
  foreach $chan (@{$event->{to}}) {
    foreach $id ( keys %dct ) {
      $::db->record($chan, $event->{nick}, $event->{user}, $event->{host}, $::sn{lc $event->{nick}}->{gecos}, $dct{$id}{risk}, $id, $dct{$id}{reason});
      $txtz = "\x03" . $::RCOLOR{$::RISKS{$dct{$id}{risk}}} . "\u$dct{$id}{risk}\x03 risk threat [\x02$chan\x02]: ".
              "\x02$event->{nick}\x02 - $dct{$id}{reason}; ping ";
      $txtz = $txtz . ASM::Util->commaAndify(ASM::Util->getAlert(lc $chan, $dct{$id}{risk}, 'hilights')) if (ASM::Util->getAlert(lc $chan, $dct{$id}{risk}, 'hilights'));
      if (ASM::Util->cs(lc $chan)->{op} ne 'no') {
        if ($event->{type} eq 'topic') { #restore old topic
          my $oldtopic = $::sc{lc $event->{to}->[0]}{topic}{text};
          $::oq->o_send( $conn, "topic $chan :$oldtopic");
          $::oq->o_send( $conn, "mode $chan +t");
        }
#        eval '$unmode = Actions::' . $dct{$id}{action} . '($conn, $event, $chan);';
        $unmode = $::actions->do($dct{$id}{action}, $conn, $event, $chan);
        my $lconn=$conn; my $lunmode = $unmode;
        if ((int($dct{$id}{time}) ne 0) && ($unmode ne '')) {
           $conn->schedule(int($dct{$id}{time}), sub { $::oq->o_send($lconn,$lunmode); });
        }
      }
      unless (defined($::ignored{$event->{host}}) && ($::ignored{$event->{host}} >= $::RISKS{$dct{$id}{risk}})) {
        my @tgts = ASM::Util->getAlert($chan, $dct{$id}{risk}, 'msgs');
        foreach my $tgt (@tgts) {
          $conn->privmsg($tgt, $txtz);
        }
        $::ignored{$event->{host}} = $::RISKS{$dct{$id}{risk}};
        $conn->schedule(60, sub { delete($::ignored{$event->{host}})});
      }
    }
  }
}

1;
