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
    my ( $self, %params ) = @_;
    my $url = 'http://xml2.txodds.com/feed/odds/xml.php';

    Carp::croak(
        "ident & passwd of http://txodds.com API required for this action")
      unless ( $self->{ident} && $self->{passwd} );

    %params = (
        ident  => $self->{ident},
        passwd => $self->{passwd}
    );

    return $self->parse_xml( $self->get( $url, \%params ), ForceArray => 'bookmaker' );
}

sub sports {
    my $self    = shift;
    my $content = $self->get('http://xml2.txodds.com/feed/sports.php');
    my $data = $self->parse_xml( $content, ValueAttr => [ 'sport', 'name' ] );

    my %sports;
    foreach (@$data) {
        $sports{ $_->{id} } = $_->{name};
    }
    return %sports;
}

sub mgroups {
    my $self    = shift;
    my $content = $self->get('http://xml2.txodds.com/feed/mgroups.php');
    my $data =
      $self->parse_xml( $content, ValueAttr => [ 'mgroup', 'sportid' ] );
    my %mgroups;
    foreach (@$data) {
        $mgroups{ $_->{name} } = $_->{sportid};
    }
    return %mgroups;
}

sub create_get_request {
    my ( $self, $url, $params ) = @_;

    $url = URI->new($url);
    $url->query_form(%$params);

    HTTP::Request::Common::GET($url);
}

sub get {
    my $self = shift;

    my $request = $self->create_get_request(@_);

    warn "GET>\n" if DEBUG;
    warn $request->as_string if DEBUG;

    my $response = $self->{ua}->request($request);

    warn "GET<\n" if DEBUG;

    return $response->decoded_content;
}

sub parse_xml {
    my ( $self, $xml_string, %options ) = @_;

    my $obj = $self->{xml}->XMLin( $xml_string, %options );

    Carp::croak( "Wrong responce: " . $xml_string ) unless $obj;

    return $obj;
}

sub clean_xml {
    my ( $self, $BadObj ) = @_;
    my %sports  = $self->sports();
    my %mgroups = $self->mgroups();

    my $obj->{'timestamp'} = $BadObj->{'timestamp'};
    $obj->{time} = $BadObj->{'time'};
    $obj->{'time'} =~ s/(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):\d{2}\+\d{2}:\d{2}/$4:$5 $3-$2-$1/;
    while ( my ( $MatchId, $MatchObj ) = each %{ $BadObj->{match} } ) {
        my $Home = $MatchObj->{hteam}->{ each %{ $MatchObj->{hteam} } }->{content};
        my $Away = $MatchObj->{ateam}->{ each %{ $MatchObj->{ateam} } }->{content};
        my $Group =$MatchObj->{group}->{ each %{ $MatchObj->{group} } }->{content};
        my $MatchTime = $MatchObj->{'time'};
        $MatchTime =~ s/(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):\d{2}\+\d{2}:\d{2}/$4:$5 $3-$2-$1/;
        my $Sport = $sports{ $mgroups{$1} } if $Group =~ m/^([A-Z]+).*/;
        $Group =~ s/^[A-Z]+ (.*)/$1/;

        %{ $obj->{match}->{$Sport}->{$Group}->{"$Home - $Away"} } = (
            MatchTime => $MatchTime,
            Home      => $Home,
            Away      => $Away
        );

        while ( my ( $BookmakerName, $BookmakerObj ) = each %{ $MatchObj->{bookmaker} } ) {
            while ( my ( $OfferId, $OfferObj ) =  each %{ $BookmakerObj->{offer} } ) {
                my $ot = $OfferObj->{ot};
                if ( $ot == 0 && ($OfferObj->{odds}->[0]->{o1} || $OfferObj->{odds}->[0]->{o2} || $OfferObj->{odds}->[0]->{o3})) {
                    %{ $obj->{match}->{$Sport}->{$Group}->{"$Home - $Away"}->{bookmaker}
                          ->{$BookmakerName}->{offer}->{$ot} } = (
                        1 => $OfferObj->{odds}->[0]->{o1},
                        x => $OfferObj->{odds}->[0]->{o2},
                        2 => $OfferObj->{odds}->[0]->{o3}
                          );
                }
            }
        }
    }
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

"Alexander Foxcool Babenko", C<< <"foxcool@cpan.org"> >>

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
