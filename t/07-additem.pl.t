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
use Carp::Always;

use Test::More tests => 1;
use Test::Deep;
use Test::Mojo;

use Koha::Plugin::Fi::Hypernova::ValueBuilder;

use t::Lib;


$ENV{REQUEST_METHOD} = 'GET';
$ENV{REMOTE_ADDR} = '127.0.0.1';

subtest("Scenario: Injecting javascript to various pages.", sub {
  plan tests => 2;

  my $plugin = Koha::Plugin::Fi::Hypernova::ValueBuilder->new();

  subtest("additem.pl", sub {
    plan tests => 3;

    t::Lib::CGIreset($plugin);
    $ENV{SCRIPT_NAME} = '/cgi-bin/koha/cataloguing/additem.pl';

    my $js = $plugin->intranet_js();
    ok($js, 'javascript injected');
    ok($js =~ /mfw_vb_bind_valuebuilder/, 'javacsript looks sane');
    ok($js =~ /mfw_vb_kohaPage = 'additem\.pl'/, 'we are on the right page')
  });

  subtest("addbiblio.pl", sub {
    plan tests => 3;

    t::Lib::CGIreset($plugin);
    $ENV{SCRIPT_NAME} = '/cgi-bin/koha/cataloguing/addbiblio.pl';

    my $js = $plugin->intranet_js();
    ok($js, 'javascript injected');
    ok($js =~ /mfw_vb_bind_valuebuilder/, 'javacsript looks sane');
    ok($js =~ /mfw_vb_kohaPage = 'addbiblio\.pl'/, 'we are on the right page')
  });
});

1;