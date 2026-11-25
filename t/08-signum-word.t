#!/usr/bin/env perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

BEGIN {
  $ENV{LOG4PERL_VERBOSITY_CHANGE} = 6;
  $ENV{VERBOSE} = 1;
  $ENV{KOHA_PLUGIN_DEV_MODE} = 1;
}

use Modern::Perl;
use utf8;

no warnings 'once';    # Koha::Biblios::find is only stubbed in this test file

use Test::More;

use MARC::Record;
use MARC::Field;

use Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Subroutine;

my $PACKAGE = 'Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Subroutine';

sub build_record {
  my (%fields) = @_;

  my $record = MARC::Record->new();
  $record->leader($fields{leader} // '     nz  a22     o  4500');

  for my $tag (sort keys %fields) {
    next if $tag eq 'leader';
    my $spec = $fields{$tag};
    $record->append_fields(
      MARC::Field->new(
        $tag,
        $spec->{i1} // ' ',
        $spec->{i2} // ' ',
        @{ $spec->{subfields} }
      )
    );
  }

  return $record;
}

sub signum_source_for {
  my ($record) = @_;
  return $PACKAGE->can('_signum_source')->($record);
}

sub signum_word_for {
  my ($record) = @_;
  return $PACKAGE->can('_signum_word_from_record')->($record);
}

# Exercises the public entry points (which fetch the biblio) with a stub.
sub _with_stub_pattern {
  my ($callback, $record) = @_;

  no warnings 'redefine';
  local *Koha::Biblios::find = sub { return bless { record => $record }, 'FakeBiblio' };
  my $pattern = bless { locals => bless { biblionumber => 1 }, 'FakeLocals' }, 'FakePattern';

  return $callback->($pattern);
}

sub signum_word_via_pattern {
  my ($record) = @_;
  return _with_stub_pattern(sub { $PACKAGE->__signum_word($_[0]) }, $record);
}

sub signum_via_pattern {
  my ($record) = @_;
  return _with_stub_pattern(sub { $PACKAGE->__signum($_[0]) }, $record);
}

my @cases = (
  {
    name   => 'inverted personal name, "Surname, Firstname"',
    record => build_record('100' => { subfields => [a => 'Surname, Firstname'] }),
    expect => 'Surname',
  },
  {
    name   => 'non-inverted personal name, "Auto Autonen"',
    record => build_record('100' => { subfields => [a => 'Auto Autonen'] }),
    expect => 'Auto',
  },
  {
    name   => 'disambiguation number is not part of the word',
    record => build_record('100' => { subfields => [a => 'Halonen, Antti (2)'] }),
    expect => 'Halonen',
  },
  {
    name   => 'life dates after the forename do not matter',
    record => build_record('100' => { subfields => [a => 'Smith, John, 1940-'] }),
    expect => 'Smith',
  },
  {
    name   => 'UTF-8 in the first word is preserved',
    record => build_record('100' => { subfields => [a => 'Åström, Lars Erik'] }),
    expect => 'Åström',
  },
  {
    name   => 'UTF-8 in a single token word is preserved',
    record => build_record('100' => { subfields => [a => 'Mónica'] }),
    expect => 'Mónica',
  },
  {
    name   => 'single token with a following word',
    record => build_record('100' => { subfields => [a => 'Err ó'] }),
    expect => 'Err',
  },
  {
    name   => 'apostrophe inside the word is kept',
    record => build_record('100' => { subfields => [a => "d'Hulst, Roger-A."] }),
    expect => "d'Hulst",
  },
  {
    name   => 'acute accent used as an apostrophe is kept',
    record => build_record('100' => { subfields => [a => 'd´O, Honoré'] }),
    expect => 'd´O',
  },
  {
    name   => 'trailing comma is trimmed',
    record => build_record('100' => { subfields => [a => 'Tal R,'] }),
    expect => 'Tal',
  },
  {
    name   => 'semicolon instead of a comma is trimmed',
    record => build_record('100' => { subfields => [a => 'Pettifor; Steven'] }),
    expect => 'Pettifor',
  },
  {
    name   => 'hyphen inside the word is kept',
    record => build_record('100' => { subfields => [a => 'IC-98, ryhmä'] }),
    expect => 'IC-98',
  },
  {
    name   => 'entities are left as-is, only the first word is returned',
    record => build_record('100' => { subfields => [a => 'Clegg &amp;amp; Guttmann, ryhmä'] }),
    expect => 'Clegg',
  },
  {
    name   => 'leading particle is returned literally (no data fixing)',
    record => build_record('100' => { subfields => [a => 'Van Asperen, Mónica'] }),
    expect => 'Van',
  },
  {
    name   => 'lowercase surname keeps its casing',
    record => build_record('100' => { subfields => [a => 'saari, Lars'] }),
    expect => 'saari',
  },
  {
    name   => 'corporate name (110)',
    record => build_record('110' => { subfields => [a => 'Museum of Modern Art (New York)'] }),
    expect => 'Museum',
  },
  {
    name   => 'UTF-8 corporate name (110)',
    record => build_record('110' => { subfields => [a => "Musée d'Orsay (Pariisi)"] }),
    expect => 'Musée',
  },
  {
    name   => 'uniform title (130) honours the non-filing indicator',
    record => build_record('130' => { i1 => '4', subfields => [a => 'The collected works'] }),
    expect => 'collected',
  },
  {
    name   => '245 honours the non-filing indicator',
    record => build_record('245' => { i1 => '1', i2 => '4', subfields => [a => 'The infinate space : women'] }),
    expect => 'infinate',
  },
  {
    name   => '245 with a blank non-filing indicator keeps the article (no data fixing)',
    record => build_record('245' => { i1 => '1', i2 => ' ', subfields => [a => 'The infinate space'] }),
    expect => 'The',
  },
  {
    name   => '245 non-filing count is character based (UTF-8)',
    record => build_record('245' => { i1 => '1', i2 => '5', subfields => [a => 'Ääniä yössä'] }),
    expect => 'yössä',
  },
  {
    name   => 'video (leader 06 = g) prefers 245 over 130',
    record => build_record(
      leader => '     ng  a22     o  4500',
      '130'  => { subfields => [a => 'Bible'] },
      '245'  => { i1 => '1', i2 => '4', subfields => [a => 'The video title'] },
    ),
    expect => 'video',
  },
  {
    name   => '130 is used when 100/110/111 are absent',
    record => build_record(
      '130' => { subfields => [a => 'Bible'] },
      '245' => { i1 => '1', i2 => '4', subfields => [a => 'The Bible'] },
    ),
    expect => 'Bible',
  },
  {
    name   => '100 wins over 130 and 245',
    record => build_record(
      '100' => { subfields => [a => 'Autonen, Auto'] },
      '130' => { subfields => [a => 'Bible'] },
      '245' => { i1 => '1', i2 => '4', subfields => [a => 'The Bible'] },
    ),
    expect => 'Autonen',
  },
  {
    name   => 'leading whitespace is skipped',
    record => build_record('100' => { subfields => [a => '   Leading spaces here'] }),
    expect => 'Leading',
  },
  {
    name   => 'repeated trailing punctuation is trimmed',
    record => build_record('100' => { subfields => [a => 'Word!!!'] }),
    expect => 'Word',
  },
  {
    name   => 'empty 100 falls through to 245',
    record => build_record(
      '100' => { subfields => [a => ''] },
      '245' => { i1 => '1', i2 => '0', subfields => [a => 'Title here'] },
    ),
    expect => 'Title',
  },
  {
    name   => 'no 1XX and no 245 yields an empty string',
    record => build_record(),
    expect => '',
  },
);

for my $case (@cases) {
  is(signum_word_for($case->{record}), $case->{expect}, $case->{name});
}

# The public entry point must behave the same as the pure helper.
is(
  signum_word_via_pattern(build_record('100' => { subfields => [a => 'Auto Autonen'] })),
  'Auto',
  'signum_word entry point reads the biblio record'
);

is(
  signum_word_via_pattern(build_record('100' => { subfields => [a => 'Mónica Álvarez'] })),
  'Mónica',
  'signum_word entry point preserves UTF-8'
);

# The existing 3-character signum must not change.
is(
  signum_via_pattern(build_record('100' => { subfields => [a => 'Meikäläinen, Matti'] })),
  'MEI',
  'signum still returns the first three characters, uppercased'
);

is(
  signum_via_pattern(build_record('245' => { i1 => '1', i2 => '4', subfields => [a => 'The infinate space'] })),
  'INF',
  'signum honours the 245 non-filing indicator'
);

is(
  signum_via_pattern(build_record()),
  '',
  'signum returns an empty string when there is no source'
);

# _signum_source exposes the resolved source and indicator.
{
  my ($source, $non_filing) = signum_source_for(
    build_record('245' => { i1 => '1', i2 => '4', subfields => [a => 'The infinate space'] })
  );
  is($source,     'The infinate space', 'signum source text');
  is($non_filing, 4,                    'signum source non-filing indicator');
}

{
  my ($source, $non_filing) = signum_source_for(build_record());
  is($source,     undef, 'no signum source text');
  is($non_filing, 0,     'no non-filing indicator');
}

done_testing();

package FakeBiblio;
sub record { $_[0]->{record} }

package FakeLocals;
sub biblionumber { $_[0]->{biblionumber} }

package FakePattern;
sub locals { $_[0]->{locals} }

package main;
