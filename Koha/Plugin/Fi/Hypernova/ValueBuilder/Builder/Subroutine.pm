package Koha::Plugin::Fi::Hypernova::ValueBuilder::Builder::Subroutine;

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
use Date::Manip::Date;
use DateTime::Format::Strptime;
use Pod::Simple::Text;

use C4::Context;
use Koha::Biblios;

sub new {
  my ($class, $params) = @_;

  my $self = bless($params, $class);
  die __PACKAGE__." 'name' missing!" unless (exists $params->{name});
  die __PACKAGE__." 'documentation' missing!" unless (exists $params->{documentation});
  die __PACKAGE__." 'parameters' missing!" unless (exists $params->{parameters});
  return $self;
}

sub newFromPattern {
  my ($class, $patternString) = @_;

  die "Unable to parse subroutine pattern '$patternString'" unless $patternString =~ /^(?<name>\w+)(?:\((?<parameters>.+?)\))?$/;

  my %params = %+;
  $params{parameters} = [split(',', $params{parameters} || '')];
  $params{documentation} = '';
  return $class->new(\%params);
}

sub name {
  return shift->{name};
}

sub documentation {
  return shift->{documentation};
}

sub parameters {
  return shift->{parameters};
}

sub dispatch {
  my ($self, $pattern) = @_;

  my $subroutine = '__'.$self->{name};
  return $self->$subroutine($pattern, @{$self->{parameters}});
}

sub ListAvailable {
  my @subroutines;
  my %subsAndDocs;
  my %documentation;
  {
    no strict 'refs';  # Disable strict refs to access the symbol table
    @subroutines = map {substr($_, 2)} grep { defined &{__PACKAGE__."\::$_"} && $_ =~ /^__/ } sort keys %{__PACKAGE__."\::"}; # List all subroutines in the class (methods)
  }

  my $filename = __PACKAGE__;
  $filename =~ s/::/\//g;  # Replace '::' with '/'
  $filename .= '.pm';      # Add '.pm' at the end
  my $fullPath = $INC{$filename};

  my $perldoc = Pod::Simple::Text->new();
  my $docstr = "";
  $perldoc->output_string(\$docstr);
  $perldoc->parse_file($fullPath);

  for (my $i=0 ; $i<@subroutines ; $i++) {
    my $sub = $subroutines[$i];
    if ($docstr =~ /^ $sub(.+?)^    END/sm) {
      $subroutines[$i] = __PACKAGE__->new({
        name => $sub,
        documentation => $1,
        parameters => [],
      });
    }
    else {
      $subroutines[$i] = __PACKAGE__->new({
        name => $sub,
        documentation => "Unable to parse doc for subroutine '$sub'",
        parameters => [],
      });
    }
  }

  return \@subroutines;
}

=head2 bib_class

Gets the classification from the bibliographic record's class fields 08X.
Fetches all instances of the various classes.

@PARAM1 String, Field filter. eg. '084', to access only field 084 instances.

@PARAM2 Char, subfield filter. Include only these subfields. eg. 'a'

END
=cut

sub __bib_class {
  my ($self, $pattern, $fieldFilter, $subfieldFilter) = @_;
  $fieldFilter = '08.' unless $fieldFilter;
  $subfieldFilter = '.' unless $subfieldFilter;

  my $biblionumber = $pattern->locals->biblionumber;
  my $biblio = Koha::Biblios->find($biblionumber);
  die "ERR_CANNOT_FIND_BIBLIO '$biblionumber'" unless $biblio;
  my $r = $biblio->record;

  my @sb;

  my @fs = $r->field($fieldFilter);
  for my $f (@fs) {
    if ($subfieldFilter =~ m/^[.*]$/) {
      push @sb, map {$_->[1]} $f->subfields;
    }
    elsif ($subfieldFilter !~ m/^.$/) {
      die "ValueBuilder 'bib_class' subfield filter '$subfieldFilter' is malformed!";
    }
    else {
      my $subfield = $f->subfield($subfieldFilter);
      push @sb, $subfield if $subfield;
    }
  }

  return join(" ", @sb);
}

=head2 f008_infer

Populate controlfield 008 from other MARC21-fields, such as:
- 00-05 date entered on file is created if it is '000000' or '||||||' or '      '
- language from 041$a
- publication country from 044$a
- dates from 260$c, 264$c, 362$a

Requires the MARC21-field to be populated for example from a MARC Framework default

=cut

sub __f008_infer {
  my ($self, $pattern) = @_;

  my ($value, $biblionumber) = ($pattern->locals->currentvalue, $pattern->locals->biblionumber);
  return undef unless $value;

  my $biblio = Koha::Biblios->find($biblionumber);
  my $record = $biblio->record if $biblio;

  my %cps;
  if ($value =~ /^(?<dateonfile>......)(?<typeofdate>.)(?<date1>....)(?<date2>....)(?<placeofpub>...)(?<p1>.................)(?<lang>...)(?<p2>..)$/) {
    %cps = %+;
    if ($cps{dateonfile} =~ /^[0 |#]{6}$/) {
      $cps{dateonfile} = DateTime->now(time_zone => C4::Context->tz)->strftime('%y%m%d');
    }    
    ($cps{typeofdate}, $cps{date1}, $cps{date2}) = $self->_getDatesFromFields($record, $cps{typeofdate}, $cps{date1}, $cps{date2});
    if ($cps{placeofpub} =~ /^[ |#]{3}$/ && $record && $record->subfield('044', 'a')) {
      $cps{placeofpub} = $record->subfield('044', 'a');
      while (length($cps{placeofpub}) < 3) {
        $cps{placeofpub} .= '#';
      }
    }
    if ($cps{lang} =~ /^[ |#]{3}$/ && $record && $record->subfield('041', 'a')) {
      $cps{lang} = $record->subfield('041', 'a');
      while (length($cps{lang}) < 3) {
        $cps{lang} .= '#';
      }
    }
  }
  else {
    return "f008_infer:> Unable to parse value '$value'";
  }

  return $cps{dateonfile}.$cps{typeofdate}.$cps{date1}.$cps{date2}.$cps{placeofpub}.$cps{p1}.$cps{lang}.$cps{p2};
}

sub _getDatesFromFields {
  my ($self, $record, $typeofdate, $date1, $date2) = @_;

  return ('|', '####', '####') unless $record;

  sub _gDFFdateParse {
    my ($datestr, $recursing) = @_;
    my ($typeofdate, $date1, $date2) = ('|', undef, undef);

    return ($typeofdate, $date1, $date2) unless defined $datestr;

    $datestr =~ s/^\s+|\s+$//g; # trim()
    $datestr =~ s/\.$//g; # remove trailing .
    eval {
      # yyyy
      return unless $datestr =~ /^[0-9]{1,4}$/;
      $date1 = $datestr;
    };
    return ($typeofdate, $date1, $date2) if $date1;
    eval {
      # yyyy-yyyy OR yyyy,yyyyy
      my %_cps;
      if ($datestr =~ /^(?<date1>[0-9]{1,4})[-,](?<date2>[0-9]{1,4})$/) {
        %_cps = %+;
        $date1 = $_cps{date1};
        $date2 = $_cps{date2};    
      }
    };
    return ($typeofdate, $date1, $date2) if $date1;
    eval {
      # yyyy-
      my %_cps;
      if ($datestr =~ /^(?<date1>[0-9]{1,4})-$/) {
        %_cps = %+;
        $date1 = $_cps{date1};
        $date2 = 9999;
        $typeofdate = 'c';
      }
    };
    return ($typeofdate, $date1, $date2) if $date1;
    eval {
      # dd.mm.YYYY
      if ($datestr =~ /\d\d?\.\d\d?\.\d\d\d\d?/) {
        my $strp = DateTime::Format::Strptime->new(pattern => '%d.%m.%Y');
        my $dt = $strp->parse_datetime($datestr);
        $date1 = sprintf("%04d", $dt->year);
        $date2 = sprintf("%02d", $dt->month) . sprintf("%02d", $dt->day);
        $typeofdate = 'e';
      }
    };
    return ($typeofdate, $date1, $date2) if $date1;
    eval {
      # Date::Manip::Date to parse many (but not any) formats
      my $date_manip = new Date::Manip::Date;
      $date_manip->config("Format_MMMYYYY", "first");
      $date_manip->set('zone', '+0000');
      $date_manip->set('time', "00:00:00");
      my $err = $date_manip->parse($datestr);
      my ($year, $month, $day) = ('####', '##', '##');
      unless ($err) {
        $year = $date_manip->printf("%Y");
        $month = $date_manip->printf("%m");
        $day = $date_manip->printf("%d");
      } else {
        return;
      }

      my $parsed_date = "$year$month$day";

      return unless $parsed_date;
      if ($parsed_date =~ /^[0-9]{8}$/) {
        # we have an absolute date
        $date2 = substr $parsed_date, 4, 4;
        $date1 = substr $parsed_date, 0, 4;
        $typeofdate = 'e';
      } elsif ($parsed_date =~ /^[0-9]{6}u*$/) {
        $date1 = substr $parsed_date, 0, 4;
        $date2 = (substr $parsed_date, 4, 2) . "uu";
        $typeofdate = 'e';
      } elsif ($parsed_date =~ /^[0-9]{4}u*$/) {
        $date1 = substr $parsed_date, 0, 4;
      }
    };
    return ($typeofdate, $date1, $date2) if $date1;
    # field contains something else, try less strict matching
    $datestr =~ s/[^0-9,\- ]+//g;
    ($typeofdate, $date1, $date2) = _gDFFdateParse($datestr, 1) unless $recursing;
    return ($typeofdate, $date1, $date2);
  }

  sub _formatYear {
    my $datestr = shift;
    return '####' unless $datestr;

    return $datestr if length($datestr) == 4;

    if ($datestr && $datestr < 1000 && $datestr > 0) {
      while ($datestr && length($datestr) < 4) {
        $datestr = '0' . $datestr; # leading 0 if year < 1000
      }
    }

    return $datestr;
  }

  foreach my $field (['260', 'c'], ['264', 'c'], ['362', 'a']) {
    if ($date1 && $date1 =~ /^[ u\|#]{4}$/ && $record->subfield($field->[0], $field->[1])) {
      my $f260c = $record->subfield($field->[0], $field->[1]);
      ($typeofdate, $date1, undef) = _gDFFdateParse($f260c);
    }
    if ($date2 && $date2 =~ /^[ u\|#]{4}$/ && $record->subfield($field->[0], $field->[1])) {
      my $f260c = $record->subfield($field->[0], $field->[1]);
      ($typeofdate, undef, $date2) = _gDFFdateParse($f260c);
    }
  }

  $date1 = _formatYear($date1);
  $date2 = _formatYear($date2);
  return ($typeofdate, $date1, $date2);
}

=head2 incremental_pattern_barcode

Generate an incremental barcode from a pattern.
Fetches the latest available id from the items.barcode -columns.

@PARAM1 String, the barcode pattern.

      eg. PREFIX00000000SUFFIX or PRE000000 or A00000B

Use YEAR to generate current year

      eg. YEARv000 => 2025v001

END
=cut

sub __incremental_pattern_barcode {
  my ($self, $pattern, $barcodePattern) = @_;

  sub replaceYear {
    if ($_[0] && $_[0] =~ m/YEAR/) {
      my $str = $_[0];
      my $year = DateTime->now(time_zone => C4::Context->tz)->year();
      $str =~ s/YEAR/$year/g;
      return $str;
    }
    return $_[0];
  }

  my $barcode = $barcodePattern;

  die "ERR_CANNOT_PARSE_PATTERN '$barcodePattern'" unless ($barcodePattern =~ /^(?<prefix>[^0]*)(?<numbers>0+)(?<suffix>[^0]*)/);

  $barcodePattern = {
    prefix => $+{prefix} // '',
    numberLength => length($+{numbers}) // 0,
    suffix => $+{suffix} // '',
  };

  my $id = 0;
  my $dbh = C4::Context->dbh;

  my $prefix = replaceYear($barcodePattern->{prefix});
  my $suffix = replaceYear($barcodePattern->{suffix});
  my $prefixLength = length($prefix);
  my $suffixLength = length($suffix);
  my $substrLength = (length($barcode)-$prefixLength-$suffixLength);
  my $sth = $dbh->prepare("SELECT MAX(CAST(SUBSTRING(barcode,($prefixLength+1),$substrLength) AS signed)) AS number FROM items WHERE barcode REGEXP ?");
  $sth->execute("^".$prefix."(\\d{".$barcodePattern->{numberLength}."})".$suffix.'$');
  while (my ($count)= $sth->fetchrow_array) {
    $id = $count if $count;
  }

  $id++;
  my $zeroesNeeded = $barcodePattern->{numberLength} - length($id);
  $barcode = $prefix . substr('00000000000000000000', 0, $zeroesNeeded) . $id . $suffix;

  return $barcode;
}

=head2 signum

Generates the signum from the main author or title.

END
=cut

sub __signum {
  my ($self, $pattern) = @_;
  my $biblionumber = $pattern->locals->biblionumber;
  my $biblio = Koha::Biblios->find($biblionumber);
  die "ERR_CANNOT_FIND_BIBLIO '$biblionumber'" unless $biblio;
  my $record = $biblio->record;

  #Get the proper SIGNUM (important) Use one of the Main Entries or the Title Statement
  my $leader = $record->leader(); #If this is a video, we calculate the signum differently, 06 = 'g'
  my $signumSource; #One of fields 100, 110, 111, 130, or 245 if 1XX is missing
  my $nonFillingCharacters = 0;

  if ($signumSource = $record->subfield('100', 'a')) {

  }
  elsif ($signumSource = $record->subfield('110', 'a')) {

  }
  elsif ($signumSource = $record->subfield('111', 'a')) {

  }
  elsif (substr($leader,6,1) eq 'g' && ($signumSource = $record->subfield('245', 'a'))) {
    $nonFillingCharacters = $record->field('245')->indicator(2);
  }
  elsif ($signumSource = $record->subfield('130', 'a')) {
    $nonFillingCharacters = $record->field('130')->indicator(1);
    $nonFillingCharacters = 0 if (not(defined($nonFillingCharacters)) || $nonFillingCharacters eq ' ');
  }
  elsif ($signumSource = $record->subfield('245', 'a')) {
    $nonFillingCharacters = $record->field('245')->indicator(2);
  }
  if ($signumSource) {
    return uc(substr($signumSource, $nonFillingCharacters, 3));
  }

  return '';
}

=head2 text

Generate a predefined text

@PARAM1 String, the text to show.

END
=cut

sub __text {
  my ($self, $pattern, $text) = @_;

  return $text;
}

1;
