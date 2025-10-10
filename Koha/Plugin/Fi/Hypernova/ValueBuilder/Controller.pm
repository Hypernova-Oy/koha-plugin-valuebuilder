package Koha::Plugin::Fi::Hypernova::ValueBuilder::Controller;

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

use Mojo::Base 'Mojolicious::Controller';

use Koha::Plugin::Fi::Hypernova::ValueBuilder;

=head1 Koha::Plugin::Fi::Hypernova::ValueBuilder::Controller

A class implementing the controller methods for the barcode generating endpoints

=cut

sub get_valuebuilder {
  my $c = shift->openapi->valid_input or return;
  my %response;
  eval {
    my $frameworkcode = $c->validation->param('frameworkcode');
    my $fieldcode = $c->validation->param('fieldcode');
    my $subfieldcode = $c->validation->param('subfieldcode');

    my $plugin = Koha::Plugin::Fi::Hypernova::ValueBuilder->new;
    my $builder = $plugin->valuebuilders->retrieve($frameworkcode, $fieldcode, $subfieldcode);
    if (not($builder)) {
      return %response = (status => 204, openapi => {error => "Builder(frameworkcode='$frameworkcode', fieldcode='$fieldcode', subfieldcode='$subfieldcode') not configured"});
    }
    if ($builder && $builder->trigger eq 'disabled') {
      return %response = (status => 204, openapi => {error => "Builder(frameworkcode='$frameworkcode', fieldcode='$fieldcode', subfieldcode='$subfieldcode') disabled"});
    }
    $builder->pattern->locals({
      biblionumber => $c->validation->param('biblionumber'),
      branchcode => $c->validation->param('branchcode'),
      currentvalue => $c->validation->param('currentvalue'),
      itemtype => $c->validation->param('itemtype'),
    });

    return %response = (status => 200, openapi => {value => $builder->pattern->render()});
  };
  if ($@) {
    return $c->render(status => 500, openapi => { error => "$@" });
  }
  return $c->render(%response);
}

sub save_builder {
  my ($plugin) = @_;
  my $cgi = $plugin->{cgi};
  eval {
    my $builder;
    my $vbs = $plugin->valuebuilders;

    if ($builder = $vbs->retrieve(scalar $cgi->param('frameworkcode'), scalar $cgi->param('fieldcode'), scalar $cgi->param('subfieldcode'))) {
      $builder->{frameworkcode} = scalar $cgi->param('frameworkcode');
      $builder->{fieldcode} = scalar $cgi->param('fieldcode');
      $builder->{subfieldcode} = scalar $cgi->param('subfieldcode');
      $builder->pattern(scalar $cgi->param('pattern'));
      $builder->{trigger} = scalar $cgi->param('trigger');
    } else {
      $builder = Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder->new({
        frameworkcode => scalar $cgi->param('frameworkcode'),
        fieldcode => scalar $cgi->param('fieldcode'),
        subfieldcode => scalar $cgi->param('subfieldcode'),
        pattern => scalar $cgi->param('pattern'),
        trigger => scalar $cgi->param('trigger'),
      });
      $vbs->add($builder);
    }
    $vbs->store();
    print $cgi->redirect('/cgi-bin/koha/plugins/run.pl?class=Koha::Plugin::Fi::Hypernova::ValueBuilder&method=configure');
  };
  if ($@) {
    warn 'Koha::Plugin::Fi::Hypernova::ValueBuilder:> '.$@;
    print $cgi->redirect('/cgi-bin/koha/plugins/run.pl?class=Koha::Plugin::Fi::Hypernova::ValueBuilder&method=configure?error='.$@);
    return 0;
  }
  return 1;
}

sub delete_builder {
  my ($plugin) = @_;
  my $cgi = $plugin->{cgi};
  eval {
    $plugin->valuebuilders->delete(scalar $cgi->param('frameworkcode'), scalar $cgi->param('fieldcode'), scalar $cgi->param('subfieldcode'));

    print $cgi->redirect('/cgi-bin/koha/plugins/run.pl?class=Koha::Plugin::Fi::Hypernova::ValueBuilder&method=configure');
  };
  if ($@) {
    warn 'Koha::Plugin::Fi::Hypernova::ValueBuilder:> '.$@;
    print $cgi->redirect('/cgi-bin/koha/plugins/run.pl?class=Koha::Plugin::Fi::Hypernova::ValueBuilder&method=configure?error='.$@);
    return 0;
  }
  return 1;
}

1;
