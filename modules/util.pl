#warning: if you add a function, put it into killsub!

use warnings;
use strict;

my %sf;
my %oq;

%::RISKS =
(
  'debug'  => 10,
  'info'   => 20,
  'low'    => 30,
  'medium' => 40,
  'high'   => 50,
  'opalert'=> 9001 #OVER NINE THOUSAND!!!
);
#leaves room for more levels if for some reason we end up needing more
#theoretically, you should be able to change those numbers without any damage

sub maxlen {
  my ($a, $b) = @_;
  my ($la, $lb) = (length($a), length($b));
  return $la if ($la > $lb);
  return $lb;
}

#cs: returns the xml settings for the specified chan, or default if there aren't any settings for that chan
sub cs {
  my ($chan) = @_;
  $chan = lc $chan;
  return $::channels->{channel}->{$chan} if ( defined($::channels->{channel}->{$chan}) );
  return $::channels->{channel}->{default};
}

#this item is a stub, dur
sub hostip {
  return gethostbyname($_[0]);
}

# Send something that requires ops
sub o_send {
  my ( $conn, $send ) = @_;
  my @splt = split(/ /, $send);
  my $chan = lc $splt[1];
  $oq{$chan} = [] unless defined($oq{$chan});
  if ( cs($chan)->{op} ne 'no' ) {
    print Dumper(lc $::settings->{nick}, $::sc{$chan}{users}{lc $::settings->{nick}});
    print Dumper($send, $chan);
    if ( $::sc{$chan}{users}{lc $::settings->{nick}}{op} eq 1) {
      $conn->sl($send);
    }
    else {
      push( @{$oq{$chan}},$send );
      $conn->privmsg( 'chanserv', "op $chan" );
    }
  }
}

sub doQueue {
  my ( $conn, $chan ) = @_;
  return unless defined $oq{$chan};
  $conn->sl(shift(@{$oq{$chan}})) while (@{$oq{$chan}});
}

sub flood_add {
    my ( $chan, $id, $host, $to ) = @_;
    push( @{$sf{$id}{$chan}{$host}}, time );
    while ( time >= $sf{$id}{$chan}{$host}[0] + $to ) {
      last if ( $#{ $sf{$id}{$chan}{$host} } == 0 );
      shift( @{$sf{$id}{$chan}{$host}} );
    }
    return $#{ @{$sf{$id}{$chan}{$host}}}+1;
}

sub flood_process {
  for my $id ( keys %sf ) {
    for my $chan ( keys %{$sf{$id}} ) {
      for my $host ( keys %{$sf{$id}{$chan}} ) {
        next unless defined $sf{$id}{$chan}{$host}[0];
        while ( time >= $sf{$id}{$chan}{$host}[0] + $sf{$id}{'timeout'} ) {
          last if ( $#{ $sf{$id}{$chan}{$host} } == 0 );
          shift ( @{$sf{$id}{$chan}{$host}} );
        }
      }
    }
  }
}

sub getAlert {
  my ($c, $risk, $t) = @_;
  @_ = ();
  $c = lc $c;
  foreach my $prisk ( keys %::RISKS) {
    if ( $::RISKS{$risk} >= $::RISKS{$prisk} ) {
      push( @_, @{$::channels->{channel}->{master}->{$t}->{$prisk}} ) if defined $::channels->{channel}->{master}->{$t}->{$prisk};
      push( @_, @{cs($c)->{$t}->{$prisk}} ) if defined cs($c)->{$t}->{$prisk};
    }
  }
  return @_;
}

sub commaAndify {
  my @seq = @_;
  my $len = ($#seq);
  my $last = $seq[$len];
  return '' if $len eq -1;
  return $seq[0] if $len eq 0;
  return join( ' and ', $seq[0], $seq[1] ) if $len eq 1;
  return join( ', ', splice(@seq,0,$len) ) . ', and ' . $last;
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

sub leq {
  my ($s1, $s2) = @_;
  return (lc $s1 eq lc $s2);
}

sub seq {
  my ($n1, $n2) = @_;
  return 0 unless defined($n1);
  return 0 unless defined($n2);
  return ($n1 eq $n2);
}

sub Util::killsub {
  undef &cs;
  undef &hostip;
  undef &o_send;
  undef &doQueue;
  undef &flood_add;
  undef &flood_process;
  undef &getAlert;
  undef &commaAndify;
  undef &parse_modes;
  undef &leq;
  undef &seq;
}

return 1;
