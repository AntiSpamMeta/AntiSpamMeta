package ASM::Commander;
no autovivification;

use warnings;
use strict;
use IO::All;
use POSIX qw(strftime);
use Data::Dumper;
use URI::Escape;
use ASM::Shortener;

no if $] >= 5.017011, warnings => 'experimental::smartmatch';

my $cmdtbl = {
	'^;wallop' => {
		'flag' => 'd',
		'cmd' => \&cmd_wallop },
	'^;;addwebuser (?<pass>.{6,})' => {
		'flag' => 's',
		'cmd' => \&cmd_addwebuser },
	'^;delwebuser (?<user>\S+)' => {
		'flag' => 'a',
		'cmd' => \&cmd_delwebuser },
	'^;teredo (?<ip>\S+)' => {
		'cmd' => \&cmd_teredo },
	'^;status$' => {
		'cmd' => \&cmd_status },
	'^;mship (?<nick>\S+)' => {
		'flag' => 's',
		'cmd' => \&cmd_mship },
	'^;source$' => {
		'cmd' => \&cmd_source },
	'^;sql (?<db>main|log) (?<string>.*)' => {
		'flag' => 'd',
		'cmd' => \&cmd_sql },
	'^;monitor (?<chan>\S+) *$' => {
		'flag' => 's',
		'cmd' => \&cmd_monitor },
	'^;monitor (?<chan>\S+) ?(?<switch>yes|no)$' => {
		'flag' => 'a',
		'cmd' => \&cmd_monitor2 },
	'^;suppress (?<chan>\S+) *$' => {
		'flag' => 's',
		'cmd' => \&cmd_suppress },
	'^;unsuppress (?<chan>\S+) *$' => {
		'flag' => 's',
		'cmd' => \&cmd_unsuppress },
	'^;silence (?<chan>\S+) *$' => {
		'flag' => 's',
		'cmd' => \&cmd_silence },
	'^;silence (?<chan>\S+) (?<switch>yes|no) *$' => {
		'flag' => 'a',
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
		'cmd' => \&cmd_investigate },
	'^;investigate2 (?<nick>\S+) ?(?<skip>\d*) *$' => {
		'flag' => 's',
		'cmd' => \&cmd_investigate2 },
	'^;userx? add (?<account>\S+) (?<flags>\S+)$' => {
		'flag' => 'a',
		'cmd' => \&cmd_user_add },
	'^;userx? flags (?<account>\S+) ?$' => {
		'cmd' => \&cmd_user_flags },
	'^;userx? flags (?<account>\S+) (?<flags>\S+)$' => {
		'flag' => 'a',
		'cmd' => \&cmd_user_flags2 },
	'^;userx? del (?<account>\S+)$' => {
		'flag' => 'a',
		'cmd' => \&cmd_user_del },
	'^;target (?<chan>\S+) (?<nickchan>\S+) ?(?<level>[a-z]*)$' => {
		'flag' => 'a',
		'cmd' => \&cmd_target },
	'^;detarget (?<chan>\S+) (?<nickchan>\S+)' => {
		'flag' => 'a',
		'cmd' => \&cmd_detarget },
	'^;showhilights (?<nick>\S+) *$' => {
		'flag' => 'h',
		'cmd' => \&cmd_showhilights },
	'^;hilight (?<chan>\S+) (?<nicks>\S+) ?(?<level>[a-z]*)$' => {
		'flag' => 'h',
		'cmd' => \&cmd_hilight },
	'^;dehilight (?<chan>\S+) (?<nicks>\S+)' => {
		'flag' => 'h',
		'cmd' => \&cmd_dehilight },
	'^;join (?<chan>\S+)' => {
		'flag' => 'a',
		'cmd' => \&cmd_join },
	'^;part (?<chan>\S+)' => {
		'flag' => 'a',
		'cmd' => \&cmd_part },
	'^;sl (?<string>.+)' => {
		'flag' => 'd',
		'cmd' => \&cmd_sl },
	'^;quit ?(?<reason>.*)' => {
		'flag' => 'a',
		'cmd' => \&cmd_quit },
	'^;ev (?<string>.*)' => {
		'flag' => 'd',
		'cmd' => \&cmd_ev },
	'^;rehash$' => {
		'flag' => 'a',
		'cmd' => \&cmd_rehash },
	'^;restrict (?<type>nick|account|host) (?<who>\S+) (?<mode>\+|-)(?<restriction>[a-z0-9_-]+)$' => {
		'flag' => 'a',
		'cmd' => \&cmd_restrict },
	'^\s*\!ops ?(?<chan>#\S+)? ?(?<reason>.*)' => {
		'nohush' => 'nohush',
		'cmd' => \&cmd_ops },
	'^;blacklist (?<string>.+)' => {
		'flag' => 's',
		'cmd' => \&cmd_blacklist },
	'^;blacklistpcre (?<string>.+)' => {
		'flag' => 'a',
		'cmd' => \&cmd_blacklistpcre },
	'^;unblacklist (?<id>[0-9a-f]+)$' => {
		'flag' => 's',
		'cmd' => \&cmd_unblacklist },
	'^;plugin (?<chan>\S+) (?<risk>\S+) (?<reason>.*)' => {
		'flag' => 'p',
		'cmd' => \&cmd_plugin },
	'^;sync (?<chan>\S+)' => {
		'flag' => 'a',
		'cmd' => \&cmd_sync },
	'^;ping\s*$' => {
		'cmd' => \&cmd_ping },
	'^;ping (?<string>\S.*)$' => {
		'flag' => 's',
		'cmd' => \&cmd_ping2 },
	'^;blreason (?<id>[0-9a-f]+) (?<reason>.*)' => {
		'flag' => 's',
		'cmd' => \&cmd_blreason },
	'^;bllookup (?<id>[0-9a-f]+)$' => {
		'flag' => 's',
		'cmd' => \&cmd_bllookup },
	'^;falsematch\b' => {
		'flag' => 's',
		'cmd' => \&cmd_falsematch },
	'^;nicks (?<nick>\S+)\s*$' => {
		'flag' => 's',
		'cmd' => \&cmd_nicks },
	'^;explain (?<nick1>\S+)\s+(?<nick2>\S+)\s*$' => {
		'flag' => 's',
		'cmd' => \&cmd_explain },
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
		if (defined($self->{cmdtbl}->{$command}->{flag})) { #If the command is restricted,
			if (!defined($acct)) {
				$fail = 1;
			}
			elsif (!defined($::users->{person}->{$acct})) { #make sure the requester has an account
				$fail = 1;
			}
			elsif (!defined($::users->{person}->{$acct}->{flags})) { #make sure the requester has flags defined
				$fail = 1;
			}
			elsif (!(grep {$_ eq $self->{cmdtbl}->{$command}->{flag}} split('', $::users->{person}->{$acct}->{flags}))) { #make sure the requester has the needed flags
				$fail = 1;
			}
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
			if ($fail == 1) {
				$conn->privmsg($nick, "You don't have permission to use that command, or you're not signed into nickserv.");
			} else {
				&{$self->{cmdtbl}->{$command}->{cmd}}($conn, $event);
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
	use Apache::Htpasswd; use Apache::Htgroup;
	my $o_Htpasswd = new Apache::Htpasswd({passwdFile => $::settings->{web}->{userfile}, UseMD5 => 1});
	my $o_Htgroup = new Apache::Htgroup($::settings->{web}->{groupfile});
	my $user = lc $::sn{lc $event->{nick}}->{account};
	$o_Htpasswd->htDelete($user);
	$o_Htpasswd->htpasswd($user, $pass);
	$o_Htpasswd->writeInfo($user, strftime("%F %T", gmtime));
	$o_Htgroup->adduser($user, 'actionlogs');
	$o_Htgroup->save();
	$conn->privmsg($event->replyto, "Added $user to the list of authorized web users.")
}

sub cmd_delwebuser {
	my ($conn, $event) = @_;

	my $user = lc $+{user};
	use Apache::Htpasswd;
	use Apache::Htgroup;
	my $o_Htpasswd = new Apache::Htpasswd({passwdFile => $::settings->{web}->{userfile}, UseMD5 => 1});
	my $o_Htgroup = new Apache::Htgroup($::settings->{web}->{groupfile});
	$o_Htpasswd->htDelete($user);
	$o_Htgroup->deleteuser($user, 'actionlogs');
	$o_Htgroup->save();
	$conn->privmsg($event->replyto, "Removed $user from the list of authorized web users.")
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

sub cmd_sql {
	my ($conn, $event) = @_;

	if (!defined $::db) {
		$conn->privmsg($event->replyto, "I am set to run without a database, fool.");
		return;
	}
	
	my $dbh = $::db->{DBH};
	if ($+{db} eq 'log') {
		$dbh = $::db->{DBH_LOG};
	}
	$::db->raw($conn, $event->{to}->[0], $dbh, $+{string});
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

sub cmd_query {
	my ($conn, $event) = @_;

	return unless defined $::db;
	my $channel = defined($2) ? $1 : '%';
	my @nuh = split(/(\!|\@)/, defined($2) ? $2 : $1);
	my $result = $::db->query($channel, $nuh[0], $nuh[2], $nuh[4]);
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
	my $dbh = $::db->{DBH};
	
	my $mnicks = $dbh->do("SELECT * from $::db->{ACTIONTABLE} WHERE nick like " . $dbh->quote($nick) . ';');
	my $musers = ($user ~~ $::mysql->{ignoredidents}) ? "didn't check" : $dbh->do("SELECT * from $::db->{ACTIONTABLE} WHERE user like " . $dbh->quote($person->{user}) . ';');
	my $mhosts = $dbh->do("SELECT * from $::db->{ACTIONTABLE} WHERE host like " . $dbh->quote($person->{host}) . ';');
	my $maccts = $dbh->do("SELECT * from $::db->{ACTIONTABLE} WHERE account like " . $dbh->quote($person->{account}) . ';');
	my $mgecos = ($gecos ~~ $::mysql->{ignoredgecos}) ? "didn't check" : $dbh->do("SELECT * from $::db->{ACTIONTABLE} WHERE gecos like " . $dbh->quote($person->{gecos}) . ';');
	
	my $ip = ASM::Util->getNickIP($nick);
	my $matchedip = 0;
	$matchedip = $dbh->do("SELECT * from $::db->{ACTIONTABLE} WHERE ip = " . $dbh->quote($ip) . ';') if defined($ip);
	$mnicks =~ s/0E0/0/;
	$musers =~ s/0E0/0/;
	$mhosts =~ s/0E0/0/;
	$maccts =~ s/0E0/0/;
	$mgecos =~ s/0E0/0/;
	$matchedip =~ s/0E0/0/;
	my $dq = '';
	if (defined($ip)) {
		$dq = join '.', unpack 'C4', pack 'N', $ip;
	}
	$conn->privmsg($event->replyto, "I found $mnicks matches by nick ($nick), $musers by user ($person->{user}), $mhosts by hostname ($person->{host}), " .
		       "$maccts by NickServ account ($person->{account}), $mgecos by gecos field ($person->{gecos}), and $matchedip by real IP ($dq). " .
		       ASM::Shortener->shorturl('https://antispammeta.net/cgi-bin/secret/investigate.pl?nick=' . uri_escape($nick) .
		       (($user ~~ $::mysql->{ignoredidents}) ? '' : '&user=' . uri_escape($person->{user})) .
		       '&host=' . uri_escape($person->{host}) . '&account=' . uri_escape($person->{account}) .
		       (($gecos ~~ $::mysql->{ignoredgecos}) ? '' : '&gecos=' . uri_escape($person->{gecos})) . '&realip=' . $dq));
}

sub cmd_investigate2 {
	my ($conn, $event) = @_;

	return unless defined $::db;
	my $nick = lc $+{nick};
	my $skip = 0;
	$skip = $+{skip} if (defined($+{skip}) and ($+{skip} ne ""));
	cmd_investigate($conn, $event);
	unless (defined($::sn{$nick})) {
		return;
	}
	my $person = $::sn{$nick};
	my $dbh = $::db->{DBH};

	my $query = "SELECT * from $::db->{ACTIONTABLE} WHERE nick like " . $dbh->quote($nick) .
	             ((lc $person->{user} ~~ $::mysql->{ignoredidents}) ? '' : ' or user like ' . $dbh->quote($person->{user})) .
	             ' or host like ' . $dbh->quote($person->{host}) .
		     ' or account like ' . $dbh->quote($person->{account}) .
	             ((lc $person->{gecos} ~~ $::mysql->{ignoredgecos}) ? '' : ' or gecos like ' . $dbh->quote($person->{gecos}));
	my $ip = ASM::Util->getNickIP($nick);
	if (defined($ip)) {
		$query = $query . ' or ip = ' . $dbh->quote($ip);
	}
	$query = $query . " order by time desc limit $skip,10;";
	ASM::Util->dprint($query, 'mysql');
	my $query_handle = $dbh->prepare($query);
	$query_handle->execute();
	my @data = @{$query_handle->fetchall_arrayref()};
	if (@data) {
		$conn->privmsg($event->replyto, 'Sending you the results...');
	} else {
		$conn->privmsg($event->replyto, 'No results to send!');
	}
#		 reverse @data;
#$data will be an array of arrays,
	my ($xindex, $xtime, $xaction, $xreason, $xchannel, $xnick, $xuser, $xhost, $xip, $xgecos, $xaccount, $xbynick, $xbyuser, $xbyhost, $xbygecos, $xbyaccount ) = ( 0 .. 15 );
	foreach my $line (@data) {
		my $reason = ''; my $channel = '';
		$reason = ' (' . $line->[$xreason] . ')' if defined($line->[$xreason]);
		$channel = ' on ' . $line->[$xchannel] if defined($line->[$xchannel]);
		$conn->privmsg($event->nick, '#' . $line->[$xindex] . ': ' . $line->[$xtime] . ' ' .
			       $line->[$xnick] . '!' . $line->[$xuser] . '@' . $line->[$xhost] . ' (' . $line->[$xgecos] . ') ' . 
			       $line->[$xaction] . $reason . $channel . ' by ' . $line->[$xbynick]); # . "\n";
	}
	if (@data) {
		$conn->privmsg($event->nick, "Only 10 results are shown at a time. For more, do ;investigate2 $nick " . ($skip+10) . '.');
	}
}

sub cmd_user_add {
	my ($conn, $event) = @_;

	my $nick = lc $+{account};
	my $account;
	my $flags = $+{flags};
	my %hasflagshash = ();
	foreach my $item (split(//, $::users->{person}->{lc $::sn{lc $event->{nick}}->{account}}->{flags})) {
		$hasflagshash{$item} = 1;
	}
	foreach my $flag (split(//, $flags)) {
		if (!defined($hasflagshash{$flag})) {
			$conn->privmsg($event->replyto, "You can't give a flag you don't already have.");
			return;
		}
	}
	if ($flags =~ /d/) {
		$conn->privmsg($event->replyto, "The d flag may not be assigned over IRC. Edit the configuration manually.");
		return;
	}
	if ( (defined($::sn{$nick}->{account})) && ( ($account = lc $::sn{$nick}->{account}) ne $nick ) ) {
		$conn->privmsg($event->replyto, "I'm assuming you mean " . $nick . "'s nickserv account, " . $account . '.');
		$nick = $account;
	}
	if (defined($::users->{person}->{$nick})) {
		$conn->privmsg($event->replyto, "The user $nick already exists.  Use ;user flags $nick $flags to set their flags");
		return;
	}
	$::users->{person}->{$nick} = { 'flags' => $flags };
	ASM::Config->writeUsers();
	$conn->privmsg($event->replyto, "Flags for NickServ account $nick set to $flags");
}

sub cmd_user_flags {
	my ($conn, $event) = @_;

	my $nick = lc $+{account};
	my $account;
	if ( defined($::sn{$nick}) && (defined($::sn{$nick}->{account})) && ( ($account = lc $::sn{$nick}->{account}) ne $nick ) ) {
		$conn->privmsg($event->replyto, "I'm assuming you mean " . $nick . "'s nickserv account, " . $account . '.');
		$nick = $account;
	}
	my $sayNick = substr($nick, 0, 1) . "\x02\x02" . substr($nick, 1);
	if (defined($::users->{person}->{$nick}->{flags})) {
		$conn->privmsg($event->replyto, "Flags for $sayNick: $::users->{person}->{$nick}->{flags}");
	} else {
		$conn->privmsg($event->replyto, "$sayNick has no flags");
	}
}

sub cmd_user_flags2 {
	my ($conn, $event) = @_;

	my $nick = lc $+{account};
	my $flags = $+{flags};
	my $account;
	my %hasflagshash = ();
	foreach my $item (split(//, $::users->{person}->{lc $::sn{lc $event->{nick}}->{account}}->{flags})) {
		$hasflagshash{$item} = 1;
	}
	foreach my $flag (split(//, $flags)) {
		if (!defined($hasflagshash{$flag})) {
			$conn->privmsg($event->replyto, "You can't give a flag you don't already have.");
			return;
		}
	}
	if ($flags =~ /d/) {
		$conn->privmsg($event->replyto, "The d flag may not be assigned over IRC. Edit the configuration manually.");
		return;
	}
	if ( (defined($::sn{$nick}->{account})) && ( ($account = lc $::sn{$nick}->{account}) ne $nick ) ) {
		$conn->privmsg($event->replyto, "I'm assuming you mean " . $nick . "'s nickserv account, " . $account . '.');
		$nick = $account;
	}
	if (defined($::users->{person}->{$nick}) &&
	    defined($::users->{person}->{$nick}->{flags}) &&
	    ($::users->{person}->{$nick}->{flags} =~ /d/)) {
		return $conn->privmsg($event->replyto, "Users with the 'd' flag are untouchable. Edit the config file manually.");
	}
	if ($flags !~ /s/) {
		use Apache::Htpasswd; use Apache::Htgroup;
		my $o_Htpasswd = new Apache::Htpasswd({passwdFile => $::settings->{web}->{userfile}, UseMD5 => 1});
		my $o_Htgroup = new Apache::Htgroup($::settings->{web}->{groupfile});
		$o_Htpasswd->htDelete($nick);
		$o_Htgroup->deleteuser($nick, 'actionlogs');
		$o_Htgroup->save();
	}
	$::users->{person}->{$nick}->{flags} = $flags;
	ASM::Config->writeUsers();
	$conn->privmsg($event->replyto, "Flags for $nick set to $flags");
}

sub cmd_user_del {
	my ($conn, $event) = @_;

	my $nick = lc $+{account};
	if (defined($::users->{person}->{$nick}) &&
	    defined($::users->{person}->{$nick}->{flags}) &&
	    ($::users->{person}->{$nick}->{flags} =~ /d/)) {
		return $conn->privmsg($event->replyto, "Users with the 'd' flag are untouchable. Edit the config file manually.");
	}
	delete($::users->{person}->{$nick});
	ASM::Config->writeUsers();
	use Apache::Htpasswd; use Apache::Htgroup;
	my $o_Htpasswd = new Apache::Htpasswd({passwdFile => $::settings->{web}->{userfile}, UseMD5 => 1});
	my $o_Htgroup = new Apache::Htgroup($::settings->{web}->{groupfile});
	$o_Htpasswd->htDelete($nick);
	$o_Htgroup->deleteuser($nick, 'actionlogs');
	$o_Htgroup->save();
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
		}
		my $uuid = $::log->incident($tgt, "$tgt: $event->{nick} requested op attention\n");
		$txtz = $txtz . ' ' . ASM::Shortener->shorturl($::settings->{web}->{detectdir} . $uuid . '.txt');
		my @tgts = ASM::Util->getAlert($tgt, 'opalert', 'msgs');
		ASM::Util->sendLongMsg($conn, \@tgts, $txtz);
	} else {
		unless (defined($::ignored{$tgt}) && ($::ignored{$tgt} >= $::RISKS{'opalert'})) {
			my @tgts = ASM::Util->getAlert($tgt, 'opalert', 'msgs');
			foreach my $chan (@tgts) {
				$conn->privmsg($chan, $event->{nick} . " tried to use the ops trigger for $tgt but is restricted from doing so.");
			}
		}
	}
	$::ignored{$tgt} = $::RISKS{'opalert'};
	$conn->schedule(45, sub { delete($::ignored{$tgt}) if $::ignored{$tgt} == $::RISKS{'opalert'} });
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

sub cmd_nicks {
	my ($conn, $event) = @_;
	my $nick = $+{nick};
	if (!defined $::db) {
		$conn->privmsg($event->replyto, "I am set to run without a database, fool.");
		return;
	}
	my $DB = $::db->{DBH_LOG};
	my $doit = sprintf ("select distinct nick from joins as v1
			inner join (
				select distinct host from joins where nick=%s
				and host not like %s
				and host <> %s
			) as v2
			on v1.host = v2.host
		where v1.nick not like %s
		",
		$DB->quote($nick),
		$DB->quote('gateway/%/session'),
		$DB->quote('127.0.0.1'),
		$DB->quote('guest%')
	);
	my $result = $DB->selectcol_arrayref( $doit );
	$conn->privmsg($event->replyto, "Results for $nick: " . ASM::Util->commaAndify(sort @$result));
}

sub cmd_explain { # all hosts associated with two given nicks
	my ($conn, $event) = @_;
	my $nick1 = $+{nick1};
	my $nick2 = $+{nick2};
	my $header = sprintf ("Hosts for %s and %s: ", $nick1, $nick2);
	if (!defined $::db) {
		$conn->privmsg($event->replyto, "I am set to run without a database, fool.");
		return;
	}
	my $DB = $::db->{DBH_LOG};
	my $result = $DB->selectcol_arrayref (
		sprintf ("
			select distinct t1.host from joins as t1
				inner join (
					select host from joins
					where
						nick=%s and
						host not like %s and
						host <> %s) as t2
				on t1.host=t2.host and
				t1.nick=%s",
			$DB->quote($nick1),
			$DB->quote('%/session'),
			$DB->quote('127.0.0.1'),
			$DB->quote($nick2)
		)
	);
	$conn->privmsg($event->replyto, $header . ASM::Util->commaAndify(sort @$result));
}

# vim: ts=8:sts=8:sw=8:noexpandtab
