package Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Trigger;

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

use File::Slurp;
use FindBin;
use File::Basename;
use File::Spec;
use Pod::Simple::Text;

sub ListAvailable {
  my @triggers;
  my %documentation;
  {
    no strict 'refs';  # Disable strict refs to access the symbol table
    @triggers = map {substr($_, 2)} grep { defined &{__PACKAGE__."\::$_"} && $_ =~ /^__/ } sort keys %{__PACKAGE__."\::"}; # List all triggers in the class (methods)
  }

  my $filename = __PACKAGE__;
  $filename =~ s/::/\//g;  # Replace '::' with '/'
  $filename .= '.pm';      # Add '.pm' at the end
  my $fullPath = $INC{$filename};

  my $perldoc = Pod::Simple::Text->new();
  my $docstr = "";
  $perldoc->output_string(\$docstr);
  $perldoc->parse_file($fullPath);

  for (my $i=0 ; $i<@triggers ; $i++) {
    my $sub = $triggers[$i];
    if ($docstr =~ /^ $sub(.+?)^    END/sm) {
      $triggers[$i] = {
        name => $sub,
        documentation => $1,
      };
    }
    else {
      $triggers[$i] = {
        name => $sub,
        documentation => "Unable to parse doc for trigger '$sub'",
      };
    }
  }

  return \@triggers;
}

sub dispatch {
  my ($self, $triggerName) = @_;

  no strict 'refs';  # Disable strict refs to access the symbol table
  return &{__PACKAGE__."\::__$triggerName"}->();
}

sub renderHelperFunctions {
  my ($self) = @_;

  my $package = __PACKAGE__;
  $package =~ s/::/\//g;
  $package .= '.pm';

  my $relative_path = File::Spec->catfile(File::Basename::dirname($INC{$package}), 'GETAndReplace.js');

  # Read the contents of the file and return it as a string
  return File::Slurp::read_file($relative_path);
}

=head2 disabled

Generate nothing

END
=cut

sub __disabled {
  return '';
}

=head2 prefill

Generate the value when a new Item is being added and there is no existing value.

END
=cut

sub __prefill {
  my ($self) = @_;

  return 'JAVASCRIPT';
}

=head2 triggered

Generate the value when a trigger button/icon is pressed on the right of the input field.

END
=cut

sub __triggered {
  my ($self) = @_;

  return 'JAVASCRIPT';
}

=head2 onsave

Generate the value when the form is submitted and the field is empty.

END
=cut

sub __onsave {
  my ($self) = @_;

  return 'JAVASCRIPT';
}

1;
