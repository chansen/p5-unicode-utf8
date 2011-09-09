#!perl

use strict;
use warnings;

use Test::More  qw[no_plan];
use Test::Fatal qw[dies_ok];
use t::Util     qw[pack_utf8];

BEGIN {
    use_ok('Unicode::UTF8', qw[ decode_utf8
                                encode_utf8 ]);
}

my @RESTRICTED = ();
{
    for (my $i = 0x110000; $i < 0x7FFFFFFF; $i += 0x200000) {
        push @RESTRICTED, $i;
    }
}

foreach my $cp (@RESTRICTED) {
    my $octets = pack_utf8($cp);

    my $name = sprintf 'decode_utf8(<%s>) restricted U-%.8X',
      join(' ', map { sprintf '%.2X', ord $_ } split //, $octets), $cp;

    dies_ok { decode_utf8($octets) } $name;
}

foreach my $cp (@RESTRICTED) {
    my $name = sprintf 'encode_utf8("\\x{%.4X}") restricted U-%.8X',
      $cp, $cp;

    my $string = do { no warnings 'utf8'; pack('U', $cp) };

    dies_ok { encode_utf8($string) } $name;
}

