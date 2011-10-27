#!perl

use strict;
use warnings;

use Test::More tests => 5;

BEGIN {
    use_ok('Unicode::UTF8', qw[ decode_utf8 encode_utf8 ]);
}

{
    my $octets = "\x80 Foo \xE2\x98\xBA \xE0\x80\x80";
    my $fallback = sub {
        return "\x{FFFD}";
    };

    my $got = do {
        no warnings 'utf8';
        decode_utf8($octets, $fallback);
    };

    my $exp = "\x{FFFD} Foo \x{263A} \x{FFFD}\x{FFFD}\x{FFFD}";

    my $name = sprintf 'decode_utf8(<%s>, $fallback1) eq <%s>',
      join(' ', map { sprintf '%.2X', ord } split //, $octets),
      join(' ', map { sprintf '%.4X', ord } split //, $exp);

    is($got, $exp, $name);
}

{
    my $octets   = "\x80 Foo \xE2\x98\xBA \xE0\x80\x80";
    my $fallback = sub {
        return $_[0];
    };

    my $got = do {
        no warnings 'utf8';
        decode_utf8($octets, $fallback);
    };

    my $exp = "\x80 Foo \x{263A} \xE0\x80\x80";

    my $name = sprintf 'decode_utf8(<%s>, $fallback2) eq <%s>',
      join(' ', map { sprintf '%.2X', ord } split //, $octets),
      join(' ', map { sprintf '%.4X', ord } split //, $exp);

    is($got, $exp, $name);
}

{
    my $string = do {
        no warnings 'utf8';
        "\x{110000} Foo \x{263A} \x{110000}";
    };
    my $fallback = sub {
        return "\x{FFFD}";
    };

    my $got = do {
        no warnings 'utf8';
        encode_utf8($string, $fallback);
    };

    my $exp = "\xEF\xBF\xBD Foo \xE2\x98\xBA \xEF\xBF\xBD";

    my $name = sprintf 'enode_utf8(<%s>, $fallback2) eq <%s>',
      join(' ', map { sprintf '%.2X', ord } split //, $string),
      join(' ', map { sprintf '%.4X', ord } split //, $exp);

    is($got, $exp, $name);
}

{
    my $string = do {
        no warnings 'utf8';
        "\x{110000} Foo \x{263A} \x{110000}";
    };
    my $fallback = sub {
        return '';
    };

    my $got = do {
        no warnings 'utf8';
        encode_utf8($string, $fallback);
    };

    my $exp = " Foo \xE2\x98\xBA ";

    my $name = sprintf 'enode_utf8(<%s>, $fallback2) eq <%s>',
      join(' ', map { sprintf '%.2X', ord } split //, $string),
      join(' ', map { sprintf '%.4X', ord } split //, $exp);

    is($got, $exp, $name);
}

