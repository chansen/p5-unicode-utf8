#!perl

# Differential oracle for read_utf8(): drains a handle to EOF over every
# PerlIO layer and read schedule and checks that the decoded characters and
# the utf8-warning count match decode_utf8() over the same octets.
#
#   * scalar / :raw / :perlio -> the fast-gets path
#   * :unix                   -> the non-buffered PerlIO_read() path
#
# Run from the repo root against the built extension:
#
#   perl Makefile.PL && make
#   perl -Mblib oracle.pl [ITERATIONS] [SEED]
#
# Exits non-zero and prints the offending octets on the first mismatch.

use strict;
use warnings;

use Unicode::UTF8 qw[ read_utf8 decode_utf8 encode_utf8 ];
use File::Temp    qw[ tempfile ];

my $ITERS = @ARGV ? shift : 3000;
my $SEED  = @ARGV ? shift : 20260706;
srand($SEED);

sub scalar_fh {
  my ($bytes) = @_;
  open my $fh, '<', \$bytes
    or die qq/Couldn't open in-memory handle: '$!'/;
  binmode $fh or die qq/binmode: '$!'/;
  return $fh;
}

sub file_fh {
  my ($layer, $bytes) = @_;
  my ($tfh, $path) = tempfile(UNLINK => 1);
  binmode $tfh;
  print {$tfh} $bytes;
  close $tfh;
  open my $fh, "<$layer", $path
    or die qq/Couldn't open $layer handle: '$!'/;
  return $fh;
}

my %MAKERS = (
  'scalar'  => sub { scalar_fh($_[0]) },
  ':raw'    => sub { file_fh(':raw',    $_[0]) },
  ':unix'   => sub { file_fh(':unix',   $_[0]) },
  ':perlio' => sub { file_fh(':perlio', $_[0]) },
);
my @LAYERS = sort keys %MAKERS;

my @REQ = (1, 2, 3, 4, 5, 7, 64, 100_000);

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

my $euro = "\xE2\x82\xAC";       # U+20AC, 3-byte
my $grin = "\xF0\x9F\x98\x80";   # U+1F600, 4-byte
my $aao  = encode_utf8("\x{E5}\x{E4}\x{F6}");

my @CORPUS = (
  "",
  "hello world",
  $aao,
  "x${euro}y",
  "x${grin}y",
  "a${euro}b${grin}c\x{E5}",
  "a\x80b",
  "\x80\x80",
  "\xC0\x80",
  "\xED\xA0\x80",
  "\xF4\x90\x80\x80",
  "a\xC3",
  "x\xE2\x82",
  "x\xF0\x9F\x98",
  "\xD4\x42",
  "\xC3${euro}",
  "${euro}\x80${grin}",
  "\x80\xC3\x80\xE2\x28\xA1",
  "abcd" x 5000,
  $euro x 3000,
  "z${grin}${euro}\x80" x 2000,
);

# A grab-bag of byte fragments biased toward lead bytes, continuations and
# truncated sequences, so random inputs land on interesting boundaries.
my @FRAGMENTS = (
  "A", "z", " ", "\x00",
  $euro, $grin, $aao,
  "\x80", "\xBF", "\xC0", "\xC1", "\xC3", "\xD4",
  "\xE2", "\xE2\x82", "\xED\xA0", "\xF0\x9F\x98", "\xF4\x90",
  "\xFE", "\xFF",
);

sub random_bytes {
  my $n = int(rand(24));
  my $s = '';
  $s .= $FRAGMENTS[int(rand @FRAGMENTS)] for 1 .. $n;
  return $s;
}

my $checks     = 0;
my $mismatches = 0;

sub check {
  my ($bytes) = @_;
  my ($want, $wwarn) = oracle($bytes);
  for my $layer (@LAYERS) {
    for my $req (@REQ) {
      my ($got, $gwarn) = drain($MAKERS{$layer}->($bytes), $req);
      $checks++;
      next if $got eq $want && $gwarn == $wwarn;
      $mismatches++;
      printf STDERR "MISMATCH [%s req=%d] octets=%s\n", $layer, $req, unpack('H*', $bytes);
      printf STDERR "  want chars=%s warns=%d\n", unpack('H*', encode_utf8($want)), $wwarn;
      printf STDERR "  got  chars=%s warns=%d\n", unpack('H*', encode_utf8($got)),  $gwarn;
      exit 1 if $mismatches >= 5;
    }
  }
}

check($_) for @CORPUS;
check(random_bytes()) for 1 .. $ITERS;

printf "ok: %d checks, 0 mismatches (%d corpus + %d random, seed %d)\n",
  $checks, scalar(@CORPUS), $ITERS, $SEED;
