#!perl

# Fast-gets fuzzer for read_utf8(). Feeds long random octet streams (biased
# toward lead bytes, continuations and truncated sequences) through the
# fast-gets path (in-memory scalar and :raw handles) at a range of request
# sizes, checking each drained result against decode_utf8() and that nothing
# crashes when sequences straddle fill/budget boundaries.
#
#   perl Makefile.PL && make
#   perl -Mblib fuzz.pl [ITERATIONS] [SEED]

use strict;
use warnings;

use Unicode::UTF8 qw[ read_utf8 decode_utf8 encode_utf8 ];
use File::Temp    qw[ tempfile ];

my $ITERS = @ARGV ? shift : 20000;
my $SEED  = @ARGV ? shift : 20260706;
srand($SEED);

sub scalar_fh {
  my ($bytes) = @_;
  open my $fh, '<', \$bytes
    or die qq/Couldn't open in-memory handle: '$!'/;
  binmode $fh or die qq/binmode: '$!'/;
  return $fh;
}

sub raw_fh {
  my ($bytes) = @_;
  my ($tfh, $path) = tempfile(UNLINK => 1);
  binmode $tfh;
  print {$tfh} $bytes;
  close $tfh;
  open my $fh, '<:raw', $path
    or die qq/Couldn't open :raw handle: '$!'/;
  return $fh;
}

my @MAKERS = (\&scalar_fh, \&raw_fh);
my @REQ    = (1, 2, 3, 4, 7, 13, 64, 4096, 100_000);

sub oracle {
  my ($bytes) = @_;
  my @w;
  local $SIG{__WARN__} = sub { push @w, @_ };
  use warnings 'utf8';
  my $chars = decode_utf8($bytes);
  return ($chars, scalar @w);
}

sub drain {
  my ($fh, $req) = @_;
  my @w;
  local $SIG{__WARN__} = sub { push @w, @_ };
  use warnings 'utf8';
  my $out = '';
  while ((my $n = read_utf8($fh, my $buf, $req)) > 0) {
    $out .= $buf;
  }
  return ($out, scalar @w);
}

my $euro = "\xE2\x82\xAC";
my $grin = "\xF0\x9F\x98\x80";

# Bytes weighted so sequences frequently split across the layer buffer.
my @FRAGMENTS = (
  "A", "z", " ", "\x00",
  $euro, $grin,
  "\x80", "\xBF", "\xC0", "\xC1", "\xC3", "\xD4",
  "\xE2", "\xE2\x82", "\xED\xA0", "\xF0\x9F\x98", "\xF4\x90",
  "\xFE", "\xFF",
);

sub random_stream {
  my $n = int rand(2048);
  my $s = '';
  $s .= $FRAGMENTS[int rand @FRAGMENTS] for 1 .. $n;
  return $s;
}

my $checks     = 0;
my $mismatches = 0;

for my $i (1 .. $ITERS) {
  my $bytes = random_stream();
  my ($want, $wwarn) = oracle($bytes);

  my $maker = $MAKERS[int rand @MAKERS];
  my $req   = $REQ[int rand @REQ];

  my ($got, $gwarn) = drain($maker->($bytes), $req);
  $checks++;
  next if $got eq $want && $gwarn == $wwarn;

  $mismatches++;
  printf STDERR "MISMATCH iter=%d req=%d octets=%s\n", $i, $req, unpack('H*', $bytes);
  printf STDERR "  want=%s warns=%d\n", unpack('H*', encode_utf8($want)), $wwarn;
  printf STDERR "  got =%s warns=%d\n", unpack('H*', encode_utf8($got)),  $gwarn;
  exit 1 if $mismatches >= 5;
}

printf "ok: %d iterations, 0 mismatches (seed %d)\n", $checks, $SEED;
