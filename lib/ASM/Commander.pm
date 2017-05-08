package ASM::Commander;
no autovivification;

use v5.10;
use warnings;
use strict;
use IO::All;
use POSIX qw(strftime);
use Data::Dumper;
use URI::Escape;
use ASM::Shortener;
use Const::Fast;

no if $] >= 5.017011, warnings => 'experimental::smartmatch';

const my $secret   => 'flag_secret';
const my $hilights => 'flag_hilights';
const my $admin    => 'flag_admin';
const my $plugin   => 'flag_plugin';
const my $debug    => 'flag_debug';

const my %letter_to_flag => (
	s => $secret,
	h => $hilights,
	a => $admin,
	p => $plugin,
	d => $debug,
);

const my %flag_to_letter => reverse(%letter_to_flag);

my $cmdtbl = {
	'^;wallop' => {
		'flag' => $debug,
		'cmd' => \&cmd_wallop },
	'^;;addwebuser (?<pass>.{6,})' => {
		'flag' => $secret,
		'txn' => 1,
		'cmd' => \&cmd_addwebuser },
	'^;teredo (?<ip>\S+)' => {
		'cmd' => \&cmd_teredo },
	'^;status$' => {
		'cmd' => \&cmd_status },
	'^;mship (?<nick>\S+)' => {
		'flag' => $secret,
		'cmd' => \&cmd_mship },
	'^;source$' => {
		'cmd' => \&cmd_source },
	'^;monitor (?<chan>\S+) *$' => {
		'flag' => $secret,
		'cmd' => \&cmd_monitor },
	'^;monitor (?<chan>\S+) ?(?<switch>yes|no)$' => {
		'flag' => $admin,
		'cmd' => \&cmd_monitor2 },
	'^;suppress (?<chan>\S+) *$' => {
		'flag' => $secret,
		'cmd' => \&cmd_suppress },
	'^;unsuppress (?<chan>\S+) *$' => {
		'flag' => $secret,
		'cmd' => \&cmd_unsuppress },
	'^;silence (?<chan>\S+) *$' => {
		'flag' => $secret,
		'cmd' => \&cmd_silence },
	'^;silence (?<chan>\S+) (?<switch>yes|no) *$' => {
		'flag' => $admin,
		'cmd' => \&cmd_silence2 },
	'^;help$' => {
		'cmd' => \&cmd_help },
	'^;help (?<cmd>\S+)$' => {
		'cmd' => \&cmd_help2 },
	'^;db$' => {
		'cmd' => \&cmd_db },
	'^;query (\S+) ?(\S+)?$' => {
		'cmd' => \&cmd_query },
	'^;investigate (?<nick>\S+) *$' => {
		'flag' => $secret,
		'cmd' => \&cmd_investigate },
	'^;investigate2 (?<nick>\S+) ?(?<skip>\d*) *$' => {
		'flag' => $secret,
		'cmd' => \&cmd_investigate2 },
	'^;userx? (?:add|flags) (?<account>\S+) (?<flags>\S+)$' => {
		'flag' => $admin,
		'txn' => 1,
		'cmd' => \&cmd_user_set_flags },
	'^;userx? flags (?<account>\S+) ?$' => {
		'cmd' => \&cmd_user_get_flags },
	'^;userx? del (?<account>\S+)$' => {
		'flag' => $admin,
		'txn' => 1,
		'cmd' => \&cmd_user_del },
	'^;target (?<chan>\S+) (?<nickchan>\S+) ?(?<level>[a-z]*)$' => {
		'flag' => $admin,
		'cmd' => \&cmd_target },
	'^;detarget (?<chan>\S+) (?<nickchan>\S+)' => {
		'flag' => $admin,
		'cmd' => \&cmd_detarget },
	'^;showhilights (?<nick>\S+) *$' => {
		'flag' => $hilights,
		'cmd' => \&cmd_showhilights },
	'^;hilight (?<chan>\S+) (?<nicks>\S+) ?(?<level>[a-z]*)$' => {
		'flag' => $hilights,
		'cmd' => \&cmd_hilight },
	'^;dehilight (?<chan>\S+) (?<nicks>\S+)' => {
		'flag' => $hilights,
		'cmd' => \&cmd_dehilight },
	'^;join (?<chan>\S+)' => {
		'flag' => $admin,
		'cmd' => \&cmd_join },
	'^;part (?<chan>\S+)' => {
		'flag' => $admin,
		'cmd' => \&cmd_part },
	'^;sl (?<string>.+)' => {
		'flag' => $debug,
		'cmd' => \&cmd_sl },
	'^;quit ?(?<reason>.*)' => {
		'flag' => $admin,
		'cmd' => \&cmd_quit },
	'^;ev (?<string>.*)' => {
		'flag' => $debug,
		'cmd' => \&cmd_ev },
	'^;rehash$' => {
		'flag' => $admin,
		'cmd' => \&cmd_rehash },
	'^;restrict (?<type>nick|account|host) (?<who>\S+) (?<mode>\+|-)(?<restriction>[a-z0-9_-]+)$' => {
		'flag' => $admin,
		'cmd' => \&cmd_restrict },
	'^\s*\!ops ?(?<chan>#\S+)? ?(?<reason>.*)' => {
		'nohush' => 'nohush',
		'cmd' => \&cmd_ops },
	'^;blacklist (?<string>.+)' => {
		'flag' => $secret,
		'cmd' => \&cmd_blacklist },
	'^;blacklistpcre (?<string>.+)' => {
		'flag' => $admin,
		'cmd' => \&cmd_blacklistpcre },
	'^;unblacklist (?<id>[0-9a-f]+)$' => {
		'flag' => $secret,
		'cmd' => \&cmd_unblacklist },
	'^;plugin (?<chan>\S+) (?<risk>\S+) (?<reason>.*)' => {
		'flag' => $plugin,
		'cmd' => \&cmd_plugin },
	'^;sync (?<chan>\S+)' => {
		'flag' => $admin,
		'cmd' => \&cmd_sync },
	'^;ping\s*$' => {
		'cmd' => \&cmd_ping },
	'^;ping (?<string>\S.*)$' => {
		'flag' => $secret,
		'cmd' => \&cmd_ping2 },
	'^;blreason (?<id>[0-9a-f]+) (?<reason>.*)' => {
		'flag' => $secret,
		'cmd' => \&cmd_blreason },
	'^;bllookup (?<id>[0-9a-f]+)$' => {
		'flag' => $secret,
		'cmd' => \&cmd_bllookup },
	'^;falsematch\b' => {
		'flag' => $secret,
		'cmd' => \&cmd_falsematch },
	'^;version$' => {
		'cmd' => \&cmd_version },
};

sub new {
	my $module = shift;
	my ($conn) = @_;
	my $self = {};
	$self->{cmdtbl} = $cmdtbl;
	$self->{CONN} = $conn;
	bless($self);
	$conn->add_handler('msg', sub { command($self, @_); }, "after");
	$conn->add_handler('public', sub { command($self, @_); }, "after");
	return $self;
}

sub command {
	my ($self, $conn, $event) = @_;
	my $args = $event->{args}->[0];
	my $from = $event->{from};
	my $cmd = $args;
	my $d1;
	my $nick = lc $event->{nick};
	my $acct;
	if (defined($::sn{$nick}) && defined($::sn{$nick}->{account})) {
		$acct = lc $::sn{$nick}->{account};
	}
	foreach my $command ( keys %{$self->{cmdtbl}} )
	{
		my $fail = 0;
		unless ( (ASM::Util->speak($event->{to}->[0])) ) {
			next unless (defined($self->{cmdtbl}->{$command}->{nohush}));
		}
		if ($cmd=~/$command/) {
			my $where = $event->{to}[0];
			if (index($where, '#') == -1) {
				$where = 'PM';
			}
			ASM::Util->dprint("$event->{from} told me in $where: $cmd", "commander");

			if (!ASM::Util->notRestricted($nick, "nocommands")) {
				$fail = 1;
			}

			my $check_and_run_command = sub {
				# If the command is restricted,
				if ( my $flag = $self->{cmdtbl}->{$command}->{flag} ) {
					# require an account
					if (!defined($acct)) {
						$fail = 1;
					}
					else {
						# and check for the flag
						my $user = $::db->resultset('User')->by_name($acct);
						if (!defined $user || !$user->$flag) {
							$fail = 1;
						}
					}
				}

				if ($fail == 1) {
					$conn->privmsg($nick, "You don't have permission to use that command, or you're not signed into nickserv.");
				} else {
					&{$self->{cmdtbl}->{$command}->{cmd}}($conn, $event);
				}
			};

			# Do we need to wrap the entire command - including the permission check - in a transaction?
			# Be careful; due to re-establishing a DB connection, this requires the command's code to
			# be idempotent. See the DBIx::Class::Storage documentation on the txn_do method for details.
			if ($self->{cmdtbl}{$command}{txn}) {
				$::db->txn_do($check_and_run_command);
			}
			else {
				$check_and_run_command->();
			}

			last;
		}
	}
}

1;

sub cmd_wallop {
	my ($conn, $event) = @_;
	
	my @chans = ();
	foreach my $chan (keys %{$::channels->{channel}}) {
		if (defined($::channels->{channel}->{$chan}->{msgs})) {
			foreach my $risk (keys %{$::channels->{channel}->{$chan}->{msgs}}) {
				push @chans, @{$::channels->{channel}->{$chan}->{msgs}->{$risk}};
			}
		}
	}
	my %uniq = ();
	foreach my $chan (@chans) { $uniq{$chan} = 1; }
	@chans = keys(%uniq);
	print Dumper(\@chans);
}

sub cmd_addwebuser {
	my ($conn, $event) = @_;
	
	my $pass = $+{pass};
	if ($event->{to}->[0] =~ /^#/) {
		$conn->privmsg($event->replyto, "This command must be used in PM. Try again WITH A DIFFERENT PASSWORD!");
		return;
	}
	my $user = $::db->resultset('User')->by_name(lc $::sn{lc $event->{nick}}->{account});
	$user->passphrase($pass);
	$user->update;

	my $name = $user->name;
	$conn->privmsg($event->replyto, "Added $name to the list of authorized web users.")
}

sub cmd_teredo {
	my ($conn, $event) = @_;

	my $arg1 = $+{ip};
	my @splitip = split(/:/, $arg1);
	if ( (int($splitip[0]) != 2001) || (int($splitip[1]) != 0) ) {
		$conn->privmsg($event->replyto, "This is not a teredo-tunnelled IP.");
		return;
	}
	my $server = join('.', unpack('C4', pack('N', hex($splitip[2] . $splitip[3]))));
	my $host = join('.', unpack('C4', pack('N', (hex($splitip[6] . $splitip[7])^hex('ffffffff')))));
	my $port = hex($splitip[5]) ^ hex('ffff');
	$conn->privmsg($event->replyto, "Source is $host:$port; teredo server in use is $server.");
}

sub cmd_status {
	my ($conn, $event) = @_;

	my $size = `pmap -X $$ | tail -n 1`;
	$size =~ s/^\s+|\s+$//g;
	my @temp = split(/ +/, $size);
	$size = $temp[1] + $temp[5];
	my $cputime = `ps -p $$ h -o time`;
	chomp $cputime;
	my $upstr = '';
	my $up = (time - $::starttime);
	if (int($up/86400) != 0) { #days
		$upstr = $upstr . int($up/86400) . 'd';
		$up = $up % 86400;
	}
	if (int($up/3600) != 0) { #hours
		$upstr = $upstr . int($up/3600) . 'h';
		$up = $up % 3600;
	}
	if (int($up/60) != 0) { #minutes
		$upstr = $upstr . int($up/60) . 'm';
		$up = $up % 60;
	}
	if (int($up/1) != 0) { #seconds
		$upstr = $upstr . int($up/1) . 's';
		$up = $up % 1;
	}
	my ($tx, $rx);
	if ($conn->{_tx}/1024 > 1024) {
		$tx = sprintf("%.2fMB", $conn->{_tx}/(1024*1024));
	} else {
		$tx = sprintf("%.2fKB", $conn->{_tx}/1024);
	}
	if ($conn->{_rx}/1024 > 1024) {
		$rx = sprintf("%.2fMB", $conn->{_rx}/(1024*1024));
	} else {
		$rx = sprintf("%.2fKB", $conn->{_rx}/1024);
	}
	$conn->privmsg($event->replyto, "This bot has been running for " . $upstr .
			", is tracking " . (scalar (keys %::sn)) . " nicks" .
			" across " . (scalar (keys %::sc)) . " tracked channels." .
			" It is using " . $size . "KB of RAM" . 
			", has used $cputime of CPU time" .
			", has sent $tx of data, and received $rx of data.");
}

sub cmd_mship {
	my ($conn, $event) = @_;

	my $nick = lc $+{nick};
	if (defined($::sn{$nick})) {
		if ($event->{to}->[0] =~ /^#/) {
			$conn->privmsg($event->replyto, $nick . " is on: " . ASM::Util->commaAndify(sort(grep { not grep { /^s$/ } @{$::sc{$_}{modes}} } @{$::sn{$nick}->{mship}})));
		} else {
			$conn->privmsg($event->replyto, $nick . " is on: " . ASM::Util->commaAndify(sort @{$::sn{$nick}->{mship}}));
		}
	} else {
		$conn->privmsg($event->replyto, "I don't see $nick.");
	}
}

sub cmd_source {
	my ($conn, $event) = @_;

	$conn->privmsg($event->replyto, 'source is at http://asm.rocks/source');
}

sub cmd_monitor {
	my ($conn, $event) = @_;

	my $chan = lc $+{chan};
	my $switch = $::channels->{channel}->{$chan}->{monitor} // 'yes';
	$conn->privmsg($event->replyto, "Monitor flag for $chan is currently set to $switch");
}

sub cmd_monitor2 {
	my ($conn, $event) = @_;

	my $chan = lc $+{chan};
	my $switch = lc $+{switch};
	$::channels->{channel}->{$chan}->{monitor} = $switch;
	ASM::Config->writeChannels();
	$conn->privmsg($event->replyto, "Monitor flag for $chan set to $switch");
}

sub cmd_suppress {
	my ($conn, $event) = @_;

	my $minutes  = 30;
	my $duration = $minutes * 60;

	my $chan = lc $1;
	my $old = $::channels->{channel}->{$chan}->{monitor};
	if ($old eq 'no') {
		$conn->privmsg($event->replyto, "$chan is not currently monitored");
		return;
	}
	$::channels->{channel}->{$chan}->{suppress} = time + $duration;
	$conn->schedule($duration, sub {
				if (($::channels->{channel}{$chan}{suppress} // 0) - 10 <= time) {
					# we needn't actually delete this here, but doing so
					# avoids cluttering the config
					delete $::channels->{channel}{$chan}{suppress};
					$conn->privmsg($event->replyto, "Unsuppressed $chan");
					ASM::Config->writeChannels();
				}
			});
	$conn->privmsg($event->replyto, "Suppressing alerts from $chan for $minutes minutes.");
}

sub cmd_unsuppress {
	my ($conn, $event) = @_;

	my $chan = lc $1;
	if (ASM::Util->isSuppressed($chan)) {
		delete $::channels->{channel}{$chan}{suppress};
		$conn->privmsg($event->replyto, "Unsuppressed $chan");
	}
	else {
		$conn->privmsg($event->replyto, "Alerts for $chan are not currently suppressed");
	}
}

sub cmd_silence {
	my ($conn, $event) = @_;

	my $chan = lc $+{chan};
	my $switch = $::channels->{channel}->{$chan}->{silence} // 'no';
	$conn->privmsg($event->replyto, "Silence flag for $chan is currently set to $switch");
}

sub cmd_silence2 {
	my ($conn, $event) = @_;

	my $chan = lc $+{chan};
	my $switch = lc $+{switch};
	$::channels->{channel}->{$chan}->{silence} = $switch;
	ASM::Config->writeChannels();
	$conn->privmsg($event->replyto, "Silence flag for $chan set to $switch");
}

sub cmd_help {
	my ($conn, $event) = @_;

	$conn->privmsg($event->replyto, "Please refer to http://antispammeta.net and irc.freenode.net #antispammeta");
}

sub cmd_help2 {
	my ($conn, $event) = @_;

	my @cmds = grep { $_ =~ /\Q$+{cmd}/} (keys %{$cmdtbl});
	if ((scalar @cmds) > 2) {
		$conn->privmsg($event->replyto, "Please refer to http://antispammeta.net and irc.freenode.net #antispammeta");
	} else {
		foreach my $cmd (@cmds) {
			$conn->privmsg($event->replyto, ($cmdtbl->{$cmd}->{flag} // ' ') . ' ' . $cmd)
		}
	}
}

sub cmd_db {
	my ($conn, $event) = @_;

	$conn->privmsg($event->replyto, "db is at http://antispammeta.net/query.html");
}

sub sql_wildcard {
	my ($str) = @_;
	# Ugh ...
	$str =~  s/\*/%/g;
	$str =~ s/_/\\_/g;
	$str =~  s/\?/_/g;

	return $str;
}

sub cmd_query {
	my ($conn, $event) = @_;

	return unless defined $::db;
	my $channel = defined($2) ? $1 : '%';
	my ($nick, $user, $host) = split(/(\!|\@)/, defined($2) ? $2 : $1);

	my $result = $::db->resultset('Alertlog')->count( {
			channel => { like => sql_wildcard($channel) },
			nick => { like => sql_wildcard($nick) },
			user => { like => sql_wildcard($user) },
			host => { like => sql_wildcard($host) },
		});
	$conn->privmsg($event->replyto, "$result results found.");
}

sub cmd_investigate {
	my ($conn, $event) = @_;

	return unless defined $::db;
	my $nick = lc $+{nick};
	unless (defined($::sn{$nick})) {
		$conn->privmsg($event->replyto, "I don't see $nick in my state tracking database, so I can't run any queries on their info, sorry :(" .
			       " You can try https://antispammeta.net/cgi-bin/secret/investigate.pl?nick=$nick instead!");
		return;
	}
	my $person = $::sn{$nick};
	my $user = lc $person->{user};
	my $gecos = lc $person->{gecos};
	my $acc = $person->{account};
	
	my $actions = $::db->resultset('Actionlog');
	my $mnicks = $actions->count({ nick => $nick });
	my $mhosts = $actions->count({ host => $person->{host} });
	my $maccts;
	my $musers;
	my $mgecos;

	if (defined $acc and $acc ne '0' and $acc ne '*') {
		$maccts = $actions->count({ account => $acc });
	}

	if ($user !~ $::mysql->{ignoredidents}) {
		$musers = $actions->count({ user => $person->{user} });
	}

	if ($gecos !~ $::mysql->{ignoredgecos}) {
		$mgecos = $actions->count({ gecos => $person->{gecos} });
	}
	
	my $matchedip;
	my $ip = ASM::Util->getNickIP($nick);
	if (defined $ip) {
		$matchedip = $actions->count({ ip => $ip });
	}

	my $dq;
	if (defined($ip)) {
		$dq = join '.', unpack 'C4', pack 'N', $ip;
	}

	my $found_by_fmt = '%s%s by %s (%s)';
	my @found;

	push @found, sprintf $found_by_fmt, $mnicks,             ' matches', 'nick',             $nick;
	push @found, sprintf $found_by_fmt, ($musers // "didn't check"), '', 'user',             $person->{user};
	push @found, sprintf $found_by_fmt, $mhosts,                     '', 'hostname',         $person->{host};
	push @found, sprintf $found_by_fmt, $maccts,                     '', 'NickServ account', $person->{account} if defined $maccts;
	push @found, sprintf $found_by_fmt, ($mgecos // "didn't check"), '', 'gecos field',      $person->{gecos};
	push @found, sprintf $found_by_fmt, $matchedip,                  '', 'real IP',          $dq if defined $ip;

	my $all_found = ASM::Util->commaAndify(@found);

	my @queries;
	push @queries, 'nick='    . uri_escape($nick);
	push @queries, 'user='    . uri_escape($person->{user}) if defined $musers;
	push @queries, 'host='    . uri_escape($person->{host});
	push @queries, 'account=' . uri_escape($person->{account}) if defined $maccts;
	push @queries, 'gecos='   . uri_escape($person->{gecos}) if defined $mgecos;
	push @queries, 'realip='  . uri_escape($dq) if defined $ip;

	my $query_string = join '&', @queries;

	$conn->privmsg( $event->replyto, "I found $all_found. " .
		ASM::Shortener->shorturl("https://antispammeta.net/cgi-bin/secret/investigate.pl?$query_string") );
}

sub cmd_investigate2 {
	my ($conn, $event) = @_;

	return unless defined $::db;
	my $nick = lc $+{nick};
	my $skip = 0;
	$skip = $+{skip} if (defined($+{skip}) and ($+{skip} ne ""));
	$skip = 1 if $skip < 1;
	$skip = int(2**31-1) if $skip > int(2**31-1);
	cmd_investigate($conn, $event);
	unless (defined($::sn{$nick})) {
		return;
	}
	my $person = $::sn{$nick};

	my $acc = $person->{account};
	undef $acc if $acc eq '0' or $acc eq '*';

	my $ip = ASM::Util->getNickIP($nick);

	my $query = [
		nick => $nick,
		host => $person->{host},
		(defined $acc ? (account => $acc) : ()),
		(defined $ip ? (ip => $ip) : ()),
		($person->{user} ~~ $::mysql->{ignoredidents} ? () : (user => $person->{user})),
		($person->{gecos} ~~ $::mysql->{ignoredgecos} ? () : (gecos => $person->{gecos})),
	];

	my @incidents = $::db->resultset('Actionlog')->search($query, {
			order_by => { -desc => 'time' },
			rows => 10,
			page => $skip,
		})->all;

	if (@incidents) {
		$conn->privmsg($event->replyto, 'Sending you the results...');
	} else {
		$conn->privmsg($event->replyto, 'No results to send!');
		return;
	}

	my $format = '#%d: %s %s!%s@%s (%s) %s%s%s%s';
	for my $line (@incidents) {
		my $out = sprintf $format, ($line->index, $line->time, $line->nick, $line->user, $line->host, $line->gecos, $line->action,
			(defined $line->reason ? ' (' . $line->reason . ')' : ''),
			(defined $line->channel ? ' on ' . $line->channel : ''),
			(defined $line->bynick ? ' by ' . $line->bynick : ''),
		);

		$conn->privmsg($event->nick, $out);
	}

	$conn->privmsg($event->nick, "Only 10 results are shown at a time. For more, do ;investigate2 $nick " . ($skip+1) . '.');
}

sub get_user_flagstring {
	my ($user) = @_;

	my $string = '';

	for my $letter (sort keys %letter_to_flag) {
		my $flag = $letter_to_flag{$letter};

		$string .= $letter if $user->$flag;
	}

	return $string;
}

sub set_user_flagstring {
	my ($user, $string) = @_;

	while (my ($letter, $flag) = each %letter_to_flag) {
		if (index($string, $letter) != -1) {
			$user->$flag(1);
		}
		else {
			$user->$flag(0);
		}
	}
}

sub is_flagstring_superset {
	my ($super, $sub) = @_;
	for my $letter (split //, $sub) {
		return 0 if index($super, $letter) == -1;
	}
	return 1;
}

sub cmd_user_set_flags {
	my ($conn, $event) = @_;

	my $nick = lc $+{account};
	my $account;
	my $flags = $+{flags};

	# we need to be idempotent if interrupted halfway.
	# TODO: this is rather ugly / error-prone.
	state $sent_message = 0;

	if ( (defined($::sn{$nick}->{account})) && ( ($account = lc $::sn{$nick}->{account}) ne $nick ) ) {
		$conn->privmsg($event->replyto, "I'm assuming you mean " . $nick . "'s nickserv account, " . $account . '.')
			if !($sent_message++);
		$nick = $account;
	}

	my $giver = $::db->resultset('User')->by_name( lc $::sn{lc $event->{nick}}{account} );

	my $own_flags = get_user_flagstring($giver);

	if (!is_flagstring_superset($own_flags, $flags)) {
		$conn->privmsg($event->replyto, "You can't give a flag you don't already have.");
		$sent_message = 0;
		return;
	}
	if ($flags =~ /d/) {
		$conn->privmsg($event->replyto, "The d flag may not be assigned over IRC. Edit the database manually.");
		$sent_message = 0;
		return;
	}

	my $target = $::db->resultset('User')->by_name_or_new( $nick );

	if ($target->flag_debug) {
		$conn->privmsg($event->replyto, "Users with the 'd' flag are untouchable. Edit the database manually.");
		$sent_message = 0;
		return;
	}

	set_user_flagstring($target, $flags);
	$target->update_or_insert;

	$sent_message = 0;
	$conn->privmsg($event->replyto, "Flags for NickServ account $nick set to $flags");
}

sub cmd_user_get_flags {
	my ($conn, $event) = @_;

	my $nick = lc $+{account};
	my $account;
	if ( defined($::sn{$nick}) && (defined($::sn{$nick}->{account})) && ( ($account = lc $::sn{$nick}->{account}) ne $nick ) ) {
		$conn->privmsg($event->replyto, "I'm assuming you mean " . $nick . "'s nickserv account, " . $account . '.');
		$nick = $account;
	}
	my $sayNick = substr($nick, 0, 1) . "\x02\x02" . substr($nick, 1);

	my $user = $::db->resultset('User')->by_name($nick);

	if (defined $user and length( my $flags = get_user_flagstring($user) )) {
		$conn->privmsg($event->replyto, "Flags for $sayNick: $flags");
	}
	else {
		$conn->privmsg($event->replyto, "$sayNick has no flags");
	}
}

sub cmd_user_del {
	my ($conn, $event) = @_;

	my $nick = lc $+{account};

	my $target = $::db->resultset('User')->by_name($nick);
	if (!defined $target) {
		$conn->privmsg($event->replyto, "I know no user by that name. Make sure you specified the account name.");
		return;
	}
	if ($target->flag_debug) {
		$conn->privmsg($event->replyto, "Users with the 'd' flag are untouchable. Edit the database manually.");
		return;
	}
	$target->delete;
	$conn->privmsg($event->replyto, "Removed $nick from authorized users." .
		       " MAKE SURE YOU PROVIDED a nickserv account to this command, rather than an altnick of the accountholder");
}

sub cmd_target {
	my ($conn, $event) = @_;

	my $chan = lc $+{chan};
	my $nick = lc $+{nickchan};
	my $level= $+{level};
	my $link = lc ASM::Util->getLink($chan);
	if ( $link ne $chan ) {
		$conn->privmsg($event->replyto, "Error: $chan is linked to $link - use $link instead.");
		return;
	}
	if ($level eq '') { $level = 'debug'; }
	unless (defined($::channels->{channel}->{$chan}->{msgs})) {
		$::channels->{channel}->{$chan}->{msgs} = {};
	}
	unless (defined($::channels->{channel}->{$chan}->{msgs}->{$level})) {
		$::channels->{channel}->{$chan}->{msgs}->{$level} = [];
	}
	my @tmphl = @{$::channels->{channel}->{$chan}->{msgs}->{$level}};
	push(@tmphl, $nick);
	$::channels->{channel}->{$chan}->{msgs}->{$level} = \@tmphl;
	ASM::Config->writeChannels();
	$conn->privmsg($event->replyto, "$nick added to $level risk messages for $chan");
}

sub cmd_detarget {
	my ($conn, $event) = @_;

	my $chan = lc $+{chan};
	my $nick = lc $+{nickchan};
	my $link = lc ASM::Util->getLink($chan);
	if ( $link ne $chan ) {
		$conn->privmsg($event->replyto, "Error: $chan is linked to $link - use $link instead.");
		return;
	}
	foreach my $risk ( keys %::RISKS ) {
		next unless defined($::channels->{channel}->{$chan}->{msgs}->{$risk});
		my @ppl = @{$::channels->{channel}->{$chan}->{msgs}->{$risk}};
		@ppl = grep { lc $_ ne $nick } @ppl;
		$::channels->{channel}->{$chan}->{msgs}->{$risk} = \@ppl;
	}
	ASM::Config->writeChannels();
	$conn->privmsg($event->replyto, "$nick removed from targets for $chan");
}

sub cmd_showhilights {
	my ($conn, $event) = @_;

	my $nick = lc $+{nick};
	my @channels = ();
	foreach my $chan (keys(%{$::channels->{channel}})) {
		foreach my $level (keys(%{$::channels->{channel}->{$chan}->{hilights}})) {
			my @nicks = map { lc } @{$::channels->{channel}->{$chan}->{hilights}->{$level}};
			if ( $nick ~~ @nicks) {
				push @channels, $chan . " ($level)";
			}
		}
	}
	if (! @channels) {
		$conn->privmsg($event->replyto, "$nick isn't on any hilights");
	} else {
		$conn->privmsg($event->replyto, "$nick is hilighted for " . join(', ', @channels));
	}
}

sub cmd_hilight {
	my ($conn, $event) = @_;

	my $chan = lc $+{chan};
	my $nick_str = lc $+{nicks};
	my @nicks = split(/,/, $nick_str);
	my $level= $+{level} // '';
	if ($level eq '') { $level = 'info'; }
	if ($level !~ /^(disable|debug|info|low|medium|high|opalert)$/) {
		$conn->privmsg($event->replyto, "Error: I don't recognize $level as a valid level.");
		return;
	}
	my $link = lc ASM::Util->getLink($chan);
	if ( $link ne $chan ) {
		$conn->privmsg($event->replyto, "Error: $chan is linked to $link - use $link instead.");
		return;
	}
	my $chan_regex = qr/^#|^default$|^master$/;
	if ( $chan !~ $chan_regex ) {
		my $msg = "Error: '$chan' doesn't look like a channel to me.";
		if ( $nick_str =~ $chan_regex ) {
			$msg .= ' (Maybe you just specified nick and channel in the wrong order?)';
		}
		$conn->privmsg($event->replyto, $msg);
		return;
	}
	unless (defined($::channels->{channel}->{$chan}->{hilights})) {
		$::channels->{channel}->{$chan}->{hilights} = {};
	}
	unless (defined($::channels->{channel}->{$chan}->{hilights}->{$level})) {
		$::channels->{channel}->{$chan}->{hilights}->{$level} = [];
	}
	my @tmphl = @{$::channels->{channel}->{$chan}->{hilights}->{$level}};
	foreach my $nick (@nicks) {
		push(@tmphl, $nick);
	}
	$::channels->{channel}->{$chan}->{hilights}->{$level} = \@tmphl;
	ASM::Config->writeChannels();
	$conn->privmsg($event->replyto, ASM::Util->commaAndify(@nicks) . " added to $level risk hilights for $chan");
}

sub cmd_dehilight {
	my ($conn, $event) = @_;

	my $chan = lc $+{chan};
	my @nicks = split(/,/, lc $+{nicks});
	my $link = lc ASM::Util->getLink($chan);
	if ( $link ne $chan ) {
		$conn->privmsg($event->replyto, "Error: $chan is linked to $link - use $link instead.");
		return;
	}
	foreach my $risk ( keys %::RISKS ) {
		next unless defined($::channels->{channel}->{$chan}->{hilights}->{$risk});
		my @ppl = @{$::channels->{channel}->{$chan}->{hilights}->{$risk}};
		@ppl = grep { !(lc $_ ~~ @nicks) } @ppl;
		$::channels->{channel}->{$chan}->{hilights}->{$risk} = \@ppl;
	}
	ASM::Config->writeChannels();
	$conn->privmsg($event->replyto, "Removing hilights for " . ASM::Util->commaAndify(@nicks) . " in $chan");
}

sub cmd_join {
	my ($conn, $event) = @_;

	my $chan = lc $+{chan};
	unless (defined($::channels->{channel}->{$chan})) {
		$::channels->{channel}->{$chan} = { monitor => "yes", silence => "no" };
		ASM::Config->writeChannels();
	}
	$conn->join($chan);
	my @autojoins = @{$::settings->{autojoins}};
	if (!grep { $chan eq lc $_ } @autojoins) {
		@autojoins = (@autojoins, $chan);
		$::settings->{autojoins} = \@autojoins;
		ASM::Config->writeSettings();
	}
}

sub cmd_part {
	my ($conn, $event) = @_;

	my $chan = lc $+{chan};
	$conn->part($chan);
	my @autojoins = @{$::settings->{autojoins}};
	@autojoins = grep { lc $_ ne $chan } @autojoins;
	$::settings->{autojoins} = \@autojoins;
	ASM::Config->writeSettings();
}

sub cmd_sl {
	my ($conn, $event) = @_;

	$conn->sl($+{string});
}

sub cmd_quit {
	my ($conn, $event) = @_;

	$conn->quit('Restart requested by ' . $event->{nick} . ': ' . $+{reason});
}

sub cmd_ev {
	my ($conn, $event) = @_;

	eval $+{string};
	warn $@ if $@;
}

sub cmd_rehash {
	my ($conn, $event) = @_;

	ASM::Config->readConfig();
	$conn->privmsg($event->replyto, 'config files were re-read');
}

sub cmd_restrict {
	my ($conn, $event) = @_;

	my $who = lc $+{who};
	if ($+{mode} eq '-') {
		delete $::restrictions->{$+{type} . 's'}->{$+{type}}->{$who}->{$+{restriction}};
		$conn->privmsg($event->replyto, "Removed $+{restriction} restriction for $+{type} $who");
	}
	if ($+{mode} eq '+') {
		if (! defined($::restrictions->{$+{type} . 's'}->{$+{type}}->{$who})) {
			$::restrictions->{$+{type} . 's'}->{$+{type}}->{$who} = {};
		}
		$::restrictions->{$+{type} . 's'}->{$+{type}}->{$who}->{$+{restriction}} = $+{restriction};
		$conn->privmsg($event->replyto, "Added $+{restriction} restriction for $+{type} $who");
	}
	ASM::Config->writeRestrictions();
}

my %ops_ignored;

sub cmd_ops {
	my ($conn, $event) = @_;

	my $tgt = lc $event->{to}->[0];
	my $msgtgt = $tgt;
	my $nick = lc $event->{nick};
	$tgt = lc $+{chan} if defined($+{chan});
	my $msg = $+{reason};
	if ( $tgt =~ /^#/ && ((($::channels->{channel}->{$tgt}->{monitor} // "yes") eq "no") || #we're not monitoring this channel
	     !($tgt ~~ $::sn{$nick}->{mship})) ) { #they're not on the channel they're calling !ops for
		return;
	}
	if (defined($::ignored{$tgt}) && ($::ignored{$tgt} >= $::RISKS{'opalert'})) {
		if (ASM::Util->notRestricted($nick, "noops")) {
			if ($msgtgt eq '##linux') {
				$conn->privmsg($event->{nick}, "I've already been recently asked to summon op attention. " .
					       "In the future, please use /msg $conn->{_nick} !ops $event->{to}->[0] reasonGoesHere" .
					       "	- this allows ops to be notified while minimizing channel hostility.");
			} elsif ($msgtgt eq lc $conn->{_nick}) {
				if ($tgt eq lc $conn->{_nick}) { # they privmsged the bot without providing a target
					$conn->privmsg($event->{nick}, "Sorry, it looks like you've tried to use the !ops command " .
						       "via PM but haven't specified a target. Try again with /msg $conn->{_nick} " .
						       "!ops #channelGoesHere ReasonGoesHere");
				} else {
					$conn->privmsg($event->{nick}, "I've already recently notified $tgt ops.");
				}
			}
		}
		return;
	}
	if (ASM::Util->notRestricted($nick, "noops")) {
		if ($msgtgt eq '##linux') {
			$conn->privmsg($event->{nick}, "I've summoned op attention. In the future, please use /msg " .
				       "$conn->{_nick} !ops $event->{to}->[0] reasonGoesHere	- this allows ops to " .
				       "be notified while minimizing channel hostility.");
		} elsif (($tgt eq '#wikipedia-en-help') && (!defined($msg))) {
			$conn->privmsg($event->{nick}, "I've summoned op attention, but in the future, please specify " .
				       "a reason, e.g. !ops reasongoeshere - so ops know what is going on. Thanks! :)");
		} elsif ($msgtgt eq lc $conn->{_nick}) {
			if ($tgt eq lc $conn->{_nick}) { # they privmsged the bot without providing a target
				$conn->privmsg($event->{nick}, "Sorry, it looks like you've tried to use the !ops command " .
					       "via PM but haven't specified a target. Try again with /msg $conn->{_nick} " .
					       "!ops #channelGoesHere ReasonGoesHere");
				return;
			} else {
				$conn->privmsg($event->{nick}, "Thanks, I'm notifying $tgt ops.");
			}
		}
		my $hilite=ASM::Util->commaAndify(ASM::Util->getAlert($tgt, 'opalert', 'hilights'));
		my $txtz = "[\x02$tgt\x02] - $event->{nick} wants op attention";
		if ((time-$::sc{$tgt}{users}{$nick}{jointime}) > 90) {
			$txtz .= " ($msg) $hilite !att-$tgt-opalert";
			$::ignored{$tgt} = $::RISKS{'opalert'};
			$conn->schedule(45, sub { delete($::ignored{$tgt}) if $::ignored{$tgt} == $::RISKS{'opalert'} });
		}
		elsif ($ops_ignored{$tgt}) {
			return;
		}
		else {
			$ops_ignored{$tgt} = 1;
			$conn->schedule(45, sub { delete $ops_ignored{$tgt} });
		}
		my $uuid = $::log->incident($tgt, $event->{nick}, undef, undef, undef, 'opalert');
		$txtz = $txtz . ' ' . ASM::Shortener->shorturl($::settings->{web}->{detectdir} . $uuid . '.txt');
		my @tgts = ASM::Util->getAlert($tgt, 'opalert', 'msgs');
		ASM::Util->sendLongMsg($conn, \@tgts, $txtz);
	} else {
		unless (defined($::ignored{$tgt}) && ($::ignored{$tgt} >= $::RISKS{'opalert'})
				or $ops_ignored{$tgt}) {
			my @tgts = ASM::Util->getAlert($tgt, 'opalert', 'msgs');
			foreach my $chan (@tgts) {
				$conn->privmsg($chan, $event->{nick} . " tried to use the ops trigger for $tgt but is restricted from doing so.");
			}
			$ops_ignored{$tgt} = 1;
			$conn->schedule(45, sub { delete $ops_ignored{$tgt} });
		}
	}
}

sub cmd_blacklist {
	my ($conn, $event) = @_;

	my $string = lc $+{string};
	use String::CRC32;
	my $id = sprintf("%08x", crc32($string));
	$::blacklist->{string}->{$id} = { "content" => $string, "type" => "string", "setby" => $event->nick, "settime" => strftime('%F', gmtime) };
	ASM::Config->writeBlacklist();
	$conn->privmsg($event->replyto, "$string blacklisted with id $id, please use ;blreason $id reasonGoesHere to set a reason");
}

sub cmd_blacklistpcre {
	my ($conn, $event) = @_;

	use String::CRC32;
	my $id = sprintf("%08x", crc32($+{string}));
	$::blacklist->{string}->{$id} = { "content" => $+{string}, "type" => "pcre", "setby" => $event->nick, "settime" => strftime('%F', gmtime) };
	ASM::Config->writeBlacklist();
	$conn->privmsg($event->replyto, "$+{string} blacklisted with id $id, please use ;blreason $id reasonGoesHere to set a reason");
}

sub cmd_unblacklist {
	my ($conn, $event) = @_;

	if (defined($::blacklist->{string}->{$+{id}})) {
		delete $::blacklist->{string}->{$+{id}};
		$conn->privmsg($event->replyto, "blacklist id $+{id} removed");
		ASM::Config->writeBlacklist();
	} else {
		$conn->privmsg($event->replyto, "invalid id");
	}
}

sub cmd_plugin {
	my ($conn, $event) = @_;

	my $chan = lc $+{chan};
	my $txtz = "\x03" . $::RCOLOR{$::RISKS{$+{risk}}} . "\u$+{risk}\x03 risk threat [\x02$chan\x02] - " .
	            "\x02($event->{nick} plugin)\x02 - $+{reason}; ping ";
	$txtz = $txtz . ASM::Util->commaAndify(ASM::Util->getAlert($chan, $+{risk}, 'hilights')) if (ASM::Util->getAlert($chan, $+{risk}, 'hilights'));
	$txtz = $txtz . ' !att-' . $chan . '-' . $+{risk};
	my @tgts = ASM::Util->getAlert($chan, $+{risk}, 'msgs');
	ASM::Util->sendLongMsg($conn, \@tgts, $txtz);
}

sub cmd_sync {
	my ($conn, $event) = @_;

	$conn->sl("WHO $+{chan} %tcuihnar,314");
	$conn->sl("MODE $+{chan}");
	$conn->sl("MODE $+{chan} bq");
}

sub cmd_ping {
	my ($conn, $event) = @_;

	$conn->privmsg($event->replyto, "pong");
}

sub cmd_ping2 {
	my ($conn, $event) = @_;

	$conn->privmsg($event->replyto, "pong $+{string}");
}

sub cmd_blreason {
	my ($conn, $event) = @_;

	if (defined($::blacklist->{string}->{$+{id}})) {
		$::blacklist->{string}->{$+{id}}->{reason} = $+{reason};
		$conn->privmsg($event->replyto, "Reason set");
		ASM::Config->writeBlacklist();
	} else {
		$conn->privmsg($event->replyto, "ID is invalid");
	}
}

sub cmd_bllookup {
	my ($conn, $event) = @_;
	my $id = $+{id};
	if (defined($::blacklist->{string}->{$id})) {
		my $content = $::blacklist->{string}->{$id}->{content};
		my $setby = $::blacklist->{string}->{$id}->{setby};
		my $settime = $::blacklist->{string}->{$id}->{settime};
		my $reason = $::blacklist->{string}->{$id}->{reason};
		my $type = $::blacklist->{string}->{$id}->{type};
		$reason = 'none ever provided' unless defined($reason);
		$conn->privmsg($event->nick, "'$content' $type blacklisted by $setby on $settime with reason $reason");
		if ($event->{to}->[0] =~ /^#/) {
			$conn->privmsg($event->replyto, "Info on blacklist ID $id sent via PM");
		}
	} else {
		$conn->privmsg($event->replyto, "ID is invalid");
	}
}

sub cmd_falsematch {
	my ($conn, $event) = @_;

	$conn->privmsg($event->replyto, 'To whitelist false matches for the impersonation check, have someone with the "a" flag run ";restrict nick LegitimateNickGoesHere +nonickbl_impersonate". Contact ilbelkyr if this issue reoccurs.');
}

sub cmd_version {
	my ($conn, $event) = @_;
	$conn->privmsg($event->replyto, $::version);
}

1;
# vim: ts=8:sts=8:sw=8:noexpandtab
