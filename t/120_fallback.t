#!perl

use strict;
use warnings;

use Test::More tests => 6;

BEGIN {
    use_ok('Unicode::UTF8', qw[ decode_utf8 encode_utf8 ]);
}

{
    my @tests = (
        [ "\x80 Foo \xE2\x98\xBA \xE0\x80\x80",
          "\x{FFFD} Foo \x{263A} \x{FFFD}\x{FFFD}\x{FFFD}",
          sub { return "\x{FFFD}" },
        ],
        [ "\x80 Foo \xE2\x98\xBA \xE0\x80\x80",
          "\x80 Foo \x{263A} \xE0\x80\x80",
          sub { return $_[0] }
        ],
    );

    foreach my $test (@tests) {
        my ($octets, $exp, $fallback) = @$test;

        my $name = sprintf 'decode_utf8(<%s>) eq <%s>',
          join(' ', map { sprintf '%.2X', ord } split //, $octets),
          join(' ', map { sprintf '%.4X', ord } split //, $exp);

        my $got = do {
            no warnings 'utf8';
            decode_utf8($octets, $fallback);
        };

        is($got, $exp, $name);
    }
}

{
    my @tests = (
        [ "\x{110000}",
          0x110000,
          sub { return $_[0] },
        ],
        [ "\x{110000} Foo \x{263A} \x{110000}",
          "\xEF\xBF\xBD Foo \xE2\x98\xBA \xEF\xBF\xBD",
          sub { return "\x{FFFD}" },
        ],
        [ "\x{110000} Foo \x{263A} \x{110000}",
          " Foo \xE2\x98\xBA ",
          sub { return '' }
        ],
    );

    foreach my $test (@tests) {
        my ($string, $exp, $fallback) = @$test;

        my $name = sprintf 'encode_utf8(<%s>) eq <%s>',
          join(' ', map { sprintf '%.2X', ord } split //, $string),
          join(' ', map { sprintf '%.4X', ord } split //, $exp);

        my $got = do {
            no warnings 'utf8';
            encode_utf8($string, $fallback);
        };

        is($got, $exp, $name);
    }
}

