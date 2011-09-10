#!perl

use strict;
use warnings;

use Test::More  tests => 5;
use Test::Fatal qw[lives_ok];
use t::Util     qw[slurp];

BEGIN {
    use_ok('Unicode::UTF8', qw[ decode_utf8
                                encode_utf8 ]);
}

my $octets = do {
    open my $fh, '<:raw', 't/quickbrown.txt' or die q<could not open 't/quickbrown.txt'>;
    slurp($fh);
};

my $string = do { utf8::decode(my $copy = $octets); $copy };

{
    my $got;
    lives_ok { $got = decode_utf8($octets); } 'decode_utf8()';
    is($got, $string, 'decode_utf8() result');
}

{
    my $got;
    lives_ok { $got = encode_utf8($string); } 'encode_utf8()';
    is($got, $octets, 'encode_utf8() result');
}


