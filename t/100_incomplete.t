#!perl

use strict;
use warnings;

use Test::More  qw[no_plan];
use Test::Fatal qw[dies_ok];
use Encode      qw[_utf8_on];
use t::Util     qw[pack_utf8];

BEGIN {
    use_ok('Unicode::UTF8', qw[ decode_utf8
                                encode_utf8 ]);
}

my @INCOMPLETE = ();

{
    for (my $i = 0x80; $i < 0x10FFFF; $i += 0x1000) {
        push @INCOMPLETE, substr(pack_utf8($i), 0, -1);
    }
}

foreach my $sequence (@INCOMPLETE) {
    my $name = sprintf 'decode_utf8(<%s>) incomplete UTF-8 sequence',
      join(' ', map { sprintf '%.2X', ord $_ } split //, $sequence);

    dies_ok { decode_utf8($sequence) } $name;
}

foreach my $sequence (@INCOMPLETE) {
    my $name = sprintf 'encode_utf8(<%s>) incomplete UTF-8 sequence',
      join(' ', map { sprintf '%.2X', ord $_ } split //, $sequence);

    _utf8_on($sequence);
    dies_ok { encode_utf8($sequence) } $name;
}

