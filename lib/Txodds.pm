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
    my ( $self, %params ) = @_;
    my $content = $self->get('http://xml2.txodds.com/feed/mgroups.php', \%params);
    my $data =
      $self->parse_xml( $content, ValueAttr => [ 'mgroup', 'sportid' ] );
    my %mgroups;
    foreach (@$data) {
        $mgroups{ $_->{name} } = $_->{sportid};
    }
    return %mgroups;
}

sub xml_schema {
    my $self = shift;
    my $content = $self->get('http://xml2.txodds.com/feed/odds/odds.xsd');
    return $content;
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

Working with http://txodds.com API.

    my $tx = Txodds->new(
        ident  => 'ident',
        passwd => 'password'
    );
    ...


=head1 SUBROUTINES/METHODS

=head2 full_service_feed
The Full Service Feed provides the same request options as the standard feed but supports the 
following additional options.    

Usage:    
    my $obj = $tx->full_service_feed();
    or
    my $obj = $tx->full_service_feed(%params);
    
%params is a HASH with API request options:
    
=head3 Date search

The required date range to search
Usage: %options = (
           date => 'StartDate,EndDate'
       );
Example:
    ...
    date => '2007-06-01,2007-06-30',
    ...
The date parameter accepts also the following values:
    yesterday - Yesterdays results;
    today     - Todays results;
    tomorrow  - Tomorrows results;
    now       - Current time + 24 hours;
    next xxx  - Specific day i.e. where xxx is day e.g. Tuesday, Wednesday, etc.
Note: You can also do date arithmetic using the following operators: -+ day / month / year
Examples:
    date => 'today',
    date => 'today,tomorrow +1 day',
    date => 'now + 1 day',
    date => 'next saturday',
    date => '2009-3-24'

=head3 Day search

A simpler way to search uses the days option
Usage: %options = (
           days => number
       );
       
Use the &days= feature to separate full odds loads easily (and therefore cutting down on file sizes).
The xml days-parameter simplifies data loading. It now accepts the following format:
    ...
    days => 'n,r',
    ...
where: n is the starting day relative to the current date and r is range (in days) so for example.
If the r parameter is not specified it works like before.
Example:
    days => '0,1', # To return all of today’s odds
    days => '0,2', # To return odds for the next 2 days
    days => '1,1'  # To return tomorrow's odds
    days => '0,-1' # To return yesterday's odds
    days => '1'    # Today
    days => '3'    # Next 3 days
    days => '-1'   # Yesterday
    days => '-3'   # Last 3 days

=head3 Hours Search

Hours parameter - now you can request any upcoming info within an hour range.
To get all matches/odds for any given time range by using the date parameter. For example this
returns all soccer fixtures for the next 24 hours:

Example:
    ...
    date => 'now,now+24hour',
    ...
        
=head3 Fixtures & results

To choose between fixtures or final results you can use the result option
    
Usage: 
    %options = (
           result => code
    );
Codes:
    0 - FIXTURE (To request FIXTURES only);
    1 - RESULT (To request RESULTS only).
Example: 
    %options = (
         result => 0
     );

=head3 Response

full_service_feed function return a HASH object with data about matches, odds etc.
    
    {
        'timestamp' => '1316685278',
        'time' => '2011-09-22T09:54:38+00:00',
        'match' => {
            '1576137' => {
                'xsid' => '0',
                'bookmaker' => {
                    'BETDAQ' => {
                        'bid' => '109',
                        'offer' => {
                            '77732329' => {
                                'n' => '1',
                                'last_updated' => '2011-09-22T06:19:06+00:00',
                                'flags' => '0',
                                'ot' => '0',
                                'bmoid' => '2309781',
                                'odds' => [
                                    {
                                        'o2' => '0',
                                        'o1' => '0',
                                        'starting_time' => '2011-09-20T11:00:00+00:00',
                                        'time' => '2011-09-20T22:52:17+00:00',
                                        'o3' => '0',
                                        'i' => '0'
                                    }

                                    ...

                                ]
                            }

                            ...

                        }

                        ...

                    }
                },
                'group' => {
                    '8932' => {
                        'content' => 'GOLF Austrian Golf Open-11'
                    }
                },
                'hteam' => {
                    '25541' => {
                        'content' => 'Forsyth, Alastair'
                    }
                },
                'time' => '2011-09-22T06:20:00+00:00',
                'ateam' => {
                    '25949' => {
                        'content' => 'Drysdale, David'
                    }
                },
                'results' => '',
            }

            ...

        }
    }

=head3 Full Service Feed XML document structure

The Full Service Feed XML document is an extension of the Standard Feed to provide the additional
information for fixtures, live scoring and final results information so please refer to the Standard XML
Feed description for the base structure details. In this section we will just document the additional
elements in the feed.
    
The XML document is made up of the following ten elements:

    • XML Declaration
    • Matches Container
    • Match Element
        o Bookmaker Element
        o Offer Element
        o Odds Element
        o Results Element
        o Result Element
        o Periods Element
        o Scorer Element
        
=head3 Odds XML Schema Definition (XSD)

Please see xml_schema function description

=head2 xml_schema

An XML Schema definition is available that describes the Odds XML. This can be used by various
development tools to simplify code generation/testing/feed parsing.
Usage:
    my $schema = $tx->xml_schema();
Response:    
    This function returns XML Schema from http://xml2.txodds.com/feed/odds/odds.xsd.

=head2 sports

This service provides a complete list of sports used within the feeds.
Usage:
    my %sports = $tx->sports();
Response:
    {
        sportid => 'sport name',
        ...
    }

=head2 mgroups
    
This function request all master groups from http://xml2.txodds.com/feed/mgroups.php.
 
Usage:   
    my %mgroups = $tx->mgroups();
Response:
    {
        name => 'sportid',
        ...
    }   
Options:
    active - (boolean) request only active master groups;
    spid - select by spid (sport identifier).
Example:
    my %mgroups = $tx->mgroups(
        active => 1,
        spid   => 1
    );
    # select only soccer active groups

=head2 get

Send GET request and return response content.

Usage:
    my $data = $tx->get($url, \%params);
%params contain GET parameters:
    my $url = 'http://www.vasya.com/index.html'
    my %params = (
        user => 'vasya',
        pass => 'paswd',
        data => 'sometxt'
    );
    my $data = $tx->get( $url, \%params );
    # GET http://www.vasya.com/index.html?user=vasya&pass=passwd&data=sometxt

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
