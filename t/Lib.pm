package t::Lib;

use strict;
use warnings;

sub CGIreset { my ($plugin) = @_;
    CGI::initialize_globals();
    $plugin->{cgi}->CLEAR() if $plugin->{cgi};
}

package Koha::Plugin::Fi::Hypernova::ValueBuilder;

our %http_response = (
    headers => [],
    html => undef,
    status => undef,
);
#Silence the HTML generation from the test case
sub output_html {
    my ( $self, $data, $status, $extra_options ) = @_;
    $http_response{html} = $data;
    $http_response{status} = $status;
    return "OK";
}

package FakeCGI;

use base 'CGI';

sub new {
    my ($class, %args) =  @_;

    my $self = $class->SUPER::new();

    if (%args && $args{params}) {
        my $cgi_tosplit = "";
        for my $k (keys %{$args{params}}) {
            $cgi_tosplit .= '&' if $cgi_tosplit;
            $cgi_tosplit .= $k.'='.$args{params}{$k};
        }
        $self->parse_params($cgi_tosplit);
    }

    return bless($self, $class);
}
sub cookie {
    return {};
}
sub redirect {
    my ($self, @args) = @_;
    my $redirect = $self->SUPER::redirect(@args);
    push(@{$http_response{headers}}, $redirect);
    return '';
}
sub request_method {
    return "GET";
}
sub header {
    return "";
}

1;
