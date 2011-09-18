#!perl

use strict;
use warnings;

use Test::More tests => 18;

BEGIN {
    use_ok('Unicode::UTF8', qw[ decode_utf8 ]);
}

my $replacement = "\x{FFFD}";

my @tests = (
    [ "\xC0\x80",           2 ],
    [ "\xC1\x80",           2 ],
    [ "\xE0\x80\x80",       1 ],
    [ "\xED\xA0\x80",       1 ],
    [ "\xF0\x80\x80\x80",   1 ],
    [ "\xF5\x80\x80",       3 ],
    [ "\xF5\x80\x80\x80",   4 ],
    [ "\xF6\x80\x80",       3 ],
    [ "\xF7\x80\x80",       3 ],
    [ "\xF8\x80\x80\x80",   4 ],
    [ "\xF9\x80",           2 ],
    [ "\xFA\x80",           2 ],
    [ "\xFB\x80",           2 ],
    [ "\xFC\x80",           2 ],
    [ "\xFD\x80",           2 ],
    [ "\xFE\x80",           2 ],
    [ "\xFF\x80",           2 ],
);

foreach my $test (@tests) {
    my ($octets, $n) = @$test;

    my $exp = $replacement x $n;
    my $got = do {
        no warnings 'utf8';
        decode_utf8($octets);
    };

    my $name = sprintf 'decode_utf8(<%s>) eq <%s>',
      join(' ', map { sprintf '%.2X', ord } split //, $octets),
      join(' ', map { sprintf '%.4X', ord } split //, $exp);

    is($got, $exp, $name);
}

