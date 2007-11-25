package ASM::Classes;

use strict;
use warnings;
use Text::LevenshteinXS qw(distance);
use Data::Dumper;

my %sf = ();

sub new
{
  my $module = shift;
  my $self = {};
  my $tbl = {
    "strbl" => \&strbl,
    "dnsbl" => \&dnsbl,
    "floodqueue" => \&floodqueue,
    "nickspam" => \&nickspam,
    "splitflood" => \&splitflood,
    "advsplitflood" => \&advsplitflood,
    "re" => \&re,
    "nick" => \&nick,
    "ident" => \&ident,
    "host" => \&host,
    "gecos" => \&gecos,
    "nuhg" => \&nuhg,
    "levenflood" => \&levenflood,
  };
  $self->{ftbl} = $tbl;
  bless($self);
  return $self;
}

sub check
{
  my $self = shift;
  my $item = shift;
  return $self->{ftbl}->{$item}->(@_);
}

my %ls = ();
sub levenflood
{
  my ($chk, $id, $event, $chan) = @_;
  my $text;
  if ($event->{type} =~ /^(public|notice|part|caction)$/) {
    $text = $event->{args}->[0];
  }
  return 0 unless ( defined($text) && (length($text) >= 30) );
  if ( ! defined($ls{$chan}) ) {
    $ls{$chan} = [ $text ];
    return 0;
  }
  my @leven = @{$ls{$chan}};
  my $ret = 0;
  if ( $#leven >= 5 ) {
    my $mx = 0;
    foreach my $item ( @leven ) {
      next unless length($text) eq length($item);
      my $tld = distance($text, $item);
      if ($tld <= 4) {
        $mx = $mx + 1;
      }
    }
    if ($mx >= 5) {
      $ret = 1;
    }
  }
  push(@leven, $text);
  shift @leven if $#leven > 10;
  $ls{$chan} = \@leven;
  return $ret;
}

sub dnsbl
{
  my ($chk, $id, $event, $chan, $rev) = @_;
  return unless index($event->{host}, '/') == -1;
  if (defined $rev) {
    my $iaddr = gethostbyname( "$rev$chk->{content}" );
    my @dnsbl = unpack( 'C4', $iaddr ) if defined $iaddr;
    return 1 if (@dnsbl);
  }
  return 0;
}

sub floodqueue {
  my ($chk, $id, $event, $chan, $rev) = @_;
  my @cut = split(/:/, $chk->{content});
  return 1 if ( flood_add( $chan, $id, $event->{host}, int($cut[1]) ) == int($cut[0]) );
  return 0;
}

sub nickspam {
  my ($chk, $id, $event, $chan) = @_;
  my @cut = split(/:/, $chk->{content});
  if ( length $event->{args}->[0] >= int($cut[0]) ) {
    my %users = %{$::sc{lc $chan}->{users}};
    my %x = map { $_=>$_ } keys %users;
    my @uniq = grep( $x{$_}, split( /[ ,]+/ , lc $event->{args}->[0]) );
    return 1 if ( @uniq >= int($cut[1]) );
  }
  return 0;
}

my %cf=();
my %bs=();
my $cfc = 0;
sub process_cf
{
  foreach my $nid ( keys %cf ) {
    foreach my $xchan ( keys %{$cf{$nid}} ) {
      next if $xchan eq 'timeout';
      foreach my $host ( keys %{$cf{$nid}{$xchan}} ) {
        next unless defined $cf{$nid}{$xchan}{$host}[0];
        while ( time >= $cf{$nid}{$xchan}{$host}[0] + $cf{$nid}{'timeout'} ) {
          last if ( $#{ $cf{$nid}{$xchan}{$host} } == 0 );
          shift ( @{$cf{$nid}{$xchan}{$host}} );
        }
      }
    }
  }
}

sub splitflood {
  my ($chk, $id, $event, $chan) = @_;
  my $text;
  my @cut = split(/:/, $chk->{content});
  $cf{$id}{timeout}=int($cut[1]);
  if ($event->{type} =~ /^(public|notice|part|caction)$/) {
    $text=$event->{args}->[0];
  }
  return unless defined($text);
  return unless length($text) >= 10;
  if (defined($bs{$id}{$text}) && (time <= $bs{$id}{$text} + 600)) {
    return 1;
  }
  push( @{$cf{$id}{$chan}{$text}}, time );
  while ( time >= $cf{$id}{$chan}{$text}[0] + $cf{$id}{'timeout'} ) {
    last if ( $#{$cf{$id}{$chan}{$text}} == 0 );
    shift ( @{$cf{$id}{$chan}{$text}} );
  }
  $cfc = $cfc + 1;
  if ( $cfc >= 100 ) {
    $cfc = 0;
    process_cf();
  }
  if ( $#{@{$cf{$id}{$chan}{$text}}}+1 == int($cut[0]) ) {
    $bs{$id}{$text} = time;
    return 1;
  }
  return 0;
} 

sub advsplitflood {
  my ($chk, $id, $event, $chan) = @_;
  my $text;
  my @cut = split(/:/, $chk->{content});
  $cf{$id}{timeout}=int($cut[1]);
  if ($event->{type} =~ /^(public|notice|part|caction)$/) {
    $text=$event->{args}->[0];
  }
  return unless defined($text);
  $text=~s/^\d+(.*)\d+$/$1/;
  return unless length($text) >= 10;
  if (defined($bs{$id}{$text}) && (time <= $bs{$id}{$text} + 600)) {
    return 1;
  }
  push( @{$cf{$id}{$chan}{$text}}, time );
  while ( time >= $cf{$id}{$chan}{$text}[0] + $cf{$id}{'timeout'} ) {
    last if ( $#{$cf{$id}{$chan}{$text}} == 0 );
    shift ( @{$cf{$id}{$chan}{$text}} );
  }
  $cfc = $cfc + 1;
  if ( $cfc >= 100 ) {
    $cfc = 0;
    process_cf();
  }
  if ( $#{@{$cf{$id}{$chan}{$text}}}+1 == int($cut[0]) ) {
    $bs{$id}{$text} = time;
    return 1;
  }
  return 0;
}

sub re {
  my ($chk, $id, $event, $chan) = @_;
  my $match = $event->{args}->[0];
  $match = $event->{nick} if ($event->{type} eq 'join');
  return 1 if ($match =~ /$chk->{content}/);
  return 0;
}

sub strbl {
  my ($chk, $id, $event, $chan) = @_;
  my $match = lc $event->{args}->[0];
  foreach my $line (@::string_blacklist) {
    my $xline = lc $line;
    my $idx = index $match, $xline;
    if ( $idx != -1 ) {
      return 1;
    }
  }
  return 0;
}

sub nick {
  my ($chk, $id, $event, $chan) = @_;
  if ( lc $event->{nick} eq lc $chk->{content} ) {
    return 1;
  }
  return 0;
}

sub ident {
  my ( $chk, $id, $event, $chan) = @_;
  if ( lc $event->{user} eq lc $chk->{content} ) {
    return 1;
  }
  return 0;
}

sub host {
  my ( $chk, $id, $event, $chan) = @_;
  if ( lc $event->{host} eq lc $chk->{content} ) {
    return 1;
  }
  return 0;
}

sub gecos {
  my ( $chk, $id, $event, $chan) = @_;
  if ( lc $::sn{lc $event->{nick}}->{gecos} eq lc $chk->{content} ) {
    return 1;
  }
  return 0;
}

sub nuhg {
  my ( $chk, $id, $event, $chan) = @_;
  my $match = $event->{from} . '!' . $::sn{lc $event->{nick}}->{gecos};
  return 1 if ($match =~ /$chk->{content}/);
  return 0;
}

my $sfc = 0;

sub flood_add
{
    my ( $chan, $id, $host, $to ) = @_;
    push( @{$sf{$id}{$chan}{$host}}, time );
    while ( time >= $sf{$id}{$chan}{$host}[0] + $to ) {
      last if ( $#{ $sf{$id}{$chan}{$host} } == 0 );
      shift( @{$sf{$id}{$chan}{$host}} );
    }
    $sf{$id}{'timeout'} = $to;
    $sfc = $sfc + 1;
    if ($sfc > 100) {
      $sfc = 0;
      flood_process();
    }
    return $#{ @{$sf{$id}{$chan}{$host}}}+1;
}

sub flood_process
{
  for my $id ( keys %sf ) {
    for my $chan ( keys %{$sf{$id}} ) {
      next if $chan eq 'timeout';
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

1;
