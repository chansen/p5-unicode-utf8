use strict;
use inc::Module::Install;

("\t" eq "\x09")
  || die("OS unsupported\n");

name           'Unicode-UTF8';
perl_version   '5.008001';
all_from       'lib/Unicode/UTF8.pm';
repository     'http://github.com/chansen/p5-unicode-utf8';
readme_from    'lib/Unicode/UTF8.pod';

requires       'Carp'        => '0';
requires       'Exporter'    => '0';
requires       'XSLoader'    => '0';

test_requires  'Test::More'  => '0.47';
test_requires  'Test::Fatal' => '0.006';
test_requires  'Encode'      => '1.9801';
makemaker_args INC => '-I.';

tests 't/*.t t/*/*.t';

ppport;
requires_external_cc;

WriteAll;
