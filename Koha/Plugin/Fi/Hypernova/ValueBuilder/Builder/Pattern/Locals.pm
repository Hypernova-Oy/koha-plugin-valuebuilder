package Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Pattern::Locals;

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

=head SYNOPSIS

Container for all variables specific to the object that is requesting the value to be built.

eg. an Item that is being created has a itemtype, and a related biblio, and the valuebuilder can build values based on those.

=cut

sub new {
  my ($class, $locals) = @_;

  die __PACKAGE__." 'biblionumber' missing!" unless (exists $locals->{biblionumber});
  die __PACKAGE__." 'branchcode' missing!" unless (exists $locals->{branchcode});
  die __PACKAGE__." 'currentvalue' missing!" unless (exists $locals->{currentvalue});
  die __PACKAGE__." 'itemtype' missing!" unless (exists $locals->{itemtype});

  return bless($locals, $class);
}

sub biblionumber {
  return shift->{biblionumber};
}

sub branchcode {
  return shift->{branchcode};
}

sub currentvalue {
  return shift->{currentvalue};
}

sub itemtype {
  return shift->{itemtype};
}

1;
