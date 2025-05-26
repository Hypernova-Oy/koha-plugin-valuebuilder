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

use Test::More tests => 1;
use Test::Deep;
use Test::Mojo;

use t::Lib::TestBuilder;
use t::Lib::Mocks;
use t::Lib::Util qw(build_patron build_valuebuilders);
use Mojo::URL;

use Koha::Database;

use Koha::Plugin::Fi::Hypernova::ValueBuilder;

my $schema = Koha::Database->schema;
$schema->storage->txn_begin;
my $plugin = Koha::Plugin::Fi::Hypernova::ValueBuilder->new(); #Make sure the plugin is installed

my $t = Test::Mojo->new('Koha::REST::V1');
t::Lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest("Scenario: Simple test REST API calls.", sub {
  my ($url, $vbs);

  plan tests => 2;

  my ($patron, $userinfo, $patronPassword) = build_patron();
  my ($librarian, $librarian_userinfo) = build_patron({
      flags => 2,
  });
  $url = Mojo::URL->new('/api/v1/contrib/hypernova/catalogue/valuebuilder')
            ->query({ frameworkcode => '', fieldcode => '952', subfieldcode => 'a', itemtype => 'BK', branchcode => 'CPL', biblionumber => 1 });

  subtest("Given Valuebuilders", sub {
    plan tests => 2;

    ok($vbs = build_valuebuilders($plugin));
    ok($vbs->store(), "Builders stored");
  });

  subtest("Login without credentials", sub {
    plan tests => 3;

    $url->userinfo($userinfo);
    $t->get_ok($url)
    ->status_is('403')
    ->json_like('/error', qr/Missing required permission/, 'Missing required permission');
  });

  subtest "/catalogue/valuebuilder" => sub {
    plan tests => 13;

    $url->userinfo($librarian_userinfo);
    $url->query({subfieldcode => 'z'});
    $t->get_ok($url);
    $t->status_is('204')
    ->json_like('/error', qr/not configured/, "Builder not configured");

    $url->query({subfieldcode => 'd'});
    $t->get_ok($url)
    ->status_is('204')
    ->json_like('/error', qr/disabled/, "Builder is disabled");

    $url->query({subfieldcode => 'c'});
    $t->get_ok($url)
    ->status_is('200')
    ->json_like('/value', qr/PREFIXSUFFIX/, "PREFIXSUFFIX");
  };
});

subtest("Scenario: Test VB Subroutines.", sub {
  my ($url, $vbs);

  plan tests => 2;

  my ($librarian, $librarian_userinfo) = build_patron({
    flags => 2,
  });
  $url = Mojo::URL->new('/api/v1/contrib/hypernova/catalogue/valuebuilder')
            ->query({ frameworkcode => '', fieldcode => '952', subfieldcode => 'a', itemtype => 'BK', branchcode => 'CPL', biblionumber => 1 });

  subtest("Given Valuebuilders", sub {
    plan tests => 2;

    ok($vbs = build_valuebuilders_advanced($plugin));
    ok($vbs->store(), "Builders stored");
  });

  subtest "/catalogue/valuebuilder" => sub {
    plan tests => 13;

    $url->userinfo($librarian_userinfo);
    $url->query({subfieldcode => 'z'});
    $t->get_ok($url);
    $t->status_is('204')
    ->json_like('/error', qr/not configured/, "Builder not configured");

    $url->query({subfieldcode => 'd'});
    $t->get_ok($url)
    ->status_is('204')
    ->json_like('/error', qr/disabled/, "Builder is disabled");

    $url->query({subfieldcode => 'c'});
    $t->get_ok($url)
    ->status_is('200')
    ->json_like('/value', qr/PREFIXSUFFIX/, "PREFIXSUFFIX");
  };
});

$schema->storage->txn_rollback;

1;
