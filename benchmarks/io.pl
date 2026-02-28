#!/usr/bin/env perl

use strict;
use warnings;

use Benchmark     qw[];
use Encode        qw[];
use FindBin       qw[$Bin];
use IO::File      qw[SEEK_SET];
use Unicode::UTF8 qw[decode_utf8];

my $dir = do {
    -d "$Bin/data" ? "$Bin/data" : die q<Could not find path to benchmarks/data directory>;
};

my $path   = "$dir/sv.txt";
my $octets = do {
    open my $fh, '<:raw', $path 
      or die qq/Could not open '$path': '$!'/;
    local $/; <$fh>;
};

open my $u_fh, '<', \$octets 
  or die qq/Could not open a PerlIO::scalar fh: '$!'/;
open my $e_fh, '<:encoding(UTF-8)', \$octets 
  or die qq/Could not open a PerlIO::scalar fh: '$!'/;

Benchmark::cmpthese( -10, {
    'Unicode::UTF8' => sub {
        while (<$u_fh>) {
            my $line = decode_utf8($_);
        }
        seek($u_fh, 0, SEEK_SET)
         or die qq/Could not rewind fh: '$!'/;
    },
    'encoding.pm' => sub {
        while (<$e_fh>) {
            my $line = $_;
        }
        seek($e_fh, 0, SEEK_SET)
          or die qq/Could not rewind fh: '$!'/;
    },
});

