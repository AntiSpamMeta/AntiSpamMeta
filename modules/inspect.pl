package ASM::Inspect;
use warnings;
use strict;

use List::Util qw(first);
use Data::Dumper;

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
  return if (defined(first { ( lc $event->{nick} eq lc $_ ) } @::eline));
  return if (defined(first { ( lc $event->{user} eq lc $_ ) } @::eline));
  return if (defined(first { ( lc $event->{host} eq lc $_ ) } @::eline));
  $iaddr = gethostbyname($event->{host});
  $rev = join('.', reverse(unpack('C4', $iaddr))).'.' if (defined $iaddr);
  %monx = defined($::channels->{channel}->{master}->{event}) ? %{$::channels->{channel}->{master}->{event}} : ();
  ## NB: isn't there a better way to do this with grep, somehow?
#  foreach ( @::ignored ) {
#    return if (lc $event->{nick} eq $_);
#  }
  foreach $chan ( @{$event->{to}} ) {
    next unless $chan =~ /^#/;
    %conx = defined($::channels->{channel}->{lc $chan}->{event}) ? %{$::channels->{channel}->{lc $chan}->{event}} : ();
    %aonx = (%monx, %conx);
    foreach $id (keys %aonx) {
      next unless ( defined(first { lc $_ eq $event->{type} } split(/[,:; ]+/, $aonx{$id}{type}) ) )
                    || ( lc $event->{type} eq lc $aonx{$id}{type} );
#      next unless ( defined($::classes->{class}->{$aonx{$id}{class}}));
      $dct{$id} = $aonx{$id} if $::classes->check($aonx{$id}{class}, $aonx{$id}, $id, $event, $chan, $rev);
#  my ($chk, $id, $event, $chan) = @_;
#       eval "Classes::" . $aonx{$id}{class} . "();";
#      warn $@ if $@;
    }
  }
  foreach ( keys %dct ) {
    push( @override, split( /[ ,;]+/, $dct{$_}{override} ) ) if ( defined $dct{$_}{override} );
  }
  delete $dct{$_} foreach @override;
  foreach $chan (@{$event->{to}}) {
    foreach $id ( keys %dct ) {
      $::db->record($chan, $event->{nick}, $event->{user}, $event->{host}, $::sn{lc $event->{nick}}->{gecos}, $dct{$id}{risk}, $id, $dct{$id}{reason});
      $txtz = "$dct{$id}{risk} risk threat: ".
              "Detected $event->{nick} $dct{$id}{reason} in $chan ";
      $txtz = $txtz . ASM::Util->commaAndify(ASM::Util->getAlert(lc $chan, $dct{$id}{risk}, 'hilights')) if (ASM::Util->getAlert(lc $chan, $dct{$id}{risk}, 'hilights'));
      if (ASM::Util->cs(lc $chan)->{op} ne 'no') {
        if ($event->{type} eq 'topic') { #restore old topic
          my $oldtopic = $::sc{lc $event->{to}->[0]}{topic}{text};
          o_send( $conn, "topic $chan :$oldtopic");
          o_send( $conn, "mode $chan +t");
        }
        eval '$unmode = Actions::' . $dct{$id}{action} . '($conn, $event, $chan);';
        warn $@ if $@;
        my $lconn=$conn; my $lunmode = $unmode;
        if ((int($dct{$id}{time}) ne 0) && ($unmode ne '')) {
           $conn->schedule(int($dct{$id}{time}), sub { print "Timer called!\n"; o_send($lconn,$lunmode); });
        }
      }
      unless (defined($::ignored{lc $event->{nick}}) && ($::ignored{lc $event->{nick}} >= $::RISKS{$dct{$id}{risk}})) {
        print "alerting!\n";
        my @tgts = ASM::Util->getAlert($chan, $dct{$id}{risk}, 'msgs');
        print Dumper(\@tgts);
        foreach my $tgt (@tgts) {
          $conn->privmsg($tgt, $txtz);
        }
        $::ignored{lc $nick} = $::RISKS{$dct{$id}{risk}};
        $conn->schedule(15, sub { delete($::ignored{lc $nick})});
      }
    }
  }
}

return 1;
