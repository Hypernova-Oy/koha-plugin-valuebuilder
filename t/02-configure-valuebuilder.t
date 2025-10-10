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
  $ENV{MOJO_OPENAPI_DEBUG} = 1;
  $ENV{MOJO_LOG_LEVEL} = 'debug';
  $ENV{VERBOSE} = 1;
  $ENV{KOHA_PLUGIN_DEV_MODE} = 1;
}

use Modern::Perl;
use utf8;

use Test::More tests => 1;
use Test::Deep;
use Test::Mojo;

use Koha::Plugin::Fi::Hypernova::ValueBuilder;

use t::Lib;

subtest("Scenario: Configure ValueBuilders.", sub {
  plan tests => 9;

  my $plugin = Koha::Plugin::Fi::Hypernova::ValueBuilder->new(); #Make sure the plugin is installed

  subtest("Save a Builder", sub {
    plan tests => 5;

    $plugin->{cgi} = FakeCGI->new(params => {
        frameworkcode => '',
        fieldcode => '952',
        subfieldcode => 'c',
        pattern => '<incremental_pattern_barcode(PREFIX00000000SUFFIX)>',
        trigger => 'onsave',
    });
    ok($plugin->save_builder(), "Saving a Builder");
    ok($Koha::Plugin::Fi::Hypernova::ValueBuilder::http_response{headers}->[0] =~ m!Location.*?error=!gsm, "Request has been redirected");

    my $b = $plugin->valuebuilders->retrieve('', '952', 'c');
    is($b->trigger, 'onsave');
    is($b->pattern->subroutines->[0]->name, 'incremental_pattern_barcode');
    is($b->pattern->subroutines->[0]->parameters->[0], 'PREFIX00000000SUFFIX');
  });

  subtest("Save a broken Builder", sub {
    plan tests => 2;

    $plugin->{cgi} = FakeCGI->new(params => {
        frameworkcode => '',
        fieldcode => '952',
        subfieldcode => 'f',
        pattern => 'PREFIX00000000SUFFIX',
        trigger => 'onsave',
    });
    ok(! $plugin->save_builder(), "Saving a broken Builder failed");
    ok($Koha::Plugin::Fi::Hypernova::ValueBuilder::http_response{headers}->[0] =~ m!Location.*?error=!gsm, "Request has been redirected with error information");
  });

  subtest("Load plugin configurer after config", sub {
    plan tests => 8;

    $plugin->{cgi} = FakeCGI->new();
    ok($plugin->configure(), "Loading the configure-view");
    is($Koha::Plugin::Fi::Hypernova::ValueBuilder::http_response{status}, 200, "Status '200'");
    ok($Koha::Plugin::Fi::Hypernova::ValueBuilder::http_response{html} =~ m!prefill!gsm, "prefill-trigger rendered");
    ok($Koha::Plugin::Fi::Hypernova::ValueBuilder::http_response{html} =~ m!disabled!gsm, "disabled-trigger rendered");
    ok($Koha::Plugin::Fi::Hypernova::ValueBuilder::http_response{html} =~ m!text!gsm, "text-subroutine rendered");
    ok($Koha::Plugin::Fi::Hypernova::ValueBuilder::http_response{html} =~ m!bib_class!gsm, "bib_class-subroutine rendered");
    ok($Koha::Plugin::Fi::Hypernova::ValueBuilder::http_response{html} =~ m!></textarea>!gsm, "empty builder pattern textarea rendered");
    ok($Koha::Plugin::Fi::Hypernova::ValueBuilder::http_response{html} =~ m!'<text(HELLO)><bib_class>'!gsm, "Created Builder pattern rendered");
  });

  subtest("intranet_js", sub {
    plan tests => 1;

    t::Lib::CGIreset($plugin);
    $ENV{SCRIPT_NAME} = '/cgi-bin/koha/cataloguing/additem.pl';

    my $js = $plugin->intranet_js();
    ok($js =~ m!mfw_vb_bind_valuebuilder!gsm, "mfw_vb_bind_valuebuilder rendered");
  });
});

1;