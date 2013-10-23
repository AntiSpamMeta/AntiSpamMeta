package ASM::Commander;

use warnings;
use strict;
use IO::All;
use POSIX qw(strftime);
use Data::Dumper;
use URI::Escape;

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
  my $acct = lc $::sn{$nick}->{account};
#  return 0 unless (ASM::Util->speak($event->{to}->[0]));
  foreach my $command ( @{$::commands->{command}} )
  {
    my $fail = 0;
    unless ( (ASM::Util->speak($event->{to}->[0])) or (!ASM::Util->notRestricted($nick, "nocommands")) ) {
      next unless (defined($command->{nohush}) && ($command->{nohush} eq "nohush"));
    }
    if (defined($command->{flag})) { #If the command is restricted,
      if (!defined($::users->{person}->{$acct})) { #make sure the requester has an account
        $fail = 1;
      }
      elsif (!defined($::users->{person}->{$acct}->{flags})) { #make sure the requester has flags defined
        $fail = 1;
      }
      elsif (!(grep {$_ eq $command->{flag}} split('', $::users->{person}->{$acct}->{flags}))) { #make sure the requester has the needed flags
        $fail = 1;
      }
    }
    if ($cmd=~/$command->{cmd}/) {
      ASM::Util->dprint("$event->{from} told me: $cmd", "commander");
      if ($fail == 1) {
        $conn->privmsg($nick, "You don't have permission to use that command, or you're not signed into nickserv.");
      } else {
        eval $command->{content};
        warn $@ if $@;
      }
      last;
    }
  }
}

1;
