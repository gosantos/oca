#!/usr/bin/perl
# Static server: 127.0.0.1 only, serves only under /<ARTIFACTS_SECRET>/, no listing, no dotfiles, no traversal.
# The site root itself is never served (404), so a stray index.html can't become a public listing.
# Core modules only (ships with macOS, most Linux, Git Bash).
# Performance: one fork per connection (not per request), HTTP/1.1 keep-alive, Content-Length, TCP_NODELAY, gzip.
use strict; use warnings; use IO::Socket::INET; use Cwd qw(realpath); use Socket qw(IPPROTO_TCP TCP_NODELAY);
my ($ROOT, $PORT) = (realpath($ARGV[0]), $ARGV[1]);
my $SECRET = $ENV{ARTIFACTS_SECRET} // ''; $SECRET =~ s/^\s+|\s+$//g;
my $PUBLIC = ($ENV{ARTIFACTS_PUBLIC} // '') eq '1';
# Fail closed: a missing or malformed secret must never widen the served paths.
die "ERROR: ARTIFACTS_SECRET must be 64 lowercase hex chars (or set ARTIFACTS_PUBLIC=1)\n"
  unless $PUBLIC || $SECRET =~ /\A[0-9a-f]{64}\z/;
my $PREFIX = $PUBLIC ? '' : "/$SECRET";
my %T = (html => 'text/html; charset=utf-8', css => 'text/css', js => 'text/javascript', json => 'application/json',
  svg => 'image/svg+xml', png => 'image/png', jpg => 'image/jpeg', webp => 'image/webp', csv => 'text/csv');
my %GZ = map { $_ => 1 } qw(html css js json svg csv);
my $GZIP = eval { require IO::Compress::Gzip; 1 } ? 1 : 0;
my $H = "X-Content-Type-Options: nosniff\r\nReferrer-Policy: no-referrer\r\nCache-Control: no-store\r\nX-Robots-Tag: noindex\r\n"
  . "X-Frame-Options: DENY\r\nContent-Security-Policy: frame-ancestors 'none'\r\n";
my $srv = IO::Socket::INET->new(LocalAddr => '127.0.0.1', LocalPort => $PORT, Listen => 128, ReuseAddr => 1, Proto => 'tcp') or die "listen: $!";
$SIG{CHLD} = 'IGNORE';
while (my $c = $srv->accept) {
  if (fork) { close $c; next; }
  close $srv;
  binmode $c;
  eval { $c->setsockopt(IPPROTO_TCP, TCP_NODELAY, pack('l', 1)) };
  local $SIG{ALRM} = sub { exit }; alarm 65;
  my $reply = sub {  # -> full response string; every status gets an exact Content-Length
    my ($code, $extra, $body, $ctype) = @_;
    $body //= '';
    return "HTTP/1.1 $code\r\n$H" . ($extra // '') . (defined $ctype ? "Content-Type: $ctype\r\n" : '')
      . "Content-Length: " . length($body) . "\r\n\r\n" . $body;
  };
  while (1) {
    my $line = <$c>;
    last unless defined $line;
    my $keep = 1; my $gzip_ok = 0;
    while (my $h = <$c>) {
      last if $h =~ /^\r?\n$/;
      $keep = 0 if $h =~ /^Connection:\s*close/i;
      $gzip_ok = 1 if $h =~ /^Accept-Encoding:.*\bgzip\b/i;
    }
    my ($m, $raw) = $line =~ m{^(\S+) (\S+)} or last;
    $keep = 0 unless $line =~ m{HTTP/1\.[1-9]};
    if ($m ne 'GET' && $m ne 'HEAD') { print $c $reply->('405 Method Not Allowed'); last unless $keep; next }
    (my $u = $raw) =~ s/[?#].*//; $u =~ s/%([0-9A-Fa-f]{2})/chr hex $1/ge;
    if (!$PUBLIC && $u eq $PREFIX) { print $c $reply->('301 Moved Permanently', "Location: $PREFIX/\r\n"); last unless $keep; next }
    if (index($u, "$PREFIX/") != 0) { print $c $reply->('404 Not Found'); last unless $keep; next }
    $u = substr($u, length $PREFIX);
    if ($u eq '' || $u eq '/' || grep { /^\./ } split m{/}, $u) { print $c $reply->('404 Not Found'); last unless $keep; next }
    my $f = "$ROOT$u"; $f .= '/index.html' if -d $f; $f = realpath($f);
    if (!defined $f || !-f $f || index($f, "$ROOT/") != 0) { print $c $reply->('404 Not Found'); last unless $keep; next }
    my ($ext) = $f =~ /\.(\w+)$/; $ext = lc($ext // '');
    my $type = $T{$ext} // 'application/octet-stream';
    my $size = -s $f;
    my $send = sub { my ($encoding, $len) = @_; print $c "HTTP/1.1 200 OK\r\n$H" . ($encoding ? "Content-Encoding: gzip\r\nVary: Accept-Encoding\r\n" : '') . "Content-Type: $type\r\nContent-Length: $len\r\n\r\n" };
    if ($m eq 'HEAD') { $send->(0, $size) }
    elsif ($GZIP && $gzip_ok && $GZ{$ext} && $size <= 1048576) {
      open my $fh, '<:raw', $f or do { print $c $reply->('404 Not Found'); last unless $keep; next };
      my $data = do { local $/; <$fh> };
      close $fh;
      # gzip() treats a plain scalar as a file name, so the data must go in by reference.
      my $out = '';
      if (IO::Compress::Gzip::gzip(\$data => \$out)) { $send->(1, length $out); print $c $out }
      else { $send->(0, length $data); print $c $data }
    } else {
      open my $fh, '<:raw', $f or do { print $c $reply->('404 Not Found'); last unless $keep; next };
      $send->(0, $size);
      if ($m eq 'GET') { local $/ = \65536; print $c $_ while <$fh> }
      close $fh;
    }
    alarm 65;
    last unless $keep;
  }
  close $c;
  exit;
}
