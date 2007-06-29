package ASM::Commander;
use warnings;
use strict;

sub new
{
  my $module = shift;
  my $self = {};
  bless($self);
  return $self;
}

sub command
{
  my ($self, $conn, $event) = @_;
  my $args = $event->{args}->[0];
  my $from = $event->{from};
  my $cmd = $args;
  my $d1;
  my $nick = lc $event->{nick};
  foreach my $command ( @{$::commands->{command}} )
  {
    if (defined($command->{flag})) {
      next unless defined($::users->{person}->{$nick});
      next unless defined($::users->{person}->{$nick}->{flags});
      next unless (grep {$_ eq $command->{flag}} split('', $::users->{person}->{$nick}->{flags}));
      if ($::users->{person}->{$nick}->{host} ne 'IDENTIFY') {
        next unless leq($::users->{person}->{$nick}->{host}, $event->{host});
      }
      else {
        if ( $cmd =~ /$command->{cmd}/ ){
          push (@{$::idqueue{$nick}}, [$cmd, $command, $event]);
          $conn->sl("whois $nick $nick");
          last;
        }
      }
    }
    if ($cmd=~/$command->{cmd}/) {
      print "$event->{from} told me: $cmd \n";
      eval $command->{content};
      warn $@ if $@;
      last;
    }
  }
}

1;
