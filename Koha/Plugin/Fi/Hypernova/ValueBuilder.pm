package Koha::Plugin::Fi::Hypernova::ValueBuilder;

# Copyright 2025 Hypernova Oy
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# This program comes with ABSOLUTELY NO WARRANTY;

use Modern::Perl;

use base qw(Koha::Plugins::Base);

use Cwd;
use Mojo::JSON qw(decode_json);
use YAML;
use Try::Tiny;

use Koha::Plugin::Fi::Hypernova::ValueBuilder::Configure;
use Koha::Plugin::Fi::Hypernova::ValueBuilder::Controller;
use Koha::Plugin::Fi::Hypernova::ValueBuilder::ValueBuilders;
use Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Trigger;

our $VERSION = "0.0.1"; #PLACEHOLDER
our $DATE_UPDATED = "2025-05-26"; #PLACEHOLDER

our $metadata = {
  name            => 'ValueBuilder',
  author          => 'Olli-Antti Kivilahti',
  date_authored   => '2025-05-26',
  date_updated    => $DATE_UPDATED,
  minimum_version => '24.11.01.000',
  maximum_version => undef,
  version         => $VERSION,
  description     => 'Configure common interface valuebuilders.',
};

sub new {
  my ( $class, $args ) = @_;

  ## We need to add our metadata here so our base class can access it
  $args->{'metadata'} = $metadata;
  $args->{'metadata'}->{'class'} = $class;

  ## Here, we call the 'new' method for our base class
  ## This runs some additional magic and checking
  ## and returns our actual $self
  my $self = $class->SUPER::new($args);
  $self->{cgi} = CGI->new();

  return $self;
}

sub valuebuilders {
  my ($plugin) = @_;

  $plugin->{valuebuilders} = Koha::Plugin::Fi::Hypernova::ValueBuilder::ValueBuilders->new($plugin) unless $plugin->{valuebuilders};
  return $plugin->{valuebuilders};
}

sub intranet_js {
  my ($self) = @_;
  my $cgi = $self->{'cgi'};
  return unless ($cgi->script_name =~ /additem\.pl/);

  my $vbs = $self->valuebuilders->retrieveAll->list;
  return '' unless $vbs && @$vbs;

  return
  "  <script>\n" .
  "  if (document.getElementById('cataloguing_additem_newitem')) {\n" .
  "    document.addEventListener('DOMContentLoaded', function () {\n" .
          Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Trigger::renderHelperFunctions() . "\n" .
          join("\n", map { "mfw_vb_bind_valuebuilder('" . $_->frameworkcode . "','" . $_->fieldcode . "','" . $_->subfieldcode . "','" . $_->trigger . "');" } @$vbs) . "\n" .
  "    });\n" .
  "  }\n" .
  "  </script>\n";
}

sub api_routes {
  my ( $self, $args ) = @_;

  my $spec_str = $self->mbf_read('openapi.json');
  my $spec     = decode_json($spec_str);

  return $spec;
}

sub api_namespace {
  my ( $self ) = @_;

  return 'hypernova';
}

sub configure { return Koha::Plugin::Fi::Hypernova::ValueBuilder::Configure::configure(@_); }
sub delete_builder { return Koha::Plugin::Fi::Hypernova::ValueBuilder::Controller::delete_builder(@_); };
sub save_builder { return Koha::Plugin::Fi::Hypernova::ValueBuilder::Controller::save_builder(@_); }

sub install {
  my ( $self, $args ) = @_;

  eval {
    $self->valuebuilders->add(Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder->new({
      frameworkcode => '',
      fieldcode => '952',
      subfieldcode => 'o',
      pattern => '<bib_class(084,a)><text( )><signum>',
      trigger => 'prefill',
    }));
    $self->valuebuilders->add(Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder->new({
      frameworkcode => '',
      fieldcode => '952',
      subfieldcode => 'p',
      pattern => '<incremental_pattern_barcode(PRE000000SUF)>',
      trigger => 'onsave',
    }));
    $self->valuebuilders->store();
  };
  if ($@) {
    warn $@;
    return 0;
  }
  return 1;
}

sub uninstall {
  my ( $self, $args ) = @_;

  eval {
    $self->store_data( { valuebuilders => undef } );
  };
  if ($@) {
    warn $@;
    return 0;
  }
  return 1;
}

1;
