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
  #$ENV{MOJO_OPENAPI_DEBUG} = 1;
  #$ENV{MOJO_LOG_LEVEL} = 'debug';
  $ENV{VERBOSE} = 1;
  $ENV{KOHA_PLUGIN_DEV_MODE} = 1;
  $ENV{MOJO_INACTIVITY_TIMEOUT} = 3600;
}

use Modern::Perl;
use utf8;

use Test::More tests => 2;
use Test::Deep;
use Test::Mojo;

use t::Lib::TestBuilder;
use t::Lib::Mocks;
use t::Lib::Util qw(build_patron build_valuebuilders_advanced);
use Mojo::URL;

use C4::Biblio;
use Koha::Database;

use Koha::Plugin::Fi::Hypernova::ValueBuilder;
use Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Subroutine;

my $schema = Koha::Database->schema;
$schema->storage->txn_begin;
my $plugin = Koha::Plugin::Fi::Hypernova::ValueBuilder->new(); #Make sure the plugin is installed

my $t = Test::Mojo->new('Koha::REST::V1');
t::Lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest("Scenario: Get Subroutine documentation.", sub {
  my ($subroutines);
  plan tests => 2;

  subtest("SetUp", sub {
    plan tests => 1;

    ok($subroutines = Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Subroutine::ListAvailable(),
      "Given a list of Subroutines");
  });

  subtest("Test documentation", sub {
    plan tests => 10;

    for (my $i=0 ; $i<@{$subroutines} ; $i++) {
      my $sub = $subroutines->[$i];
      ok($sub->{name}, "Then a name is defined");
      ok($sub->{documentation} !~ /Unable to parse doc for /,
        "Then the documentation is correctly parsed for the Subroutine '$i' '".$sub->{name}."'.");
    }
  });
});

subtest("Scenario: Test VB Subroutines.", sub {
  my ($url, $vbs, $bib);

  plan tests => 8;

  subtest("Given Valuebuilders", sub {
    plan tests => 2;

    ok($vbs = build_valuebuilders_advanced($plugin));
    ok($vbs->store(), "Builders stored");
  });

  subtest("Given a MARC record", sub {
    plan tests => 1;

    $bib = Koha::Biblios->search()->next;
    ok($bib, "A MARC record exists");
    t::Lib::Util::decorate_marcxml_for_signum_and_bib_class($bib);
  });

  my ($librarian, $librarian_userinfo) = build_patron({
      flags => 2,
  });
  $url = Mojo::URL->new('/api/v1/contrib/hypernova/catalogue/valuebuilder')
            ->query({ frameworkcode => '', fieldcode => '952', subfieldcode => 'a', itemtype => 'BK', branchcode => 'CPL', biblionumber => $bib->biblionumber });
  $url->userinfo($librarian_userinfo);

  subtest "<bib_class(,a)>" => sub {
    plan tests => 3;

    $url->query({subfieldcode => 'a'});
    $t->get_ok($url);
    $t->status_is('200')
    ->json_like('/value', qr/1\.2\.3\.4 84\.2 Muu/, "bib_class(,a)");
  };

  subtest "<bib_class(084,a)>" => sub {
    plan tests => 3;

    $url->query({subfieldcode => 'b'});
    $t->get_ok($url);
    $t->status_is('200')
    ->json_like('/value', qr/84\.2/, "bib_class(084,a)");
  };

  subtest "incremental_pattern_barcode(PREFIX00000000SUFFIX)" => sub {
    plan tests => 15;

    $url->query({subfieldcode => '0'});
    $t->get_ok($url);
    $t->status_is('200')
    ->json_like('/value', qr/PREFIX00000001SUFFIX/, "Initial increment");

    my $item = Koha::Items->search()->next;
    $item->barcode($t->tx->res->json('/value'));
    ok($item->store, "New barcode saved to Item");

    $t->get_ok($url)
    ->status_is('200')
    ->json_like('/value', qr/PREFIX00000002SUFFIX/, "Second increment");

    $item->barcode($t->tx->res->json('/value'));
    ok($item->store, "New barcode saved to Item");

    $t->get_ok($url)
    ->status_is('200')
    ->json_like('/value', qr/PREFIX00000003SUFFIX/, "Third increment");

    $item->barcode($t->tx->res->json('/value'));
    ok($item->store, "New barcode saved to Item");

    $t->get_ok($url)
    ->status_is('200')
    ->json_like('/value', qr/PREFIX00000004SUFFIX/, "Third increment");
  };

  subtest "incremental_pattern_barcode(00000000)" => sub {
    plan tests => 7;

    $url->query({subfieldcode => '1'});
    $t->get_ok($url);
    $t->status_is('200')
    ->json_like('/value', qr/00000001/, "Initial increment");

    my $item = Koha::Items->search()->next;
    $item->barcode('00000099');
    ok($item->store, "Barcode to test incrementing to 100");

    $t->get_ok($url)
    ->status_is('200')
    ->json_like('/value', qr/00000100/, "Increment to 100");
  };

  subtest "incremental_pattern_barcode(YEARv000)" => sub {
    plan tests => 7;
    my $year = DateTime->now(time_zone => C4::Context->tz)->year();

    $url->query({subfieldcode => '2'});
    $t->get_ok($url);
    $t->status_is('200')
    ->json_like('/value', qr/${year}v001/, "Initial increment");

    my $item = Koha::Items->search()->next;
    $item->barcode('00000099');
    ok($item->store, "Barcode to test incrementing to 100");

    $t->get_ok($url)
    ->status_is('200')
    ->json_like('/value', qr/${year}v002/, "Increment to 100");
  };

  subtest "f008_infer" => sub {
    plan tests => 6;
    my $yymmdd = DateTime->now(time_zone => C4::Context->tz)->strftime("%y%m%d");

    $url->query({fieldcode => '008', subfieldcode => '@', currentvalue => '000000n||||####xx#||||||||||||f|||||||||'});
    $t->get_ok($url);
    $t->status_is('200')
    ->json_like('/value', qr/^${yymmdd}/, "date entered on file set");

    $url->query({fieldcode => '008', subfieldcode => '@', currentvalue => '250102n||||####xx#||||||||||||f|||||||||', biblionumber => 9999999});
    $t->get_ok($url)
    ->status_is('200', 'Returns a reasonable value even without a biblio')
    ->json_like('/value', qr/^250102/, "date entered on file not overwritten");
  };
});

$schema->storage->txn_rollback;

1;
