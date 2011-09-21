package Txodds;

use 5.006;
use strict;
use warnings;

require HTTP::Request::Common;
require LWP::UserAgent;
require XML::LibXML::Simple;
require Carp;

our $VERSION = '0.51';
use constant DEBUG => $ENV{TXODDS_DEBUG} || 0;

sub new {
    my $class = shift;
    my $self  = {@_};

    $self->{ua} ||= LWP::UserAgent->new( agent => "TXOdds-agent/$VERSION" );
    $self->{xml} ||= XML::LibXML::Simple->new;
    bless $self, $class;
}

sub full_service_feed {
    my ( $self, @params ) = @_;
    my $url = 'http://xml2.txodds.com/feed/odds/xml.php';

    Carp::croak(
        "ident & passwd of http://txodds.com API required for this action")
      unless ( $self->{ident} && $self->{passwd} );

    my $BadObj = parse_xml(
        get( $url, $self->{ident}, $self->{passwd}, @params ),
        ForceArray => 'bookmaker'
    );
    return $BadObj;
}

sub create_get_request {
    my ( $self, $url, $params ) = @_;

    $url = URI->new($url);
    $url->query_form(@$params);

    HTTP::Request::Common::GET($url);
}

sub get {
    my $self = shift;

    my $request = $self->create_get_request(@_);

    warn "GET>\n" if DEBUG;
    warn $request->as_string if DEBUG;

    my $response = $self->{ua}->request($request);

    warn "GET<\n" if DEBUG;

    return $response->content;
}

sub parse_xml {
    my ( $self, $xml_string, %options ) = @_;

    my $obj = $self->{xml}->XMLin( $xml_string, %options );

    Carp::croak( "Wrong responce: " . $xml_string ) unless $obj;

    return $obj;
}

__END__

=pod

=head1 NAME

Txodds - TXOdds.com API Perl interface.

=head1 VERSION

Version 0.51

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Txodds;

    my $foo = Txodds->new();
    ...


=head1 SUBROUTINES/METHODS



=head1 AUTHOR

"Foxcool", C<< <""> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-txodds at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Txodds>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Txodds


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Txodds>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Txodds>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Txodds>

=item * Search CPAN

L<http://search.cpan.org/dist/Txodds/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 "Foxcool".

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
