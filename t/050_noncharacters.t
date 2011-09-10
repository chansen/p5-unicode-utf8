#!perl

use strict;
use warnings;

use Test::More tests => 133;
use t::Util    qw[throws_ok pack_utf8];

BEGIN {
    use_ok('Unicode::UTF8', qw[ decode_utf8
                                encode_utf8 ]);
}

my @NONCHARACTERS = (0xFDD0 .. 0xFDEF);
{
    for (my $i = 0; $i < 0x10FFFF; $i += 0x10000) {
        push @NONCHARACTERS, $i ^ 0xFFFE, $i ^ 0xFFFF;
    }
}

foreach my $cp (@NONCHARACTERS) {
    my $octets = pack_utf8($cp);

    my $name = sprintf 'decode_utf8(<%s>) noncharacter U+%.4X',
      join(' ', map { sprintf '%.2X', ord $_ } split //, $octets), $cp;

    throws_ok { decode_utf8($octets) } qr/Can't interchange noncharacter code point/, $name;
}

foreach my $cp (@NONCHARACTERS) {
    my $name = sprintf 'encode_utf8("\\x{%.4X}") noncharacter U+%.4X',
      $cp, $cp;

    my $string = do { no warnings 'utf8'; pack('U', $cp) };

    throws_ok { encode_utf8($string) } qr/Can't interchange noncharacter code point/, $name;
}

