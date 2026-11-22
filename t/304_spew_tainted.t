#!perl

# Under taint mode spew_utf8() must refuse a tainted filename, as Perl's own
# open does for files opened for writing. Tainted content is fine.

use strict;
use warnings;

use Test::More;

BEGIN {
    eval 'use Taint::Runtime 0.03 qw[taint_start tainted];';
    plan skip_all => 'Taint::Runtime 0.03 is required for this test' if $@;
}

use Unicode::UTF8 qw[ spew_utf8 ];
use File::Temp    qw[ tempdir ];

my $dir  = tempdir(CLEANUP => 1);
my $path = "$dir/file";

taint_start();

plan skip_all => 'taint mode is not available on this perl' unless ${^TAINT};

{
  my $tainted = $path . tainted();
  my $ok = eval { spew_utf8($tainted, "x"); 1 };
  ok(!$ok, 'tainted filename croaks');
  like($@, qr/^Insecure dependency in spew_utf8/, 'tainted filename: message');
  ok(!-e $path, 'tainted filename: no file is created');
}

{
  my $ok = eval { spew_utf8($path, "content" . tainted()); 1 };
  ok($ok, 'tainted string is written') or diag $@;
  ok(-s $path, 'tainted string: file has content');
}

done_testing;
