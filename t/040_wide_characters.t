#!perl

use strict;
use warnings;

use Test::More  tests => 3;
use Test::Fatal qw[lives_ok];
use t::Util     qw[throws_ok];

BEGIN {
    use_ok('Unicode::UTF8', qw[ decode_utf8 ]);
}

{
    utf8::upgrade(my $octets = "blåbär är gött!");
    lives_ok { decode_utf8($octets); } 'decode_utf8() upgraded UTF-8 octets';
}

{
    use utf8;
    my $str = "\x{26C7}";
    throws_ok { decode_utf8($str); } qr/Can't decode a wide character string/, 'wide character string';
}

