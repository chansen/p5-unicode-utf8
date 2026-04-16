#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long  qw[];
use Time::HiRes   qw[clock_gettime CLOCK_MONOTONIC];
use Config        qw[%Config];
use Encode        qw[];
use FindBin       qw[$Bin];
use IO::Dir       qw[];
use Unicode::UTF8 qw[];

my $dir_opt;

Getopt::Long::GetOptions(
  'd=s' => \$dir_opt,
) or die "Usage: $0 [-d <directory>]\n";

my $enc = Encode::find_encoding('UTF-8')
  or die q/find_encoding('UTF-8')/;

my $dir = $dir_opt                  ? $dir_opt
        : -d "$Bin/data"            ? "$Bin/data"
        : die q<Could not find path to benchmarks/data directory>;

my @docs = do {
  my $d = IO::Dir->new($dir)
    or die qq/Could not open directory '$dir': $!/;
  sort grep { /^[A-Za-z]+\.txt/ } $d->read;
};

printf "perl:          %s (%s %s)\n", $], @Config{qw[osname osvers]};
printf "Encode:        %s\n",   Encode->VERSION;
printf "Unicode::UTF8: %s\n\n", Unicode::UTF8->VERSION;

my $BENCH_SECONDS = 20;

sub format_size {
  my ($n) = @_;
  if ($n >= 1024 * 1024 * 1024) {
    return sprintf '%.0f GiB', $n / (1024 * 1024 * 1024);
  }
  if ($n >= 1024 * 1024.0) {
    return sprintf '%.0f MiB', $n / (1024 * 1024);
  }
  if ($n >= 1024) {
    return sprintf '%.0f KiB', $n / 1024;
  }
  return sprintf '%d bytes', $n;
}

sub format_count {
  my ($n) = @_;
  if ($n >= 1000 * 1000 * 1000) {
    return sprintf '%.0fB', $n / (1000 * 1000 * 1000);
  }
  if ($n >= 1000 * 1000) {
    return sprintf '%.0fM', $n / (1000 * 1000);
  }
  if ($n >= 1000) {
    return sprintf '%.0fK', $n / 1000;
  }
  return sprintf '%d', $n;
}

sub bench {
  my ($octets, $fn) = @_;
  my $mb      = length($octets) / (1024 * 1024);
  my $iters   = 0;
  my $t       = clock_gettime(CLOCK_MONOTONIC);
  while (clock_gettime(CLOCK_MONOTONIC) - $t < $BENCH_SECONDS) {
    $fn->($octets);
    $iters++;
  }
  my $elapsed = clock_gettime(CLOCK_MONOTONIC) - $t;
  return $iters / $elapsed * (length($octets) / (1000 * 1000));
}

my @benchmark = (
  [ 'Encode', sub {
    $enc->decode($_[0], Encode::FB_CROAK | Encode::LEAVE_SRC);
  }],
  [ 'Unicode::UTF8', sub {
    Unicode::UTF8::decode_utf8($_[0]);
  }],
);

my @labels  = ('U+0000..U+007F',
               'U+0080..U+07FF',
               'U+0800..U+FFFF',
               'U+10000..U+10FFFF');

my @regexps = (qr/[\x{00}-\x{7F}]/,
               qr/[\x{80}-\x{7FF}]/,
               qr/[\x{800}-\x{FFFF}]/,
               qr/[\x{10000}-\x{10FFFF}]/);

foreach my $doc (@docs) {
  my $octets = do {
    open my $fh, '<:raw', "$dir/$doc" or die $!;
    local $/; <$fh>;
  };

  my $string = Unicode::UTF8::decode_utf8($octets);
  my $total  = length $string;

  printf "%s: %s; %s code points; %.2f units/point\n", $doc, 
    format_size(length $octets), format_count($total), length($octets) / $total;
  foreach my $i (0 .. $#regexps) {
    my $count = () = $string =~ m/$regexps[$i]/g;
    next unless $count;
    printf "  %-20s %6s  %4.1f%%\n", 
      $labels[$i], format_count($count), 100 * $count / $total;
  }

  my @rates;
  foreach my $impl (@benchmark) {
    push @rates, [ $impl->[0], bench($octets, $impl->[1]) ];
  }

  my @sorted  = sort { $a->[1] <=> $b->[1] } @rates;
  my $slowest = $sorted[0][1];

  printf "  %-19s  %8.0f MB/s\n", $sorted[0][0], $sorted[0][1];
  foreach my $i (1 .. $#sorted) {
    printf "  %-19s  %8.0f MB/s  (%.2fx)\n",
      $sorted[$i][0], $sorted[$i][1], $sorted[$i][1] / $slowest;
  }
  print "\n";
}
