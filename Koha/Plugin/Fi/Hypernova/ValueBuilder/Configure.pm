package Koha::Plugin::Fi::Hypernova::ValueBuilder::Configure;

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

use Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder;
use Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Subroutine;
use Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Trigger;
use Koha::Plugin::Fi::Hypernova::ValueBuilder::ValueBuilders;

#Controller
sub configure {
  my ($plugin, $args) = @_;
  my $cgi = $plugin->{'cgi'};

  my $template = $plugin->get_template( { file => _absPath($plugin, 'configure.tt') } );

  $template->param(
    available_subroutines => Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Subroutine::ListAvailable(),
    available_triggers => Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Trigger::ListAvailable(),
    item_marc_subfield_structures => GetMARCFrameworkSubfields('', '952'),
    valuebuilders => Koha::Plugin::Fi::Hypernova::ValueBuilder::ValueBuilders->new($plugin)->retrieveAll,
  );

  $plugin->output_html( $template->output(), 200 );
  return 1;
}

sub GetMARCFrameworkSubfields {
  my ($fieldcode, $subfieldcode) = @_;
  my $dbh = C4::Context->dbh();

  my $sth = $dbh->prepare("SELECT * FROM marc_subfield_structure WHERE frameworkcode = ? AND tagfield = ?");
  $sth->execute($fieldcode, $subfieldcode);
  return $sth->fetchall_arrayref({});
}

sub _absPath {
  my ($plugin, $file) = @_;

  return Cwd::abs_path($plugin->mbf_path($file));
}

1;
