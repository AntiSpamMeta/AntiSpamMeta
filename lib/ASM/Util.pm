package ASM::Util;
use Array::Utils qw(:all);
use POSIX qw(strftime);
use warnings;
use strict;
use Term::ANSIColor qw (:constants);
use Socket qw( inet_aton inet_ntoa );
use Data::Dumper;
use Carp qw(cluck);

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

#leaves room for more levels if for some reason we end up needing more
#theoretically, you should be able to change those numbers without any damage

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
  $chan =~ s/^[@+]//;
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
  $chan =~ s/^[@+]//;
  my $link = $::channels->{channel}->{$chan}->{link};
  if ( defined($link) ) {
    return $link;
  }
  return $chan;
}

sub speak
{
  my ($module, $chan) = @_;
  $chan = lc $chan;
  $chan =~ s/^[@+]//;
  if ( defined($::channels->{channel}->{$chan}->{silence}) ) {
    if ($::channels->{channel}->{$chan}->{silence} eq "no") {
      return 1;
    }
    elsif ($::channels->{channel}->{$chan}->{silence} eq "yes") {
      return 0;
    }
  }
  if ( defined($::channels->{channel}->{default}->{silence}) ) {
    if ( $::channels->{channel}->{default}->{silence} eq "no" ) {
      return 1;
    }
    elsif ( $::channels->{channel}->{default}->{silence} eq "yes" ) {
      return 0;
    }
  }
  return 1;
}

#this item is a stub, dur
sub hostip {
  #cluck "Calling gethostbyname in hostip";
  return gethostbyname($_[0]);
}

# If $tgts="#antispammeta" that's fine, and if $tgts = ["#antispammeta", "##linux-ops"] that's cool too
sub sendLongMsg {
  my ($module, $conn, $tgts, $txtz) = @_;
  if (length($txtz) <= 380) {
    $conn->privmsg($tgts, $txtz);
  } else {
    my $splitpart = rindex($txtz, " ", 380);
    $conn->privmsg($tgts, substr($txtz, 0, $splitpart));
    $conn->privmsg($tgts, substr($txtz, $splitpart));
  }
}

sub getAlert {
  my ($module, $c, $risk, $t) = @_;
  my @disable = ();
  my @x = ();
  $c = lc $c;
  $c =~ s/^[@+]//;
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

#I last worked on this function while having way too many pain meds, if it's fucked up, that's why.
sub dprint {
  my ($module, $text, $type) = @_;
  if (!defined($type)) {
    die "old method for dprint called!\n";
  }
  if (!defined($::debugx{$type})) {
    die "dprint called with invalid type!\n";
  }
  if ($::debugx{$type} eq 0) {
    return;
  }
  say STDERR strftime("%F %T ", gmtime),
                 GREEN, 'DEBUG', RESET, '(', $::debugx{$type}, $type, RESET, ') ', $text;
}


sub intToDottedQuad {
  my ($module, $num) = @_;
 return inet_ntoa(pack('N', $num)); 
}

sub dottedQuadToInt
{
  my ($module, $dottedquad) = @_;
#  my $ip_number = 0;
#  my @octets = split(/\./, $dottedquad);
#  foreach my $octet (@octets) {
#    $ip_number <<= 8;
#    $ip_number |= $octet;
#  }
#  return $ip_number;
 return unpack('N', inet_aton($dottedquad)); 
}

sub getHostIP
{
  my ($module, $host) = @_;
  if ( ($host =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) or
       ($host =~ /^gateway\/web\/.*\/ip\.(\d+)\.(\d+)\.(\d+)\.(\d+)$/) ) {
    #yay, easy IP!   
    return dottedQuadToInt(undef, "$1.$2.$3.$4");
  } elsif (index($host, '/') != -1) {
    return;
  } elsif ($host =~ /^2001:0:/) {
    my @splitip = split(/:/, $host);
    return unless defined($splitip[6]) && defined($splitip[7]);
    #I think I can just do (hex($splitip[6] . $splitip[7]) ^ hex('ffffffff')) here but meh
    my $host = join('.', unpack('C4', pack('N', (hex($splitip[6] . $splitip[7])^hex('ffffffff')))));
    return dottedQuadToInt(undef, $host);
  }
  #cluck "Calling gethostbyname in getHostIP";
  my @resolve = gethostbyname($host);
  return unless @resolve;
  return dottedQuadToInt(undef, join('.', unpack('C4', $resolve[4])));
}

sub getNickIP
{
  my ($module, $nick, $host) = @_;
  $nick = lc $nick;
  return unless defined($::sn{$nick});
  if (defined($::sn{$nick}{ip})) {
    return $::sn{$nick}{ip};
  }
  $host //= $::sn{$nick}{host};
  my $ip = getHostIP(undef, $host);
  if (defined($ip)) {
    $::sn{$nick}{ip} = $ip;
    return $ip;
  }
  return;
#  if ( ($host =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) or
#       ($host =~ /^gateway\/web\/freenode\/ip\.(\d+)\.(\d+)\.(\d+)\.(\d+)$/) ) {
#    #yay, easy IP!
#    $::sn{$nick}{ip} = dottedQuadToInt(undef, "$1.$2.$3.$4");
#    return $::sn{$nick}{ip};
#  } elsif (index($host, '/') != -1) {
#    return;
#  } elsif ($host =~ /^2001:0:/) {
#    my @splitip = split(/:/, $host);
#    #I think I can just do (hex($splitip[6] . $splitip[7]) ^ hex('ffffffff')) here but meh
#    my $host = join('.', unpack('C4', pack('N', (hex($splitip[6] . $splitip[7])^hex('ffffffff')))));
#    $::sn{$nick}{ip} = dottedQuadToInt(undef, $host);
#    return $::sn{$nick}{ip};
#  }
#  my @resolve = gethostbyname($::sn{$nick}{host});
#  return unless @resolve;
#  $::sn{$nick}{ip} = dottedQuadToInt(undef, join('.', unpack('C4', $resolve[4])));
#  return $::sn{$nick}{ip};
}

sub notRestricted {
  my ($module, $nick, $restriction) = @_;
  $nick = lc $nick;
  my $host = lc $::sn{$nick}{host};
  my $account = lc $::sn{$nick}{account};
  foreach my $regex (keys %{$::restrictions->{nicks}->{nick}}) {
    if ($nick =~ /^$regex$/i && defined($::restrictions->{nicks}->{nick}->{$regex}->{$restriction})) {
      dprint("blah", "Restriction $restriction found for $nick (nick $regex)", "restrictions");
      return 0;
    }
  }
  if ((defined($host)) && (defined($account))) {
    foreach my $regex (keys %{$::restrictions->{accounts}->{account}}) {
      if ($account =~ /^$regex$/i && defined($::restrictions->{accounts}->{account}->{$regex}->{$restriction})) {
        dprint("blah", "Restriction $restriction found for $nick (account $regex)", "restrictions");
        return 0;
      }
    }
    foreach my $regex (keys %{$::restrictions->{hosts}->{host}}) {
      if ($host =~ /^$regex$/i && defined($::restrictions->{hosts}->{host}->{$regex}->{$restriction})) {
        dprint("blah", "Restriction $restriction found for $nick (host $regex)", "restrictions");
        return 0;
      }
    }
  }
  return 1;
}

return 1;