use strict;
use warnings;
use Data::Dumper;
#package Classes;

sub Classes::dnsbl {
  our (%aonx, $id, %dct, $event, $chan, $rev);
    if (defined $rev) {
      my $iaddr = hostip( "$rev$aonx{$id}{content}" );
      my @dnsbl = unpack( 'C4', $iaddr ) if defined $iaddr;
      $dct{$id} = $aonx{$id} if (@dnsbl);
    }
}

sub Classes::floodqueue {
  our (%aonx, $id, %dct, $event, $chan);
  my @cut=split(/:/, $aonx{$id}{content});
  $dct{$id} = $aonx{$id} if ( flood_add( $chan, $id, $event->{host}, int($cut[1]) ) == int($cut[0]) );
}

sub Classes::nickspam {
  our (%aonx, $id, %dct, $event, $chan);
     my @cut = split(/:/, $aonx{$id}{content});
     if ( length $event->{args}->[0] >= int($cut[0]) ) {
       %_ = map { $_=>$_ } lc keys %{$::sc{lc $chan}{users}};
       my @uniq = grep( $_{$_}, split( / /, lc $event->{args}->[0]) );
       $dct{$id} = $aonx{$id} if ( $#{ @uniq } >= int($cut[1]) );
     }
}

my %cf=();
my %bs=();

sub Classes::splitflood {
  our (%aonx, $id, %dct, $event, $chan);
  my $text;
  my @cut = split(/:/, $aonx{$id}{content});
  $cf{$id}{timeout}=int($cut[1]);
  if ($event->{type} =~ /^(public|notice|part|caction)$/) {
    $text=$event->{args}->[0];
  }
  return unless defined($text);
  return unless length($text) >= 10;
  if (defined($bs{$id}{$text}) && (time <= $bs{$id}{$text} + 600)) {
    $dct{$id}=$aonx{$id};
    return;
  }
  push( @{$cf{$id}{$chan}{$text}}, time );
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
  if ( $#{ @{$cf{$id}{$chan}{$text}}}+1 == int($cut[0]) ) {
    $dct{$id}=$aonx{$id};
    $bs{$id}{$text} = time;
  }
} 

sub Classes::re {
  our (%aonx, $id, %dct, $event, $chan);
     my $match = $event->{args}->[0];
     $match = $event->{nick} if ($event->{type} eq 'join');
     if ( (defined $aonx{$id}{nocase}) && ($aonx{$id}{nocase}) ) {
       $dct{$id}=$aonx{$id} if ($match =~ /$aonx{$id}{content}/i);
     }
     else {
       $dct{$id}=$aonx{$id} if ($match =~ /$aonx{$id}{content}/);
     }
}

sub Classes::nick {
  our (%aonx, $id, %dct, $event, $chan);
  if ( lc $event->{nick} eq lc $aonx{$id}{content} ) {
    $dct{$id} = $aonx{$id};
  }
}

sub Classes::ident {
  our (%aonx, $id, %dct, $event, $chan);
  if ( lc $event->{user} eq lc $aonx{$id}{content} ) {
    $dct{$id} = $aonx{$id};
  }
}

sub Classes::host {
  our (%aonx, $id, %dct, $event, $chan);
  if ( lc $event->{host} eq lc $aonx{$id}{content} ) {
    $dct{$id} = $aonx{$id};
  }
}

sub Classes::gecos {
  our (%aonx, $id, %dct, $event, $chan);
  if ( lc $::sn{lc $event->{nick}}->{gecos} eq lc $aonx{$id}{content} ) {
    $dct{$id} = $aonx{$id};
  }
}

sub Classes::nuhg {
  our (%aonx, $id, %dct, $event, $chan);
  my $match = $event->{from} . '!' . $::sn{lc $event->{nick}}->{gecos};
  if ( (defined $aonx{$id}{nocase}) && ($aonx{$id}{nocase}) ) {
    $dct{$id}=$aonx{$id} if ($match =~ /$aonx{$id}{content}/i);
  } else {
    $dct{$id}=$aonx{$id} if ($match =~ /$aonx{$id}{content}/);
  }
}

sub Classes::killsub {
  undef &Classes::dnsbl;
  undef &Classes::floodqueue;
  undef &Classes::nickspam;
  undef &Classes::re;
}

#$VAR1 = bless( {
#                 'to' => [
#                           '##asb-testing'
#                         ],
#                 'format' => 'mode',
#                 'from' => 'ChanServ!ChanServ@services.',
#                 'user' => 'ChanServ',
#                 'args' => [
#                             '+o',
#                             'AntiSpamMetaBeta',
#                             ''
#                           ],
#                 'nick' => 'ChanServ',
#                 'type' => 'mode',
#                 'userhost' => 'ChanServ@services.',
#                 'host' => 'services.'
#               }, 'Net::IRC::Event' );

return 1;
