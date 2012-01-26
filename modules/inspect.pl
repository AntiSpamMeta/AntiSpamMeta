package ASM::Inspect;
use warnings;
use strict;

use Data::Dumper;
#use List::Util qw(first);
use String::Interpolate qw(interpolate);

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
  my $xresult;
  return if (index($nick, ".") != -1);
  return if (defined($::eline{$nick}) || defined($::eline{lc $event->{user}}) || defined($::eline{lc $event->{host}}));
  if ( $event->{host} =~ /gateway\/web\// ) {
    if ( $event->{user} =~ /([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})/ ) {
      $rev = sprintf("%d.%d.%d.%d.", hex($4), hex($3), hex($2), hex($1));
    }
  }
  else {
    $iaddr = gethostbyname($event->{host});
    $rev = join('.', reverse(unpack('C4', $iaddr))).'.' if (defined $iaddr);
  }
  ## NB: isn't there a better way to do this with grep, somehow?
  %aonx = %{$::channels->{channel}->{master}->{event}};
  foreach $chan ( @{$event->{to}} ) {
    next unless $chan =~ /^#/;
    next if ((defined($::channels->{channel}->{$chan}->{monitor})) and ($::channels->{channel}->{$chan}->{monitor} eq "no"));
    foreach $id (keys %aonx) {
      next unless ( grep { $event->{type} eq $_ } split(/[,:; ]+/, $aonx{$id}{type}) );
      next if ($aonx{$id}{class} eq 'dnsbl') && ($event->{host} =~ /(fastwebnet\.it|fastres\.net)$/); #this is a bad hack
      $xresult = $::classes->check($aonx{$id}{class}, $aonx{$id}, $id, $event, $chan, $rev); # this is another bad hack done for dnsbl-related stuff
      next if defined($xresult) == 0;
      next if $xresult eq 0;
      ASM::Util->dprint(Dumper( $xresult ));
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
  my $mylastreason = $::lastreason;
  my $evcontent = $event->{args}->[0];
  my $evhost = $event->{host};
  foreach $chan (@{$event->{to}}) {
    foreach $id ( keys %dct ) {
      $xresult = $dct{$id}{xresult};
      my $nicereason = interpolate($dct{$id}{reason});
      $::db->record($chan, $event->{nick}, $event->{user}, $event->{host}, $::sn{lc $event->{nick}}->{gecos}, $dct{$id}{risk}, $id, $nicereason);
      $txtz = "\x03" . $::RCOLOR{$::RISKS{$dct{$id}{risk}}} . "\u$dct{$id}{risk}\x03 risk threat [\x02$chan\x02]: ".
              "\x02$event->{nick}\x02 - ${nicereason}; ping ";
      $txtz = $txtz . ASM::Util->commaAndify(ASM::Util->getAlert(lc $chan, $dct{$id}{risk}, 'hilights')) if (ASM::Util->getAlert(lc $chan, $dct{$id}{risk}, 'hilights'));
      $txtz = $txtz . ' !att-' . $chan . '-' . $dct{$id}{risk};
      unless (defined($::ignored{$chan}) && ($::ignored{$chan} >= $::RISKS{$dct{$id}{risk}})) {
        my @tgts = ASM::Util->getAlert($chan, $dct{$id}{risk}, 'msgs');
        foreach my $tgt (@tgts) { #unfortunately wikipedia has way too many ops, and it breaks things
          if (length($txtz) <= 380) {
            $conn->privmsg($tgt, $txtz);
          } else {
            my $splitpart = rindex($txtz, " ", 380);
            $conn->privmsg($tgt, substr($txtz, 0, $splitpart));
            $conn->privmsg($tgt, substr($txtz, $splitpart));
          }
        }
        $::ignored{$chan} = $::RISKS{$dct{$id}{risk}};
        $conn->schedule(45, sub { delete($::ignored{$chan})});
      }
    }
  }
}

1;
