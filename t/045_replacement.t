#!perl

use strict;
use warnings;

use Test::More tests => 30;

BEGIN {
    use_ok('Unicode::UTF8', qw[ decode_utf8 ]);
}

my $replacement = "\x{FFFD}";

my @tests = (
    [ "\x80",               1 ],
    [ "\x80\x80",           2 ],
    [ "\x80\x80\x80",       3 ],
    [ "\xC0\x80",           2 ],
    [ "\xC1\x80",           2 ],
    [ "\xC2",               1 ],
    [ "\xE0\x80\x80",       3 ],
    [ "\xE0\xA0",           1 ],
    [ "\xE0\x9F\x80",       3 ],
    [ "\xED\xA0\x80",       3 ],
    [ "\xED\x80",           1 ],
    [ "\xED\xBF\x80",       3 ],
    [ "\xF0\x80\x80\x80",   4 ],
    [ "\xF0\x90\x80",       1 ],
    [ "\xF0\x8F\x80\x80",   4 ],
    [ "\xF4\x80\x80",       1 ],
    [ "\xF4\x90\x80\x80",   4 ],
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

