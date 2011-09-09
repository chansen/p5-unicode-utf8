#!perl

use strict;
use warnings;

use Test::More  qw[no_plan];
use Test::Fatal qw[dies_ok];

BEGIN {
    use_ok('Unicode::UTF8', qw[ decode_utf8
                                encode_utf8 ]);
}

my @SUPER = ();
{
    for (my $i = 0x8000000; $i < 0xFFFFFFFF; $i += 0x400000) {
        push @SUPER, $i;
    }
}

foreach my $cp (@SUPER) {
    my $name = sprintf 'encode_utf8("\\x{%.4X}") super U-%.8X',
      $cp, $cp;

    my $string = do { no warnings 'utf8'; pack('U', $cp) };

    dies_ok { encode_utf8($string) } $name;
}

