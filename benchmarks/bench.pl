#!/usr/bin/perl
use strict;
use warnings;

use Benchmark     qw[];
use Encode        qw[];
use IO::Dir       qw[];
use Unicode::UTF8 qw[];

my $enc = Encode::find_encoding('UTF-8')
  || die(q/find_encoding('UTF-8')/);

my $dir = do {
    -d './data' ? './data' : './benchmarks/data';
};

my @docs = do {
    my $d = IO::Dir->new($dir)
      or die qq/Could not open directory '$dir': $!/;
    sort grep { /^[a-z]{2}\.txt/ } $d->read;
};

printf "perl:          %s\n", $];
printf "Encode:        %s\n", Encode->VERSION;
printf "Unicode::UTF8: %s\n", Unicode::UTF8->VERSION;

foreach my $doc (@docs) {

    my $src = do {
        open my $fh, '<:raw', "$dir/$doc" or die $!;
        local $/; <$fh>;
    };

    my $str = Unicode::UTF8::decode_utf8($src);

    my @ranges = (
        [    0x00,     0x7F, qr/[\x{00}-\x{7F}]/        ],
        [    0x80,    0x7FF, qr/[\x{80}-\x{7FF}]/       ],
        [   0x800,   0xFFFF, qr/[\x{800}-\x{FFFF}]/     ],
        [ 0x10000, 0x10FFFF, qr/[\x{10000}-\x{10FFFF}]/ ],
    );

    my $sum = 0;
    my @out;
    foreach my $r (@ranges) {
        my ($s, $e, $regexp) = @$r;
        my $c = () = $str =~ m/$regexp/g;
        push @out, sprintf "U+%.4X..U+%.4X: %d", $s, $e, $c;
        $sum += $c;
    }

    printf "\n\n%s: code points: %d (%s)\n", $doc, $sum, join ' ', @out;

    Benchmark::cmpthese( -10, {
        'U::U::decode' => sub {
            my $v = Unicode::UTF8::decode_utf8($src);
        },
        'Encode.pm relax' => sub {
            my $v = Encode::decode_utf8($src);
        },
        'Encode.pm strict' => sub {
            my $v = $enc->decode($src, Encode::FB_CROAK|Encode::LEAVE_SRC);
        },
    });
}

