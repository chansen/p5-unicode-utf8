#!perl

use strict;
use warnings;

use Test::More  tests => 4097;
use Test::Fatal qw[dies_ok];
use t::Util     qw[pack_utf8];

BEGIN {
    use_ok('Unicode::UTF8', qw[ decode_utf8
                                encode_utf8 ]);
}

my @SURROGATES = (0xD800 .. 0xDFFF);

foreach my $cp (@SURROGATES) {
    my $octets = pack_utf8($cp);

    my $name = sprintf 'decode_utf8(<%s>) surrogate U+%.4X',
      join(' ', map { sprintf '%.2X', ord $_ } split //, $octets), $cp;

    dies_ok { decode_utf8($octets) } $name;
}

foreach my $cp (@SURROGATES) {
    my $name = sprintf 'encode_utf8("\\x{%.4X}") surrogate U+%.4X',
      $cp, $cp;

    my $string = do { no warnings 'utf8'; pack('U', $cp) };

    dies_ok { encode_utf8($string) } $name;
}

