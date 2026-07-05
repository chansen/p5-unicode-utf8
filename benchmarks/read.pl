#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long        qw[];
use Time::HiRes         qw[clock_gettime CLOCK_MONOTONIC];
use Config              qw[%Config];
use Encode              qw[];
use IO::Dir             qw[];
use Unicode::UTF8       qw[read_utf8];

sub usage {
    print STDERR <<EOF;
Usage: $0 -d <dir> [-t <secs>]

Options:
  -d <dir>   benchmark all .txt files in directory
  -t <secs>  run each function for <secs> seconds (default: 5)

EOF
    exit 1;
}

my $Dir;
my $Seconds = 5;

Getopt::Long::GetOptions(
  'd=s' => \$Dir,
  't=i' => \$Seconds,
) or usage();

(defined $Dir && -d $Dir) or usage();

my @docs = do {
  my $d = IO::Dir->new($Dir)
    or die qq/Could not open corpus directory '$Dir': $!/;
  sort grep { /^[A-Za-z-]+\.txt/ } $d->read;
};

printf "perl:          %s (%s %s)\n", $], @Config{qw[osname osvers]};
printf "Encode:        %s\n",   Encode->VERSION;
printf "Unicode::UTF8: %s\n\n", Unicode::UTF8->VERSION;

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
  my ($octets, $fn, $codepoint_count) = @_;
  my $iters = 0;
  my $t     = clock_gettime(CLOCK_MONOTONIC);
  while (clock_gettime(CLOCK_MONOTONIC) - $t < $Seconds) {
    $fn->($octets, $codepoint_count);
    $iters++;
  }
  my $elapsed = clock_gettime(CLOCK_MONOTONIC) - $t;
  return $iters / $elapsed * (length($octets) / (1000 * 1000));
}

my @benchmark = (
  [ 'scalar:utf8', sub {
      open my $fh, '<:scalar:utf8', \$_[0]
        or die qq/Could not open a PerlIO::scalar:utf8 fh: '$!'/;
      read $fh, my $text, $_[1]
        or die qq/Could not read from fh: '$!'/;
      length $text == $_[1]
        or die qq/scalar:utf8 read mismatch/;
  }],
  [ 'scalar:encoding(UTF-8)', sub {
      open my $fh, '<:scalar:encoding(UTF-8)', \$_[0]
        or die qq/Could not open a PerlIO::scalar:encoding(UTF-8) fh: '$!'/;
      read $fh, my $text, $_[1]
        or die qq/Could not read from fh: '$!'/;
      length $text == $_[1]
        or die qq/scalar:encoding(UTF-8) read mismatch/;
  }],
  [ 'scalar + read_utf8', sub {
      open my $fh, '<:scalar', \$_[0]
        or die qq/Could not open a PerlIO::scalar fh: '$!'/;
      read_utf8 $fh, my $text, $_[1]
        or die qq/Could not read from fh: '$!'/;
      length $text == $_[1]
        or die qq/utf8_read read mismatch/;
  }]
);

eval {
  use PerlIO::utf8_strict;
  push @benchmark, [ 'scalar:utf8_strict', sub {
      open my $fh, '<:scalar:utf8_strict', \$_[0]
        or die qq/Could not open a PerlIO::scalar:utf8_strict fh: '$!'/;
      read $fh, my $text, $_[1]
        or die qq/Could not read from fh: '$!'/;
      length $text == $_[1]
        or die qq/scalar:utf8_strict read mismatch/;
  }];
};

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
    open my $fh, '<:raw', "$Dir/$doc" or die $!;
    local $/; <$fh>;
  };

  my $string = Unicode::UTF8::decode_utf8($octets);
  my $total  = length $string;

  printf "%s: %s; %s code points; %.2f units/point\n", $doc, 
    format_size(length $octets), format_count($total), length($octets) / $total;
  foreach my $i (0 .. $#regexps) {
    my $count = () = $string =~ m/$regexps[$i]/g;
    next unless $count;
    printf "  %-25s %6s  %4.1f%%\n", 
      $labels[$i], format_count($count), 100 * $count / $total;
  }

  my @rates;
  foreach my $impl (@benchmark) {
    push @rates, [ $impl->[0], bench($octets, $impl->[1], $total) ];
  }

  my @sorted  = sort { $a->[1] <=> $b->[1] } @rates;
  my $slowest = $sorted[0][1];

  printf "  %-24s  %8.0f MB/s\n", $sorted[0][0], $sorted[0][1];
  foreach my $i (1 .. $#sorted) {
    printf "  %-24s  %8.0f MB/s  (%.2fx)\n",
      $sorted[$i][0], $sorted[$i][1], $sorted[$i][1] / $slowest;
  }
  print "\n";
}
