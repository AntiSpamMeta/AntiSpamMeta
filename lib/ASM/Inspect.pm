package ASM::Inspect;
no autovivification;
use warnings;
use strict;

use Data::Dumper;
use String::Interpolate qw(interpolate);
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

%::ignored = ();
sub new
{
  my $module = shift;
  my $self = {};
  bless($self);
  return $self;
}

sub inspect {
  our ($self, $conn, $event, $response) = @_;
  my (%aonx, %dct, $rev, $chan, $id);
  %aonx=(); %dct=(); $chan=""; $id="";
  my (@dnsbl, @uniq);
  my ($match, $txtz, $iaddr);
  my @override = [];
  my $nick = ($event->{type} eq 'nick') ? $event->{args}->[0] : lc $event->{nick};
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
    next if ((defined($::channels->{channel}->{$chan}->{monitor})) and ($::channels->{channel}->{$chan}->{monitor} eq "no"));
    foreach $id (keys %aonx) {
      next unless ( grep { $event->{type} eq $_ } split(/[,:; ]+/, $aonx{$id}{type}) );
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
    foreach $id ( keys %dct ) {
      return unless (ASM::Util->notRestricted($nick, "notrigger") && ASM::Util->notRestricted($nick, "no$id"));
      $xresult = $dct{$id}{xresult};
      my $nicereason = interpolate($dct{$id}{reason});
      if (defined $::db) {
          $::db->record($chan, $event->{nick}, $event->{user}, $event->{host}, $::sn{lc $event->{nick}}->{gecos}, $dct{$id}{risk}, $id, $nicereason);
      }
      $txtz = "\x03" . $::RCOLOR{$::RISKS{$dct{$id}{risk}}} . "\u$dct{$id}{risk}\x03 risk threat [\x02$chan\x02] - ".
              "\x02$event->{nick}\x02 - ${nicereason}; ping ";
      $txtz = $txtz . ASM::Util->commaAndify(ASM::Util->getAlert(lc $chan, $dct{$id}{risk}, 'hilights')) if (ASM::Util->getAlert(lc $chan, $dct{$id}{risk}, 'hilights'));
      $txtz = $txtz . ' !att-' . $chan . '-' . $dct{$id}{risk};
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
      $::log->incident($chan, "$chan: $dct{$id}{risk} risk: $event->{nick} - $nicereason\n");
    }
  }
}

1;
# vim: ts=2:sts=2:sw=2:expandtab
