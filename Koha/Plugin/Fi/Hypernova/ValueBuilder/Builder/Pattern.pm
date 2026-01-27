package Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Pattern;

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
use overload '""' => 'TO_STRING';

use Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Subroutine;
use Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Pattern::Locals;

sub new {
  my ($class, $patternString) = @_;

  my $self = bless({}, $class);

  $self->{subroutines} = $self->_parsePattern($patternString);
  $self->{locals} = Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Pattern::Locals->new($self->locals) if $self->locals;

  return $self;
}

sub locals {
  my ($self, $locals) = @_;
  $self->{locals} = Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Pattern::Locals->new($locals) if $locals;
  return $self->{locals};
}

sub subroutines {
  return shift->{subroutines};
}

sub TO_STRING {
  my ($self) = @_;
  return $self->{patternString};
}

sub _parsePattern {
  my ($self, $patternString) = @_;

  $self->{patternString} = $patternString;

  my @subroutines = $patternString =~ /<(.+?)>/gsm;
  die "ERR_CANNOT_PARSE_PATTERN '$patternString'" unless (@subroutines);

  for (my $i=0 ; $i<@subroutines ; $i++) {
    $subroutines[$i] = Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Subroutine->newFromPattern($subroutines[$i]);
  }

  return \@subroutines;
}

sub render {
  my ($self) = @_;

  my $sb = '';
  for my $sub (@{$self->subroutines}) {
    $sb .= $sub->dispatch($self);
  }
  return $sb;
}

1;
