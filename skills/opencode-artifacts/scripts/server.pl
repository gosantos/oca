#!/usr/bin/perl
# Static server: 127.0.0.1 only, serves only under /<ARTIFACTS_SECRET>/, no listing, no dotfiles, no traversal.
# Core modules only (ships with macOS, most Linux, Git Bash).
use strict; use warnings; use IO::Socket::INET; use Cwd qw(realpath);
my ($ROOT, $PORT) = (realpath($ARGV[0]), $ARGV[1]);
my $SECRET = $ENV{ARTIFACTS_SECRET} // ''; my $PREFIX = $SECRET ne '' ? "/$SECRET" : '';
my %T = (html => 'text/html; charset=utf-8', css => 'text/css', js => 'text/javascript', json => 'application/json',
  svg => 'image/svg+xml', png => 'image/png', jpg => 'image/jpeg', webp => 'image/webp', csv => 'text/csv');
my $H = "X-Content-Type-Options: nosniff\r\nReferrer-Policy: no-referrer\r\nCache-Control: no-store\r\nX-Robots-Tag: noindex\r\nConnection: close\r\n";
my $srv = IO::Socket::INET->new(LocalAddr => '127.0.0.1', LocalPort => $PORT, Listen => 64, ReuseAddr => 1, Proto => 'tcp') or die "listen: $!";
$SIG{CHLD} = 'IGNORE';
while (my $c = $srv->accept) {
  if (fork) { close $c; next; }
  close $srv; binmode $c;
  local $SIG{ALRM} = sub { exit }; alarm 10;
  my $line = <$c> // exit; while (my $l = <$c>) { last if $l =~ /^\r?\n$/ }
  my ($m, $raw) = $line =~ m{^(\S+) (\S+)} or exit;
  my $send = sub { my ($code, $extra, $body) = @_; print $c "HTTP/1.1 $code\r\n$H" . ($extra // '') . "Content-Length: " . length($body // '') . "\r\n\r\n" . ($body // ''); exit };
  $send->('405 Method Not Allowed') unless $m eq 'GET' || $m eq 'HEAD';
  (my $u = $raw) =~ s/[?#].*//; $u =~ s/%([0-9A-Fa-f]{2})/chr hex $1/ge;
  $send->('301 Moved Permanently', "Location: $PREFIX/\r\n") if $u eq $PREFIX;
  $send->('404 Not Found') unless index($u, "$PREFIX/") == 0;
  $u = substr($u, length $PREFIX);
  $send->('404 Not Found') if grep { /^\./ } split m{/}, $u;
  my $f = "$ROOT$u"; $f .= '/index.html' if -d $f; $f = realpath($f);
  $send->('404 Not Found') unless defined $f && -f $f && index($f, "$ROOT/") == 0;
  my ($ext) = $f =~ /\.(\w+)$/; my $type = $T{lc($ext // '')} // 'application/octet-stream';
  open my $fh, '<:raw', $f or $send->('404 Not Found');
  print $c "HTTP/1.1 200 OK\r\n${H}Content-Type: $type\r\nContent-Length: " . (-s $f) . "\r\n\r\n";
  if ($m eq 'GET') { local $/ = \65536; print $c $_ while <$fh>; }
  exit;
}
