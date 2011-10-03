package Txodds;

use 5.006;
use strict;
use warnings;

require HTTP::Request::Common;
require LWP::UserAgent;
require XML::LibXML::Simple;
require Carp;

our $VERSION = '0.64';
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

    return $self->parse_xml( $self->get( $url, \%params ),
        ForceArray => 'bookmaker' );
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
    my $content =
      $self->get( 'http://xml2.txodds.com/feed/mgroups.php', \%params );
    my $data =
      $self->parse_xml( $content, ValueAttr => [ 'mgroup', 'sportid' ] );
    my %mgroups;
    foreach (@$data) {
        $mgroups{ $_->{name} } = $_->{sportid};
    }
    return %mgroups;
}

sub odds_types {
    my $self    = shift;
    my $content = $self->get('http://xml2.txodds.com/feed/odds_types.php');
    my $data    = $self->parse_xml( $content, ValueAttr => ['type'] );
    unless (@_) {
        my %obj;
        foreach (@$data) {
            $obj{ $_->{ot} } = $_->{name};
        }
        return \%obj;
    }
    else { return $data; }
}

sub offer_amounts {
    my ( $self, %params ) = @_;
    my $content =
      $self->get( 'http://xml2.txodds.com/feed/offer_amounts.php', \%params );
    my $data = $self->parse_xml( $content, ValueAttr => ['offer'] );
    my %obj;
    if ( ref $data eq 'ARRAY' ) {
        foreach (@$data) { $obj{ $_->{boid} } = $_->{amount}; }
    }
    elsif ( ref $data eq 'HASH' ) {
        $obj{ $$data{boid} } = $$data{amount};
    }
    return \%obj;
}

sub ap_offer_amounts {
    my $self = shift;
    my $content =
      $self->get('http://xml2.txodds.com/feed/ap_offer_amounts.php');
    my $data = $self->parse_xml( $content, ValueAttr => ['offer'] );
    return $data;
}

sub deleted_ap_offers {
    my ( $self, %params ) = @_;
    my $url = 'http://xml2.txodds.com/feed/deleted_ap_offers.php';
    Carp::croak(
        "ident & passwd of http://txodds.com API required for this action")
      unless ( $self->{ident} && $self->{passwd} );

    %params = (
        ident  => $self->{ident},
        passwd => $self->{passwd}
    );
    return $self->parse_xml( $self->get( $url, \%params ) );
}

sub countries {
    my $self = shift;
    my $content =
      $self->get('http://xml2.txodds.com/feed/countries.php');
    my $data = $self->parse_xml( $content, ValueAttr => ['country'] );
    return $data;
}

sub competitors {
    my ( $self, %params ) = @_;
    my $url = 'http://xml2.txodds.com/feed/competitors.php';
    Carp::croak(
        "ident & passwd of http://txodds.com API required for this action")
      unless ( $self->{ident} && $self->{passwd} );

    %params = (
        ident  => $self->{ident},
        passwd => $self->{passwd}
    );
    return $self->parse_xml( $self->get( $url, \%params ), ValueAttr => ['competitor'] );
}

sub xml_schema {
    my $self    = shift;
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

sub clean_obj {
    my ( $self, $BadObj ) = @_;
    my %sports  = $self->sports();
    my %mgroups = $self->mgroups();

    my $obj->{'timestamp'} = $BadObj->{'timestamp'};
    $obj->{time} = $BadObj->{'time'};
    $obj->{'time'} =~
s/(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):\d{2}\+\d{2}:\d{2}/$4:$5 $3-$2-$1/;
    while ( my ( $MatchId, $MatchObj ) = each %{ $BadObj->{match} } ) {
        my $Home =
          $MatchObj->{hteam}->{ each %{ $MatchObj->{hteam} } }->{content};
        my $Away =
          $MatchObj->{ateam}->{ each %{ $MatchObj->{ateam} } }->{content};
        my $Group =
          $MatchObj->{group}->{ each %{ $MatchObj->{group} } }->{content};
        my $MatchTime = $MatchObj->{'time'};
        $MatchTime =~
s/(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):\d{2}\+\d{2}:\d{2}/$4:$5 $3-$2-$1/;
        my $Sport = $sports{ $mgroups{$1} } if $Group =~ m/^([A-Z]+).*/;
        $Group =~ s/^[A-Z]+ (.*)/$1/;

        %{ $obj->{sport}->{$Sport}->{$Group}->{"$Home - $Away"} } = (
            MatchTime => $MatchTime,
            Home      => $Home,
            Away      => $Away
        );

        while ( my ( $BookmakerName, $BookmakerObj ) =
            each %{ $MatchObj->{bookmaker} } )
        {
            while ( my ( $OfferId, $OfferObj ) =
                each %{ $BookmakerObj->{offer} } )
            {
                my $ot = $OfferObj->{ot};
                if (
                    $ot == 0
                    && (   $OfferObj->{odds}->[0]->{o1}
                        || $OfferObj->{odds}->[0]->{o2}
                        || $OfferObj->{odds}->[0]->{o3} )
                  )
                {
                    %{ $obj->{sport}->{$Sport}->{$Group}->{"$Home - $Away"}
                          ->{bookmaker}->{$BookmakerName}->{offer}->{$ot} } = (
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

    * XML Declaration
    * Matches Container
    * Match Element
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
    
This method request all master groups from http://xml2.txodds.com/feed/mgroups.php.
 
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

=head2 odds_types

This method return all odds types. For more information see
Appendix 13 in PDF documentation (C<<http://txodds.com/v2/0/services.xml.html>>).

Usage:
    my %types = $tx->odds_types();

Response:
    {
        '1' => 'money line',
        '0' => 'three way',
        '3' => 'points',
        '4' => 'totals',
        '5' => 'asian handicap'
        ...
    };

Options:
    any option (see example) will return full response
    
Example:
    my %types = $tx->odds_types('full');
    #return full response

Response:
    [
        {
            'sname' => '1x2',
            'name' => 'three way',
            'ot' => '0'
        },
        ...
    ]

=head2 offer_amounts

This servise is resersed for including exchange matched amounts for standard odds. For more information see
Appendix 12 in PDF documentation (C<<http://txodds.com/v2/0/services.xml.html>>).

Usage:
    my %oa = $tx->offer_amounts(date => '2011-04-02');

Options:
    date:
        YYYY-MM-DD            - For a cpecific date;
        YYY-MM-DD, YYYY-MM-DD - For a cpecific date range;
        today                 - Just for today;
        today+7               - For today plus 7 days;
    spid (Sport Id):
        1 - soccer;
        2 - hockey;
        Please see sports() for all sport id codes;
     boid (Bet Offer Id):
        xxxxxxx - Single bet offer id;
        xxxxxxx, yyyyyyy, zzzzzzz - multiple bet offer id;

Response:
    {
        %boid% => %amount%,
        ...
    }

=head2 ap_offer_amounts

Antepost Exchange Mathed Amounts Servise. This servise is resersed for including exchange matched amounts.
For more information see Appendix 11 in PDF documentation (C<<http://txodds.com/v2/0/services.xml.html>>).

Usage:
    my $oa = $tx->ap_offer_amounts();

Response:
    [
        {
            'amount' => %amount%,
            'bid'    => %BookmakerId%,
            'pgid'   => %pgid%
        }
        ...
    ]
    
    or
    
    {
        'amount' => %amount%,
        'bid'    => %BookmakerId%,
        'pgid'   => %pgid%
    }
    if amount is single.
    
    %amount% - monetary value of amounts of matched bets on exchanges;
    %BookmakerId% - bookmaker (exchange) identify code;
    %pgid% - offer id code. This maps directly to the offer id specified in the offer element section.

=head2 deleted_ap_offers

This servise allows a search for deleted offers on Antepost feed.
An offer refers to market/bookie/team combination.
When an offer for team is no longer 'valid' the offer id is available
on this webservise ths providing a complete audit trail of what has been available. 

Method have mandatory options:
    ident;
    passwd.

Usage:
    my $offers = $tx->deleted_ap_offers();

=head2 countries

Country codes

Usage:
    $countries = $tx->countries();

Response:
    [
        {
            'cc'   => 'IRI',
            'name' => 'Iran',
            'id'   => '361'
        }
    ]

=head2 competitors

Competitors webservice
This webservice provides a comprehensive list of team and players names used by the feed.
For more information see Appendix 6 in PDF documentation (C<<http://txodds.com/v2/0/services.xml.html>>).

Usage:
    my $competitors = $tx->competitors();

Options:
    pid     - by participant id i.e. the unique competitor number;
    pgrp    - by participant group name a combination of the sport and country (or league for US Sports) e.g. fbjpn is football Japan;
    cid     - by country id all competitors or teams within a particular country;
    spid    - by sport id – every sport has a unique identifier;
    name    - by alias name selection – shows all competitors that include a particular string.

Response:
    [
        {
            'group' => 'fbeng',
            'name' => 'Liverpool',
            'id' => '2452'
        },
        {
            'group' => 'fbeng',
            'name' => 'Liverpool B',
            'id' => '7965'
        }
    ];

=head2 get

Send GET request and return response content.

Usage:
    my $data = $tx->get( $url, \%params );

Example:
    my $url = 'http://www.vasya.com/index.html'
    my %params = (
        user => 'vasya',
        pass => 'paswd',
        data => 'sometxt'
    );
    my $data = $tx->get( $url, \%params );
    # GET http://www.vasya.com/index.html?user=vasya&pass=passwd&data=sometxt

=head2 parse_xml

Usage:
    my $obj = $tx->parse_xml($xml_string, [Parser options]);

Options:
    Function is use XML::LibXML::Simple module. See options of parser in documentation of this module.

=head2 create_get_request

Method create GET request with URI. Used by get().

Usage:
    my $request = $tx->create_get_request( $url, \%params );

=head2 clean_obj

Method for clean "bad" API data object, returned full_service_feed(): delete unnecessary nodes, add sport node etc.

Usage:
    my $BadObj = $tx->full_service_feed();
    my $GoodObj = $tx->clean_obj($BadObj);

Response:
    {
        'timestamp' => '%Timestamp%',
        'time' => '%Time%',
        'sport' => {
            %SportName% => {
                %GroupName% => {
                    %MatchName% => {
                        'bookmaker' => {
                            %BookmakerName% => {
                                'offer' => {
                                    %OfferCode% => {
                                        '1' => %Odd%,
                                        'x' => %Odd%,
                                        '2' => %Odd%
                                    },
                                    ...
                                }
                            }
                            ...
                        },
                        'Home' => %HomeTeam%,
                        'MatchTime' => %MatchTime%,
                        'Away' => %AwayTeam%
                    },
                    ...
                },
                ...
            },
            ...
        },
    }

    Where:
        %Timestamp%      - Unix timestamp;
        %Time%           - Current time 'hh:mm dd-mm-yyyy' (13:04 22-09-2011);
        %SportName%      - Name of sport. See sports() method description;
        %GroupName%      - Group, League, Division, etc.;
        %MatchName%      - Name of match ('First comand\player' - 'Second comand\player');
        %BookmakerName%  - Name of bookmaker;
        %OfferCode%      - Offer code;
        %Odd%            - Odd factor;
        %HomeTeam%       - First comand, home comand, first player, or favorite etc.;
        %AwayTeam%       - Second comand, home comand, second player etc.


=head1 AUTHOR

"Alexander Foxcool Babenko", C<<"foxcool@cpan.org">>

=head1 BUGS

Please report any bugs or feature requests to C<bug-txodds at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Txodds>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

GitHub: C<<https://github.com/Foxcool/Txodds>>

For more information about TXOdds API please see C<<http://txodds.com/v2/0/services.xml.html>>.

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
