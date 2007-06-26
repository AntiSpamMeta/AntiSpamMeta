use warnings;
use strict;

use List::Util qw(first);

#my @ignored = ();
@::ignored = ();

sub inspect {
  our ($conn, $event) = @_;
  my (%conx, %monx);
  our (%aonx, %dct, $rev, $chan, $id);
  %aonx=(); %dct=(); $rev; $chan=""; $id="";
  my (@dnsbl, @unpakt, @uniq, @cut);
  my ($match, $txtz, $iaddr);
  my @override = [];
  our $unmode='';
  my $nick = lc $event->{nick};
  return if (defined(first { ( lc $event->{nick} eq lc $_ ) } @::eline));
  return if (defined(first { ( lc $event->{user} eq lc $_ ) } @::eline));
  return if (defined(first { ( lc $event->{host} eq lc $_ ) } @::eline));
  $iaddr = hostip($event->{host});
  $rev = join('.', reverse(unpack('C4', $iaddr))).'.' if (defined $iaddr);
  %monx = defined($::channels->{channel}->{master}->{event}) ? %{$::channels->{channel}->{master}->{event}} : ();
  ## NB: isn't there a better way to do this with grep, somehow?
  foreach ( @::ignored ) {
    return if (lc $event->{nick} eq $_);
  }
  foreach $chan ( @{$event->{to}} ) {
    next unless $chan =~ /^#/;
    %conx = defined($::channels->{channel}->{lc $chan}->{event}) ? %{$::channels->{channel}->{lc $chan}->{event}} : ();
    %aonx = (%monx, %conx);
    foreach $id (keys %aonx) {
      next unless ( defined(first { lc $_ eq $event->{type} } split(/[,:; ]+/, $aonx{$id}{type}) ) )
                    || ( lc $event->{type} eq lc $aonx{$id}{type} );
#      next unless ( defined($::classes->{class}->{$aonx{$id}{class}}));
      eval "Classes::" . $aonx{$id}{class} . "();";
      warn $@ if $@;
    }
  }
  foreach ( keys %dct ) {
    push( @override, split( /[ ,;]+/, $dct{$_}{override} ) ) if ( defined $dct{$_}{override} );
  }
  delete $dct{$_} foreach @override;
  foreach $chan (@{$event->{to}}) {
    foreach $id ( keys %dct ) {
      sql_record($chan, $event->{nick}, $event->{user}, $event->{host}, $dct{$id}{risk}, $id, $dct{$id}{reason});
      $txtz = "$dct{$id}{risk} risk threat: ".
              "Detected $event->{nick} $dct{$id}{reason} in $chan ";
      $txtz = $txtz . commaAndify(getAlert(lc $chan, $dct{$id}{risk}, 'hilights')) if (getAlert(lc $chan, $dct{$id}{risk}, 'hilights'));
      if (cs(lc $chan)->{op} ne 'no') {
        if ($event->{type} eq 'topic') { #restore old topic
          my $oldtopic = $::sc{lc $event->{to}->[0]}{topic}{text};
          o_send( $conn, "topic $chan :$oldtopic");
          o_send( $conn, "mode $chan +t");
        }
        eval "Actions::" . $dct{$id}{action} . "();";
        warn $@ if $@;
        my $lconn=$conn; my $lunmode = $unmode;
        if ((int($dct{$id}{time}) ne 0) && ($unmode ne '')) {
           $conn->schedule(int($dct{$id}{time}), sub { print "Timer called!\n"; o_send($lconn,$lunmode); });
        }
      }
      $conn->privmsg($_, $txtz) foreach getAlert($chan, $dct{$id}{risk}, 'msgs');
      push(@::ignored, lc $event->{nick});
      $conn->schedule(15, sub { @::ignored = grep { lc $_ ne lc $nick } @::ignored; });
    }
  }
}

sub Inspect::killsub {
  undef &inspect;
}

return 1;
