#!/usr/bin/perl -w
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
#    02110-1301, USA

package Finance::Quote::XETRA;

require 5.005;

use strict;
use JSON qw( decode_json );
use vars qw($VERSION $YIND_URL_HEAD $YIND_URL_TAIL);
use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::TableExtract;
use Time::Piece;

# VERSION


my $PRICE_URL = "https://api.boerse-frankfurt.de/data/price_information?mic=XETR&isin=";

sub methods {
    return ( xetra => \&xetra,
    );
}
{
    my @labels = qw/exchange symbol last high low isodate date close currency/;

    sub labels {
        return ( xetra => \@labels, );
    }
}

sub xetra {

    my $quoter = shift;
    my @stocks = @_;
    my ( %info, $reply, $url, $te, $ts, $row, @cells, $ce );
    my $ua = $quoter->user_agent();

    # server reply is a perpetual event stream with continuous updates
    # disconnect after we receive the first event
    $ua->max_size(10);

    foreach my $stocks (@stocks) {
        my $url = $PRICE_URL . $stocks;
        my $resp = $ua->request(GET $url);
        my $code = $resp->code;
        my $desc = HTTP::Status::status_message($code);
        my $len = length($resp->content);

        $info{ $stocks, "symbol" } = $stocks;

        if ( $code == 200 && $len > 5 ) {
            my $payload = substr($resp->content, 5);
            my $data = JSON::decode_json $payload;

            $info{$stocks, 'success'} = 1;
            $info{$stocks, 'method'} = 'xetra';
            $info{$stocks, 'exchange'} = 'XETR';
            $info{$stocks, 'symbol'} = $data->{'isin'};
            $info{$stocks, 'last'} = $data->{'lastPrice'};
            $info{$stocks, 'high'} = $data->{'dayHigh'};
            $info{$stocks, 'low'} = $data->{'dayLow'};
            $info{$stocks, 'close'} = $data->{'closingPricePrevTradingDay'};
            $info{$stocks, 'currency'} = $data->{'currency'}{'originalValue'};

            my $isodate = substr($data->{'timestampLastPrice'}, 0, 10);
            $info{$stocks, 'isodate'} = $isodate;
            $info{$stocks, 'date'} = substr($isodate, 5, 2) . "/" . substr($isodate, 8, 10) . "/" . substr($isodate, 0, 4);

        }
        else {
            $info{ $stocks, "success" } = 0;
            $info{ $stocks, "errormsg" } =
                "Error retrieving quote for $stocks. Attempt to fetch the URL $url resulted in HTTP response $code ($desc) and body of length $len";
        }

    }

    return wantarray() ? %info : \%info;
    return \%info;
}

1;

=head1 NAME

Finance::Quote::XETRA - Obtain quotes from XETRA.

=head1 SYNOPSIS

    use Finance::Quote;

    $q = Finance::Quote->new;

    %info = Finance::Quote->fetch("xetra","EU0009658145");

=head1 DESCRIPTION

This module fetches information from the XETRA exchange, also including ETFs.

This module is loaded by default on a Finance::Quote object. It's
also possible to load it explicitly by placing "XETRA" in the argument
list to Finance::Quote->new().

This module provides the "xetra" fetch method.

=head1 LABELS RETURNED

The following labels may be returned by Finance::Quote::XETRA :
exchange symbol last high low isodate date close currency

=head1 SEE ALSO

=cut