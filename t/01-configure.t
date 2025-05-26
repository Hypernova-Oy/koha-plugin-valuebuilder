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
use Koha::Plugin::Fi::Hypernova::ValueBuilder::ValueBuilders;

use t::Lib;

subtest("Scenario: Simple plugin lifecycle tests.", sub {
  plan tests => 9;

  my $plugin; #Instantiating a Plugin-instance autoinstalls/upgrades it to Koha

  subtest("Make sure the plugin is uninstalled", sub {
    plan tests => 1;

    $plugin = Koha::Plugin::Fi::Hypernova::ValueBuilder->new(); #This implicitly calls install()
    $plugin->uninstall(); #So we have to install/upgrade + uninstall the plugin.
    #ok(!$plugin->retrieve_data('__INSTALLED__'), "Uninstalled");
    ok(!$plugin->retrieve_data('valuebuilders'), "'valuebuilders' is not defined");
  });

  subtest("Install the plugin", sub {
    plan tests => 1;

    $plugin->install();
    #ok($plugin->retrieve_data('__INSTALLED__'), "Installed");
    ok($plugin->retrieve_data('valuebuilders'), "'valuebuilders' is defined");
  });

  #subtest("Upgrade the plugin", sub {
  #    plan tests => 1;
  #
  #    $plugin->store_data({ '__INSTALLED_VERSION__' => '0.0.0' });
  #    $plugin = Koha::Plugin::Fi::KohaSuomi::SelfService->new(); #This implicitly calls upgrade()
  #    is($plugin->get_metadata->{version}, $plugin->retrieve_data('__INSTALLED_VERSION__'), "Upgraded");
  #});

  subtest("Fetch MARC subfield structures", sub {
    plan tests => 4;

    my $sfs = Koha::Plugin::Fi::Hypernova::ValueBuilder::Configure::GetMARCFrameworkSubfields('', '952');
    is(ref($sfs), 'ARRAY', "Got an ARRAY");
    ok(@$sfs > 10, "Looks like enough subfields");
    is($sfs->[0]->{frameworkcode}, '', "Default Framework");
    is($sfs->[0]->{tagfield}, '952', "Field 952");
  });

  subtest("Load the plugin configurer", sub {
    plan tests => 7;

    $plugin->{cgi} = FakeCGI->new(params => {});
    ok($plugin->configure(), "Loading the configure-view");
    is($Koha::Plugin::Fi::Hypernova::ValueBuilder::http_response{status}, 200, "Status '200'");
    ok($Koha::Plugin::Fi::Hypernova::ValueBuilder::http_response{html} =~ m!prefill!gsm, "prefill-trigger rendered");
    ok($Koha::Plugin::Fi::Hypernova::ValueBuilder::http_response{html} =~ m!disabled!gsm, "disabled-trigger rendered");
    ok($Koha::Plugin::Fi::Hypernova::ValueBuilder::http_response{html} =~ m!text!gsm, "text-subroutine rendered");
    ok($Koha::Plugin::Fi::Hypernova::ValueBuilder::http_response{html} =~ m!bib_class!gsm, "bib_class-subroutine rendered");
    ok($Koha::Plugin::Fi::Hypernova::ValueBuilder::http_response{html} =~ m!></textarea>!gsm, "empty builder pattern textarea rendered");
  });

  subtest("Save a Builder", sub {
    plan tests => 6;

    $plugin->{cgi} = FakeCGI->new(params => {
      frameworkcode => '',
      fieldcode => '952',
      subfieldcode => 'c',
      pattern => '<text(HELLO)><bib_class>',
      trigger => 'prefill',
    });
    ok($plugin->save_builder(), "Saving a Builder");

    my $b = Koha::Plugin::Fi::Hypernova::ValueBuilder::ValueBuilders->new($plugin)->retrieve('', '952', 'c');
    is($b->trigger, 'prefill');
    is($b->pattern->subroutines->[0]->name, 'text');
    is($b->pattern->subroutines->[0]->parameters->[0], 'HELLO');
    is($b->pattern->subroutines->[1]->name, 'bib_class');
    is($b->pattern->subroutines->[1]->parameters->[0], undef);
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

  subtest("Delete a Builder", sub {
    plan tests => 2;

    $plugin->{cgi} = FakeCGI->new(params => {
      frameworkcode => '',
      fieldcode => '952',
      subfieldcode => 'c',
    });
    ok($plugin->delete_builder(), "Deleting a Builder");

    my $b = Koha::Plugin::Fi::Hypernova::ValueBuilder::ValueBuilders->new($plugin)->retrieve('', '952', 'c');
    is($b, undef, "Builder deleted");
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
    ok(! $Koha::Plugin::Fi::Hypernova::ValueBuilder::http_response{html} =~ m!'<text(HELLO)><bib_class>'!gsm, "Created Builder pattern NOT rendered");
  });

  subtest("intranet_js", sub {
    plan tests => 1;

    my $js = $plugin->intranet_js();
    #print $js;
    ok($js =~ m!mfw_vb_bind_valuebuilder!gsm, "mfw_vb_bind_valuebuilder rendered");
  });
});

1;