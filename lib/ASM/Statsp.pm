package ASM::Statsp;
no autovivification;
use warnings;
use strict;

use Data::Dumper;
use IO::All;
use POSIX qw(strftime);
use ASM::Util;

no if $] >= 5.017011, warnings => 'experimental::smartmatch';

sub new
{
	my $module = shift;
	my ($conn) = @_;
	my $self = {};
	$self->{CONN} = $conn;
	bless($self);
	$conn->add_handler('statsdebug', \&on_statsdebug, 'after');
	$conn->add_handler('endofstats', \&on_endofstats, 'after');
	$conn->add_handler('263', \&on_whofuckedup, 'after');
	$conn->schedule(180, sub { $conn->sl('STATS p'); });
	return $self;
}

my $clearstatsp = 1;
my %statsp = ();
my %oldstatsp = ();

sub on_statsdebug
{
	my ($conn, $event) = @_;
	my ($char, $line) = ($event->{args}->[1], $event->{args}->[2]);
	if ($char eq 'p') {
		if ($clearstatsp) {
			$clearstatsp = 0;
			%oldstatsp = %statsp;
			%statsp = ();
		}
		if ($line =~ /^(\d+) staff members$/) {
			#this is the end of the report
		} else {
			my ($nick, $userhost) = split(" ", $line);
			$userhost =~ s/\((.*)\)/$1/;
			my ($user, $host) = split("@", $userhost);
			$statsp{$nick}= [$user, $host];
		}
	}
}

sub on_endofstats
{
	my ($conn, $event) = @_;
	if ($event->{args}->[1] eq 'p') {
		$clearstatsp=1;
		my $tmp = Dumper(\%statsp); chomp $tmp;
		if ( join(',', sort(keys %oldstatsp)) ne join(',', sort(keys %statsp)) ) {
			open(FH, '>>', 'statsplog.txt');
			say FH strftime('%F %T ', gmtime) . join(',', sort(keys %statsp));
			close(FH);
			ASM::Util->dprint(join(",", keys %statsp), 'statsp');
		}
		# $event->{args}->[2] == "End of /STATS report"
		#end of /stats p
		$conn->schedule( 90, sub { $conn->sl('STATS p') } );
	}
}

sub on_whofuckedup
{
	my ($conn, $event) = @_;
	if ($event->{args}->[1] eq "STATS") {
		$conn->schedule(30, sub { $conn->sl('STATS p') } );
	}
}

1;
