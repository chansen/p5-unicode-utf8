#!perl

use strict;
use warnings;

use Test::More  qw[no_plan];
use Test::Fatal qw[dies_ok];
use Encode      qw[_utf8_on];

BEGIN {
    use_ok('Unicode::UTF8', qw[ decode_utf8
                                encode_utf8 ]);
}

my @tests = (
    [   0x00, "\xC0\x80", "\xE0\x80\x80", "\xF0\x80\x80\x80", "\xF8\x80\x80\x80\x80", "\xFC\x80\x80\x80\x80\x80" ],
    [   0x80,             "\xE0\x82\x80", "\xF0\x80\x82\x80", "\xF8\x80\x80\x82\x80", "\xFC\x80\x80\x80\x82\x80" ],
    [  0x800,                             "\xF0\x80\xA0\x80", "\xF8\x80\x80\xA0\x80", "\xFC\x80\x80\x80\xA0\x80" ],
    [ 0x1000,                                                 "\xF8\x80\x90\x80\x80", "\xFC\x80\x80\x90\x80\x80" ],
);

foreach my $test (@tests) {
    my ($cp, @sequences) = @$test;

    foreach my $sequence (@sequences) {
        my $name = sprintf 'decode_utf8(<%s>) non-shortest form representation of U+%.4X',
          join(' ', map { sprintf '%.2X', ord $_ } split //, $sequence), $cp;

        dies_ok { decode_utf8($sequence) } $name;
    }
}

foreach my $test (@tests) {
    my ($cp, @sequences) = @$test;

    foreach my $sequence (@sequences) {
        my $name = sprintf 'encode_utf8(<%s>) non-shortest form representation of U+%.4X',
          join(' ', map { sprintf '%.2X', ord $_ } split //, $sequence), $cp;

        _utf8_on($sequence);
        dies_ok { encode_utf8($sequence) } $name;
    }
}

