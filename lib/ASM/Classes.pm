package ASM::Classes;
no autovivification;
use strict;
use warnings;
use Text::LevenshteinXS qw(distance);
use Data::Dumper;
use Regexp::Wildcards;
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

my %sf = ();

sub new
{
  my $module = shift;
  my $self = {};
  my $tbl = {
    "strblnew" => \&strblnew,
    "strblpcre" => \&strblpcre,
    "dnsbl" => \&dnsbl,
    "floodqueue" => \&floodqueue,
    "floodqueue2" => \&floodqueue2,
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
    "proxy" => \&proxy,
    "nickbl" => \&nickbl,
    "nickfuzzy" => \&nickfuzzy,
    "asciiflood" => \&asciiflood,
    "joinmsgquit" => \&joinmsgquit,
    "garbagemeter" => \&garbagemeter,
    "cyclebotnet" => \&cyclebotnet,
    "banevade" => \&banevade,
    "urlcrunch" => \&urlcrunch,
    "cloning" => \&cloning
  };
  $self->{ftbl} = $tbl;
  bless($self);
  return $self;
}

sub cloning {
  my ($chk, $id, $event, $chan, $rev) = @_;
  my $max = int($chk->{content});
  my @nicks = grep {
                    (defined($::sn{$_}->{host})) &&
                    (defined($::sn{$_}->{mship})) &&
                    ($::sn{$_}->{host} eq $event->{host}) &&
                    (lc $chan ~~ $::sn{$_}->{mship})
                   } keys %::sn;
  if ($#nicks >= $max) {
    return ASM::Util->commaAndify(@nicks);
  }
  return 0;
}

sub garbagemeter {
  my ($chk, $id, $event, $chan, $rev) = @_;
  my @cut = split(/:/, $chk->{content});
  my $limit = int($cut[0]);
  my $timeout = int($cut[1]);
  my $threshold = int($cut[2]);
  my $threshold2 = int($cut[3]);
  my $wordcount = 0;
  my $line = $event->{args}->[0];
  return 0 unless ($line =~ /^[A-Za-z: ]+$/);
  my @words = split(/ /, $line);
  return 0 unless ((scalar @words) >= $threshold2);
  foreach my $word (@words) {
    if (defined($::wordlist{lc $word})) {
      $wordcount += 1;
    }
    return 0 if ($wordcount >= $threshold);
  }
  return 1 if ( flood_add( $chan, $id, 0, $timeout ) == $limit );
  return 0;
}

sub joinmsgquit
{
  my ($chk, $id, $event, $chan, $rev) = @_;
  my $time = $chk->{content};
##STATE
  $chan = lc $chan; #don't know if this is necessary but I'm trying to track down some mysterious state tracking corruption
  return 0 unless defined($::sc{$chan}{users}{lc $event->{nick}}{jointime});
  return 0 unless defined($::sc{$chan}{users}{lc $event->{nick}}{msgtime});
  return 0 if ((time - $::sc{$chan}{users}{lc $event->{nick}}{jointime}) > $time);
  return 0 if ((time - $::sc{$chan}{users}{lc $event->{nick}}{msgtime}) > $time);
  return 1;
}

sub urlcrunch
{
  my ($chk, $id, $event, $chan, $response) = @_;
  return 0 unless defined($response);
  return 0 unless ref($response);
  return 0 unless defined($response->{_previous});
  return 0 unless defined($response->{_previous}->{_headers});
  return 0 unless defined($response->{_previous}->{_headers}->{location});
  if ($response->{_previous}->{_headers}->{location} =~ /$chk->{content}/i) {
    return 1;
  }
  return 0;
}

sub check
{
  my $self = shift;
  my $item = shift;
  return $self->{ftbl}->{$item}->(@_);
}

sub nickbl
{
  my ($chk, $id, $event, $chan, $rev) = @_;
  my $match = lc $event->{nick};
  foreach my $line (@::nick_blacklist) {
    if ($line eq $match) {
      return 1;
    }
  }
  return 0;
}

sub banevade
{
  my ($chk, $id, $event, $chan, $rev) = @_;
  my $ip = ASM::Util->getNickIP($event->{nick});
  return 0 unless defined($ip);
  if (defined($::sc{lc $chan}{ipbans}{$ip})) {
    return 1;
  }
  return 0;
}

sub proxy
{
  my ($chk, $id, $event, $chan, $rev) = @_;
  if (defined($rev) and ($rev =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)\./)) {
    if (defined($::proxies{"$4.$3.$2.$1"})) {
      return 1;
    }
  }
  return 0;
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

sub nickfuzzy
{
  my ($chk, $id, $event, $chan) = @_;
  my $nick = $event->{nick};
  $nick = $event->{args}->[0] if ($event->{type} eq 'nick');
  my ($fuzzy, $match) = split(/:/, $chk->{content});
  my @nicks = split(/,/, $match);
  foreach my $item (@nicks) {
    if (distance(lc $nick, lc $item) <= $fuzzy) {
      return 1;
    }
  }
  return 0;
}

sub dnsbl
{
  my ($chk, $id, $event, $chan, $rev) = @_;
#  return unless index($event->{host}, '/') == -1;
#  hopefully getting rid of this won't cause shit to assplode
#  but I'm getting rid of it so it can detect cgi:irc shit
#  return 0;
  if (defined $rev) {
    ASM::Util->dprint("Querying $rev$chk->{content}", "dnsbl");
    my $iaddr = gethostbyname( "$rev$chk->{content}" );
    my @dnsbl = unpack( 'C4', $iaddr ) if defined $iaddr;
    my $strip;
    if (@dnsbl) {
      $strip = sprintf("%s.%s.%s.%s", @dnsbl);
      ASM::Util->dprint("found host (rev $rev) in $chk->{content} - $strip", 'dnsbl');
    }
    if ((@dnsbl) && (defined($::dnsbl->{query}->{$chk->{content}}->{response}->{$strip}))) {
      $::lastlookup=$::dnsbl->{query}->{$chk->{content}}->{response}->{$strip}->{content};
      ASM::Util->dprint("chk->content: $chk->{content}", 'dnsbl');
      ASM::Util->dprint("strip: $strip", 'dnsbl');
      ASM::Util->dprint("result: " . $::dnsbl->{query}->{$chk->{content}}->{response}->{$strip}->{content}, 'dnsbl');
      $::sn{lc $event->{nick}}->{dnsbl} = 1;
      # lol really icky hax
      return $::dnsbl->{query}->{$chk->{content}}->{response}->{$strip}->{content};
    }
  }
  return 0;
}

sub floodqueue2 {
  my ($chk, $id, $event, $chan, $rev) = @_;
  my @cut = split(/:/, $chk->{content});

  my $cvt = Regexp::Wildcards->new(type => 'jokers');
  my $hit = 0;
  foreach my $mask ( keys %{$::sc{lc $chan}{quiets}}) {
    if ($mask !~ /^\$/) {
      my @div = split(/\$/, $mask);
      my $regex = $cvt->convert($div[0]);
      if (lc $event->{from} =~ lc $regex) {
        $hit = 1;
      }
    } elsif ( (defined($::sn{lc $event->{nick}}{account})) && ($mask =~ /^\$a:(.*)/)) {
      my @div = split(/\$/, $mask);
      my $regex = $cvt->convert($div[0]);
      if (lc ($::sn{lc $event->{nick}}{account}) =~ lc $regex) {
        $hit = 1;
      }
    }
  }
  return 0 unless $hit;

  return 1 if ( flood_add( $chan, $id, $event->{host}, int($cut[1]) ) == int($cut[0]) );
  return 0;
}

sub floodqueue {
  my ($chk, $id, $event, $chan, $rev) = @_;
  my @cut = split(/:/, $chk->{content});
  return 1 if ( flood_add( $chan, $id, $event->{host}, int($cut[1]) ) == int($cut[0]) );
  return 0;
}

sub asciiflood {
  my ($chk, $id, $event, $chan, $rev) = @_;
  my @cut = split(/:/, $chk->{content});
  return 0 if (length($event->{args}->[0]) < $cut[0]);
  return 0 if ($event->{args}->[0] =~ /[A-Za-z0-9]/);
  return 1 if ( flood_add( $chan, $id, $event->{host}, int($cut[2]) ) == int($cut[1]) );
  return 0;
}

sub cyclebotnet
{
  my ($chk, $id, $event, $chan, $rev) = @_;
  my ($cycletime, $queueamt, $queuetime) = split(/:/, $chk->{content});
  $chan = lc $chan; #don't know if this is necessary but I'm trying to track down some mysterious state tracking corruption
  return 0 unless defined($::sc{$chan}{users}{lc $event->{nick}}{jointime});
  return 0 if ((time - $::sc{$chan}{users}{lc $event->{nick}}{jointime}) > int($cycletime));
  return 1 if ( flood_add( $chan, $id, "cycle", int($queuetime)) == int($queueamt) );
  return 0;
}

sub nickspam {
  my ($chk, $id, $event, $chan) = @_;
  my @cut = split(/:/, $chk->{content});
  if ( length $event->{args}->[0] >= int($cut[0]) ) {
    my %users = %{$::sc{lc $chan}->{users}};
    my %x = map { $_=>$_ } keys %users;
    my @uniq = grep( $x{$_}, split( /[^a-zA-Z0-9_\\|`[\]{}^-]+/ , lc $event->{args}->[0]) );
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
          shift ( @{$cf{$nid}{$xchan}{$host}} );
          if ( (scalar @{$cf{$nid}{$xchan}{$host}}) == 0 ) {
            delete $cf{$nid}{$xchan}{$host};
            last;
          }
#          last if ( $#{ $cf{$nid}{$xchan}{$host} } == 0 );
#          shift ( @{$cf{$nid}{$xchan}{$host}} );
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
  # a bit ugly but this should avoid false positives on foolish humans
  # give them the benefit of the doubt if they talked before ... but not too recently
  # if we didn't see them join, assume they did talk at some point
  my $msgtime = $::sc{$chan}{users}{lc $event->{nick}}{msgtime} // 0;
  $msgtime ||= 1 if !$::sc{$chan}{users}{lc $event->{nick}}{jointime};
  return if $text =~ /^[^\w\s]+\w+\s*$/ && $msgtime && ($msgtime + $cf{$id}{timeout}) < time;
#  return unless length($text) >= 10;
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
  if ( scalar @{$cf{$id}{$chan}{$text}} == int($cut[0]) ) {
    $bs{$id}{$text} = time unless length($text) < 10;
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
  $text=~s/^\d*(.*)\d*$/$1/;
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
  if ( scalar @{$cf{$id}{$chan}{$text}} == int($cut[0]) ) {
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

sub strblnew {
  my ($chk, $xid, $event, $chan) = @_;
  my $match = lc $event->{args}->[0];
  foreach my $id (keys %{$::blacklist->{string}}) {
    next unless $::blacklist->{string}->{$id}->{type} eq "string";
    my $line = lc $::blacklist->{string}->{$id}->{content};
    my $idx = index $match, $line;
    if ( $idx != -1 ) {
      my $setby = $::blacklist->{string}->{$id}->{setby};
      $setby = substr($setby, 0, 1) . "\x02\x02" . substr($setby, 1);
      return defined($::blacklist->{string}->{$id}->{reason}) ?
        "id $id added by $setby because $::blacklist->{string}->{$id}->{reason}" :
        "id $id added by $setby for no reason";
    }
  }
  return 0;
}

sub strblpcre {
  my ($chk, $xid, $event, $chan) = @_;
  my $match = lc $event->{args}->[0];
  foreach my $id (keys %{$::blacklist->{string}}) {
    next unless $::blacklist->{string}->{$id}->{type} eq "pcre";
    my $line = lc $::blacklist->{string}->{$id}->{content};
    my $idx = index $match, $line;
    if ( $match =~ /$line/ ) {
      my $setby = $::blacklist->{string}->{$id}->{setby};
      $setby = substr($setby, 0, 1) . "\x02\x02" . substr($setby, 1);
      return defined($::blacklist->{string}->{$id}->{reason}) ?
        "id $id added by $setby because $::blacklist->{string}->{$id}->{reason}" :
        "id $id added by $setby for no reason";
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
  return 0 unless defined($::sn{lc $event->{nick}}->{gecos});
  my $match = $event->{from} . '!' . $::sn{lc $event->{nick}}->{gecos};
  return 1 if ($match =~ /$chk->{content}/);
  return 0;
}

sub invite {
  my ( $chk, $id, $event, $chan) = @_;
  return 1;
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
#    return $#{ @{$sf{$id}{$chan}{$host}}}+1;
    return scalar @{$sf{$id}{$chan}{$host}};
}

sub flood_process
{
  for my $id ( keys %sf ) {
    for my $chan ( keys %{$sf{$id}} ) {
      next if $chan eq 'timeout';
      for my $host ( keys %{$sf{$id}{$chan}} ) {
        next unless defined $sf{$id}{$chan}{$host}[0];
        while ( time >= $sf{$id}{$chan}{$host}[0] + $sf{$id}{'timeout'} ) {
          shift ( @{$sf{$id}{$chan}{$host}} );
          if ( (scalar @{$sf{$id}{$chan}{$host}}) == 0 ) {
            delete $sf{$id}{$chan}{$host};
            last;
          }
#          last if ( $#{ $sf{$id}{$chan}{$host} } == 0 );
#          shift ( @{$sf{$id}{$chan}{$host}} );
        }
      }
    }
  }
}

sub dump
{
  #%sf, %ls, %cf, %bs
  open(FH, ">", "sf.txt");
  print FH Dumper(\%sf);
  close(FH);
  open(FH, ">", "ls.txt");
  print FH Dumper(\%ls);
  close(FH);
  open(FH, ">", "cf.txt");
  print FH Dumper(\%cf);
  close(FH);
  open(FH, ">", "bs.txt");
  print FH Dumper(\%bs);
  close(FH);
}

1;
