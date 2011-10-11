#!perl
use strict;
use warnings;

use Test::More;

BEGIN {
    eval 'use Variable::Magic qw[cast wizard];';
    plan skip_all => 'Variable::Magic is required for this test' if $@;
    plan tests => 5;
}

BEGIN {
    use_ok('Unicode::UTF8', qw[ decode_utf8
                                encode_utf8 ]);
}

my ($nget, $nset);

my $wizard = wizard get => sub { $nget++ },
                    set => sub { $nset++ };


($nget, $nset) = (0, 0);

{
    my $octets = "\x80\x80\x80";
    my $string;

    cast $octets, $wizard;
    cast $string, $wizard;
    {
        no warnings 'utf8';
        $string = decode_utf8($octets);
    }

    is($nget, 1, 'decode_utf8() GET magic');
    is($nset, 1, 'decode_utf8() SET magic');
}

($nget, $nset) = (0, 0);

{
    my $string = "\x{110000}\x{110000}\x{110000}";
    my $octets;

    cast $octets, $wizard;
    cast $string, $wizard;
    {
        no warnings 'utf8';
        $octets = encode_utf8($string);
    }

    is($nget, 1, 'encode_utf8() GET magic');
    is($nset, 1, 'encode_utf8() SET magic');
}


