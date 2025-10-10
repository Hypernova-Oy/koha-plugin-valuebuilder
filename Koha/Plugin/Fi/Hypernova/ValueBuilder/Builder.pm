package Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder;

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
use strict;
use warnings;
use Carp::Always;

use YAML::XS;
$YAML::XS::LoadBlessed = 1;

use Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Pattern;

sub new {
  my ($class, $params) = @_;

  my $self = bless($params, $class);
  die __PACKAGE__." 'frameworkcode' missing!" unless (exists $self->{frameworkcode});
  die __PACKAGE__." 'fieldcode' missing!" unless (exists $self->{fieldcode});
  die __PACKAGE__." 'subfieldcode' missing!" unless (exists $self->{subfieldcode});
  die __PACKAGE__." 'pattern' missing!" unless (exists $self->{pattern});
  die __PACKAGE__." 'trigger' missing!" unless (exists $self->{trigger});
  $self->pattern($self->{pattern}) if $self->{pattern};
  return $self;
}

sub pattern {
  my ($self, $pattern) = @_;
  $self->{pattern} = Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Pattern->new($pattern) if $pattern;
  return $self->{pattern};
}

sub trigger {
  return shift->{trigger};
}

sub frameworkcode {
  return shift->{frameworkcode}
}

sub fieldcode {
  return shift->{fieldcode}
}

sub subfieldcode {
  return shift->{subfieldcode}
}

sub ParseCGIKey {
  my ($keyString) = @_;

  if ($keyString =~ m!^(?<frameworkcode>.*)->(?<fieldcode>\d\d\d)\$(?<subfieldcode>[a-z0-9@])->(?<attribute>\w+)$!) {
    return \%+;
  }
  return undef;
}
sub serialize {
  my ($self) = @_;
  return YAML::XS::Dump($self);
}
sub deserialize {
  my ($class, $yamlString) = @_;
  return YAML::XS::Load($yamlString);
}
sub serializeCGIKey {
  my ($self, $attribute) = @_;

  return $self->frameworkcode.'->'.$self->fieldcode.'$'.$self->subfieldcode.'->'.$attribute;
}

sub serializeKey {
  my ($self) = @_;

  return SerializeKey($self->frameworkcode, $self->fieldcode, $self->subfieldcode);
}

sub SerializeKey {
  my ($frameworkcode, $fieldcode, $subfieldcode) = @_;

  return "$frameworkcode->$fieldcode\$$subfieldcode";
}

sub serializeJSON {
  my ($self) = @_;

  return JSON->new->encode($self);
}

sub IsKey {
  my ($key) = @_;
  if ($key =~ m!^(?<frameworkcode>.*)->(?<fieldcode>\d\d\d)\$(?<subfieldcode>[a-z0-9@])$!) {
    return 1;
  }
  return 0;
}

1;
