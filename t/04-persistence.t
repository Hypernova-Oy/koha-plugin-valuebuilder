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

use Test::More tests => 1;
use Test::Deep;
use t::Lib::Util qw(build_valuebuilders);

use Koha::Plugin::Fi::Hypernova::ValueBuilder;
use Koha::Plugin::Fi::Hypernova::ValueBuilder::ValueBuilders;

use t::Lib;

subtest("Scenario: Persistence tests.", sub {
  plan tests => 5;

  my $plugin = Koha::Plugin::Fi::Hypernova::ValueBuilder->new();

  subtest("Persist valuebuilders", sub {
    plan tests => 1;

    my $vbs = build_valuebuilders($plugin);
    ok($vbs->store(), "valuebuilders stored");
  });

  subtest("Retrieve valuebuilders", sub {
    plan tests => 4;

    my $vbs = Koha::Plugin::Fi::Hypernova::ValueBuilder::ValueBuilders->new->retrieveAll();
    my $b = $vbs->get('','952','a');
    is($b->trigger, 'prefill');
    is(@{$b->pattern->subroutines}, 1);

    $b = $vbs->get('','952','b');
    is($b->trigger, 'trigger');
    is(@{$b->pattern->subroutines}, 2);
  });

  subtest("Retrieve a single builder", sub {
    plan tests => 2;

    my $b = Koha::Plugin::Fi::Hypernova::ValueBuilder::ValueBuilders->new->retrieve('','952','a');
    is($b->trigger, 'prefill');
    is(@{$b->pattern->subroutines}, 1);
  });
});

1;
