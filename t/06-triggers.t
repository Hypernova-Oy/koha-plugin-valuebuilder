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

use Modern::Perl;
use utf8;
use strict;
use warnings;

use Test::More tests => 1;
use Test::Deep;

use Koha::Plugin::Fi::Hypernova::ValueBuilder;
use Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Trigger;

use t::Lib;

subtest("Scenario: Get Trigger documentation.", sub {
  my ($triggers);
  plan tests => 2;

  my $plugin = Koha::Plugin::Fi::Hypernova::ValueBuilder->new();

  subtest("SetUp", sub {
    plan tests => 1;

    ok($triggers = Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Trigger::ListAvailable(),
      "Given a list of Triggers");
  });

  subtest("Test documentation", sub {
    plan tests => 8;

    for (my $i=0 ; $i<@{$triggers} ; $i++) {
      ok($triggers->[$i]->{name}, "Then a name is defined");
      ok($triggers->[$i]->{documentation} !~ /Unable to parse doc for trigger/,
        "Then the documentation is correctly parsed for the Trigger '$i' '".$triggers->[$i]->{name}."'.");
    }
  });
});

1;
