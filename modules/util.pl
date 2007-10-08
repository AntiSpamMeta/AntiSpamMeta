package ASM::Util;
use Array::Utils qw(:all);
use warnings;
use strict;

my %sf;
my %oq;

%::RISKS =
(
  'disable'=> -1, #this isn't really an alert
  'debug'  => 10,
  'info'   => 20,
  'low'    => 30,
  'medium' => 40,
  'high'   => 50,
  'opalert'=> 9001 #OVER NINE THOUSAND!!!
);

%::COLORS =
(
  'white'   => '00',
  'black'   => '01',
  'blue'    => '02',
  'green'   => '03',
  'red'     => '04',
  'brown'   => '05',
  'purple'  => '06',
  'orange'  => '07',
  'yellow'  => '08',
  'ltgreen' => '09',
  'teal'    => '10',
  'ltcyan'  => '11',
  'ltblue'  => '12',
  'pink'    => '13',
  'grey'    => '14',
  'ltgrey'  => '15',
);

%::RCOLOR =
(
  $::RISKS{debug}  => $::COLORS{purple},
  $::RISKS{info}   => $::COLORS{blue},
  $::RISKS{low}    => $::COLORS{green},
  $::RISKS{medium} => $::COLORS{orange},
  $::RISKS{high}   => $::COLORS{red},
);

sub new
{
  my $module = shift;
  my $self = {};
  bless ($self);
  return $self;
}

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
  my ($module, $chan) = @_;
  $chan = lc $chan;
  return $::channels->{channel}->{default} unless defined($::channels->{channel}->{$chan});
  if ( defined($::channels->{channel}->{$chan}->{link}) ) {
    return $::channels->{channel}->{ $::channels->{channel}->{$chan}->{link} };
  }
  return $::channels->{channel}->{$chan};
}

sub getLink
{
  my ($module, $chan) = @_;
  $chan = lc $chan;
  my $link = $::channels->{channel}->{$chan}->{link};
  if ( defined($link) ) {
    return $link;
  }
  return $chan;
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
  my ($module, $c, $risk, $t) = @_;
  my @disable = ();
  my @x = ();
  $c = lc $c;
  foreach my $prisk ( keys %::RISKS) {
    if ( $::RISKS{$risk} >= $::RISKS{$prisk} ) {
      push( @x, @{$::channels->{channel}->{master}->{$t}->{$prisk}} ) if defined $::channels->{channel}->{master}->{$t}->{$prisk};
      push( @x, @{cs($module, $c)->{$t}->{$prisk}} ) if defined cs($module, $c)->{$t}->{$prisk};
    }
  }
  push( @disable, @{$::channels->{channel}->{master}->{$t}->{disable}} ) if defined $::channels->{channel}->{master}->{$t}->{disable};
  push( @disable, @{cs($module, $c)->{$t}->{disable}} ) if defined cs($module, $c)->{$t}->{disable};
  @x = unique(@x);
  @x = array_diff(@x, @disable);
  return @x;
}

sub commaAndify {
  my $module = shift;
  my @seq = @_;
  my $len = ($#seq);
  my $last = $seq[$len];
  return '' if $len eq -1;
  return $seq[0] if $len eq 0;
  return join( ' and ', $seq[0], $seq[1] ) if $len eq 1;
  return join( ', ', splice(@seq,0,$len) ) . ', and ' . $last;
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

return 1;
