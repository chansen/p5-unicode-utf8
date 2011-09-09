#!perl

use strict;
use warnings;

use Test::More tests => 1;

BEGIN {
    use_ok('Unicode::UTF8');
}

diag("Unicode::UTF8 $Unicode::UTF8::VERSION, Perl $], $^X");

__END__

000_load.t

0XX_wide_character.t
0XX_native.t

050_noncharacters.t
060_surrogates.t
070_restricted.t
080_super.t
090_non_shortest_form.t
100_incomplete.t

