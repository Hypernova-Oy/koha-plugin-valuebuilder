package Koha::Plugin::Fi::Hypernova::ValueBuilder::ValueBuilders;

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

=head2 SYNOPSIS

Data structure to store all the Builders

=cut

our $plugin;

sub new {
  my ($class, $plugin_) = @_;
  my $self = bless({}, $class);
  die "$class->new($plugin_):> Unable to instantiate without a plugin reference." unless $plugin || $plugin_;
  $plugin = $plugin_ if $plugin_;
  return $self;
}

sub add {
  my ($self, $builderParams) = @_;

  my $builder = (ref($builderParams) =~ /Builder$/) ? $builderParams : Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder->new($builderParams);

  $self->{$builder->{frameworkcode}} = {} unless $self->{$builder->{frameworkcode}};
  $self->{$builder->{frameworkcode}}->{$builder->{fieldcode}} = {} unless $self->{$builder->{frameworkcode}}->{$builder->{fieldcode}};
  $self->{$builder->{frameworkcode}}->{$builder->{fieldcode}}->{$builder->{subfieldcode}} = $builder;
  return $builder;
}

sub get {
  my ($self, $frameworkcode, $fieldcode, $subfieldcode) = @_;
  if ($self->{$frameworkcode} && $self->{$frameworkcode}->{$fieldcode} && $self->{$frameworkcode}->{$fieldcode}->{$subfieldcode}) {
    return $self->{$frameworkcode}->{$fieldcode}->{$subfieldcode};
  }
  else {
    return undef;
  }
}

sub store {
  my ($self) = @_;

  for my $frameworkcode (keys %$self) {
    for my $fieldcode (keys %{$self->{$frameworkcode}}) {
      for my $subfieldcode (keys %{$self->{$frameworkcode}{$fieldcode}}) {
        my $b = $self->{$frameworkcode}{$fieldcode}{$subfieldcode};
        $plugin->store_data({$b->serializeKey => $b->serialize});
      }
    }
  }
  return $self;
}

sub retrieve {
  my ($self, $frameworkcode, $fieldcode, $subfieldcode) = @_;

  my $serialized = $plugin->retrieve_data(Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::SerializeKey($frameworkcode, $fieldcode, $subfieldcode));
  return undef unless $serialized;
  my $builder = Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder->deserialize($serialized);
  $self->add($builder);
  return $builder;
}

sub delete {
  my ($self, $frameworkcode, $fieldcode, $subfieldcode) = @_;

  if ($self->{$frameworkcode} && $self->{$frameworkcode}->{$fieldcode} && $self->{$frameworkcode}->{$fieldcode}->{$subfieldcode}) {
    delete $self->{$frameworkcode}->{$fieldcode}->{$subfieldcode};
  }
  $plugin->store_data({Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::SerializeKey($frameworkcode, $fieldcode, $subfieldcode) => undef});

  return $self;
}

sub retrieveAll {
  my ($self, $kohaPage) = @_;

  my $dbh = C4::Context->dbh;
  my $sql = "SELECT plugin_key, plugin_value FROM plugin_data WHERE plugin_class = ?";
  $sql .= " AND plugin_key LIKE '\%->952\$\%'" if ($kohaPage eq 'additem.pl'); # Show only Item subfields for item editing views.
  $sql .= " AND plugin_key NOT LIKE '\%->952\$\%'" if ($kohaPage eq 'addbiblio.pl'); # Show only Item subfields for item editing views.
  my $sth = $dbh->prepare($sql);
  $sth->execute($plugin->{class});
  my $rows = $sth->fetchall_arrayref({});
  return undef unless $rows;

  for my $r (@$rows) {
    if (Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::IsKey($r->{plugin_key})) {
      if ($r->{plugin_value}) {
        $self->add(
          Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder->deserialize($r->{plugin_value})
        );
      }
    }
  }

  return $self;
}

sub list {
  my ($self) = @_;

  my @list;
  for my $frameworkcode (keys %$self) {
    for my $fieldcode (keys %{$self->{$frameworkcode}}) {
      for my $subfieldcode (keys %{$self->{$frameworkcode}{$fieldcode}}) {
        push @list, $self->{$frameworkcode}{$fieldcode}{$subfieldcode};
      }
    }
  }
  return \@list;
}

1;
