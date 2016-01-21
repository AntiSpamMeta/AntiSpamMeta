#!/usr/bin/perl

package ASM::Shortener;

use LWP::UserAgent;
use URI::Escape;

sub shorturl
{
  my $module = shift;
  my ($url) = @_;
  my $apikey = $::settings->{web}->{shortener}->{apikey};
  my $domain = $::settings->{web}->{shortener}->{domain};
  my $ua = LWP::UserAgent->new;
  $ua->agent("AntiSpamMeta/13.37 ");
  my $res = $ua->get('https://shortener.godaddy.com/v1/?apikey=' .$apikey . '&domain=' . $domain .'&url=' . uri_escape($url) );
  if ($res->is_success) {
      return $res->content;
  }
  else {
      warn $res->status_line;
      return $url;
  }
}

1;
