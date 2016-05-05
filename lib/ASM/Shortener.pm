#!/usr/bin/perl

package ASM::Shortener;

use LWP::UserAgent;
use URI::Escape;

sub shorturl
{
  my $module = shift;
  my ($url) = @_;
  if ((!defined($::settings->{web}->{shortener})) ||
      (!defined($::settings->{web}->{shortener}->{domain})) ||
      (!defined($::settings->{web}->{shortener}->{apikey})) ||
      ($::settings->{web}->{shortener}->{domain} eq '') ||
      ($::settings->{web}->{shortener}->{apikey} eq '')) {
    return $url;
  }
  my $apikey = $::settings->{web}->{shortener}->{apikey};
  my $domain = $::settings->{web}->{shortener}->{domain};
  my $secure = $::settings->{web}->{shortener}->{secure};
  my $ua = LWP::UserAgent->new;
  $ua->agent("AntiSpamMeta/13.37 ");
  my $res = $ua->get('http' . ($secure ? 's' : '') . '://' . $domain . '/yourls-api.php?' .
                     'signature=' . $apikey . '&action=shorturl&format=simple&url=' . uri_escape($url) );
  if ($res->is_success) {
      return $res->content;
  }
  else {
      warn $res->status_line;
      return $url;
  }
}

1;
