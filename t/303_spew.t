#!perl

# Exercises spew_utf8($filename, $string): it writes the string encoded as
# UTF-8 with unbuffered (:unix) IO, with the same U+FFFD substitution and
# utf8 warnings as encode_utf8().

use strict;
use warnings;
use lib 't';

use Test::More;
use Unicode::UTF8 qw[ spew_utf8 slurp_utf8 encode_utf8 ];
use Util          qw[ throws_ok warns_ok ];

use File::Temp qw[ tempdir ];

my $dir = tempdir(CLEANUP => 1);
my $seq = 0;

sub fresh_path { return sprintf '%s/file-%d', $dir, ++$seq }

sub octets_of {
  my ($path) = @_;
  open my $fh, '<', $path or die "Cannot open '$path': $!";
  binmode $fh;
  local $/;
  my $octets = <$fh>;
  close $fh;
  return $octets;
}

sub oracle {
  my ($string) = @_;
  my @w;
  local $SIG{__WARN__} = sub { push @w, @_ };
  use warnings 'utf8';
  my $octets = encode_utf8($string);
  return ($octets, scalar @w);
}

my $surrogate = do { no warnings 'utf8'; "\x{D800}" };
my $super     = do { no warnings 'utf8'; "\x{110000}" };
my $upgraded  = "abc";
utf8::upgrade($upgraded);

my %CORPUS = (
  'empty'                 => "",
  'ascii'                 => "hello world",
  'upgraded ascii'        => $upgraded,
  'native 8-bit'          => "caf\xE9",
  'native, looks encoded' => "\xC3\xA9",
  'wide'                  => "\x{20AC}\x{1F600}",
  'mixed widths'          => "a\x{20AC}b\x{1F600}c\x{E5}",
  'noncharacter'          => "\x{FFFE}",
  'surrogate'             => "a${surrogate}b",
  'super'                 => "a${super}b",
  # larger than one write is likely to be split into
  'large'                 => ("z\x{1F600}\x{20AC}\x{E5}abc" x 200000),
);

# ---- octets and warning count match encode_utf8() ------------------------

for my $name (sort keys %CORPUS) {
  my $string = $CORPUS{$name};
  my ($want, $wwarn) = oracle($string);
  my $path = fresh_path();

  my @w;
  my $ret;
  {
    local $SIG{__WARN__} = sub { push @w, @_ };
    use warnings 'utf8';
    $ret = spew_utf8($path, $string);
  }

  ok($ret,                         "'$name': returns true");
  ok(octets_of($path) eq $want,    "'$name': octets match encode_utf8");
  is(scalar @w, $wwarn,            "'$name': utf8 warning count matches encode_utf8");
}

# ---- round trip through slurp_utf8() ---------------------------------------

{
  my $string = "a\x{20AC}b\x{1F600}c\x{E5}\n" x 1000;
  my $path   = fresh_path();
  spew_utf8($path, $string);
  ok(slurp_utf8($path) eq $string, 'round trip: slurp_utf8 returns the string');
}

# ---- an existing file is replaced ------------------------------------------

{
  my $path = fresh_path();
  spew_utf8($path, "a much longer first version\n");
  spew_utf8($path, "short");
  is(octets_of($path), "short", 'existing file is truncated');
}

# ---- warnings ---------------------------------------------------------------

warns_ok {
  use warnings 'utf8';
  spew_utf8(fresh_path(), "a${surrogate}b");
} qr/Can't represent surrogate code point U\+D800 in position 1/,
  'surrogate: warns in the utf8 category';

{ # suppressed under 'no warnings utf8', still replaced
  my @w;
  local $SIG{__WARN__} = sub { push @w, @_ };
  my $path = fresh_path();
  {
    no warnings 'utf8';
    spew_utf8($path, "a${super}b");
  }
  is(scalar @w, 0,                         'super: silent without utf8 warnings');
  is(octets_of($path), "a\xEF\xBF\xBDb",   'super: still replaced when silent');
}

{ # a fatal warning is raised before the file is opened
  my $path = fresh_path();
  spew_utf8($path, "keep");

  throws_ok {
    use warnings FATAL => 'utf8';
    spew_utf8($path, "a${surrogate}b");
  } qr/^Can't represent surrogate code point/,
    'fatal utf8 warning croaks';
  is(octets_of($path), "keep", 'fatal utf8 warning: existing file is untouched');

  my $missing = fresh_path();
  eval {
    use warnings FATAL => 'utf8';
    spew_utf8($missing, "a${surrogate}b");
  };
  ok(!-e $missing, 'fatal utf8 warning: no file is created');
}

# ---- filename is a string of octets ---------------------------------------

{
  package Local::FetchCounter;
  sub TIESCALAR { my ($class, $value) = @_; bless { value => $value, count => 0 }, $class }
  sub FETCH     { $_[0]{count}++; $_[0]{value} }
}

{
  my $name     = "$dir/caf\xC3\xA9.txt";
  my $upgraded = $name;
  utf8::upgrade($upgraded);

  spew_utf8($name, "one");
  is(octets_of($name), "one", 'filename: downgraded string names the file');

  spew_utf8($upgraded, "two");
  is(octets_of($name), "two", 'filename: upgraded string names the same file');
  ok(utf8::is_utf8($upgraded), 'filename: upgraded argument is not modified');

  for my $case ([ downgraded => $name ], [ upgraded => $upgraded ]) {
    my ($form, $value) = @$case;
    tie my $tied, 'Local::FetchCounter', $value;
    spew_utf8($tied, $form);
    is(octets_of($name), $form,   "filename: tied $form string names the file");
    is((tied $tied)->{count}, 1,  "filename: tied $form string is fetched once");
  }

  tie my $tied, 'Local::FetchCounter', "\x{20AC}";
  spew_utf8($name, $tied);
  is(octets_of($name), "\xE2\x82\xAC", 'string: tied string is written');
  is((tied $tied)->{count}, 1,         'string: tied string is fetched once');
}

# ---- errors --------------------------------------------------------------

throws_ok {
  spew_utf8("$dir/no/such/directory/file", "x");
} qr!^Couldn't open '\Q$dir\E/no/such/directory/file': !,
  'unwritable path croaks with "Couldn\'t open ..."';

throws_ok {
  spew_utf8("snowman-\x{2603}.txt", "x");
} qr/^Wide character in filename/,
  'wide character in filename croaks';

for my $case ([ downgraded => 0 ], [ upgraded => 1 ]) {
  my ($form, $upgrade) = @$case;
  my $name = "$dir/nul\0.txt";
  utf8::upgrade($name) if $upgrade;

  throws_ok {
    spew_utf8($name, "x");
  } qr/^Invalid \\0 character in filename/,
    "NUL in $form filename croaks";
  ok(!-e "$dir/nul", "NUL in $form filename: no truncated name is created");
}

done_testing;
