#!/usr/bin/env perl
use strict;
use warnings;

use Benchmark     qw[];
use Config        qw[%Config];
use Encode        qw[];
use FindBin       qw[$Bin];
use IO::Dir       qw[];
use Unicode::UTF8 qw[];

my $enc = Encode::find_encoding('UTF-8')
  || die(q/find_encoding('UTF-8')/);

my $dir = do {
    -d "$Bin/data" ? "$Bin/data" : die q<Could not find path to benchmarks/data directory>;
};

my @docs = do {
    my $d = IO::Dir->new($dir)
      or die qq/Could not open directory '$dir': $!/;
    sort grep { /^[a-z]{2}\.txt/ } $d->read;
};

printf "perl:          %s (%s %s)\n", $], @Config{qw[osname osvers]};
printf "Encode:        %s\n", Encode->VERSION;
printf "Unicode::UTF8: %s\n", Unicode::UTF8->VERSION;

foreach my $doc (@docs) {

    my $octets = do {
        open my $fh, '<:raw', "$dir/$doc" or die $!;
        local $/; <$fh>;
    };

    my $string = Unicode::UTF8::decode_utf8($octets);

    my @ranges = (
        [    0x00,     0x7F, qr/[\x{00}-\x{7F}]/        ],
        [    0x80,    0x7FF, qr/[\x{80}-\x{7FF}]/       ],
        [   0x800,   0xFFFF, qr/[\x{800}-\x{FFFF}]/     ],
        [ 0x10000, 0x10FFFF, qr/[\x{10000}-\x{10FFFF}]/ ],
    );

    my @out;
    foreach my $r (@ranges) {
        my ($start, $end, $regexp) = @$r;
        my $count = () = $string =~ m/$regexp/g;
        push @out, sprintf "U+%.4X..U+%.4X: %d", $start, $end, $count
          if $count;
    }

    printf "\n\n%s: code points: %d (%s)\n", $doc, length $string, join ' ', @out;

    Benchmark::cmpthese( -10, {
        'Unicode::UTF8' => sub {
            my $v = Unicode::UTF8::decode_utf8($octets);
        },
        'Encode' => sub {
            my $v = $enc->decode($octets, Encode::FB_CROAK|Encode::LEAVE_SRC);
        },
    });
}

