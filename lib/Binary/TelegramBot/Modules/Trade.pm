package Binary::TelegramBot::Modules::Trade;

use Binary::TelegramBot::WSBridge qw(send_ws_request get_currency);
use Binary::TelegramBot::SendMessage qw(send_message);
use Exporter qw(import);
use Data::Dumper;

our @EXPORT = qw(process_trade);

sub process_trade {
    my ($chat_id, $arguments) = @_;
    my @args = split(/ /, $arguments, 4);
    my $length = scalar @args;

    my $response_map = {
        0 => sub {
            my $response = 'Please select a trade type:';
            my $keys     = [[{
                        text          => 'Digit Matches',
                        callback_data => '/trade DIGITMATCH'
                    },
                    {
                        text          => 'Digit Differs',
                        callback_data => '/trade DIGITDIFF'
                    },
                    {
                        text          => 'Digit Over',
                        callback_data => '/trade DIGITOVER'
                    },
                ],
                [{
                        text          => 'Digit Under',
                        callback_data => '/trade DIGITUNDER'
                    },
                    {
                        text          => 'Digit Even',
                        callback_data => '/trade DIGITEVEN'
                    },
                    {
                        text          => 'Digit Odd',
                        callback_data => '/trade DIGITODD'
                    }]];
            send_message($chat_id, $response, {inline_keyboard => $keys});
        },
        1 => sub {
            my $trade_type = $args[0];
            return if ask_for_barrier($chat_id, $args[0]);    #Check if contract requires barrier.
            my $response = 'Please select an underlying:';
            my $keys     = [[{
                        text          => 'Volatility Index 10',
                        callback_data => "/trade $trade_type R_10"
                    },
                    {
                        text          => 'Volatility Index 25',
                        callback_data => "/trade $trade_type R_25"
                    }
                ],
                [{
                        text          => 'Volatility Index 50',
                        callback_data => "/trade $trade_type R_50"
                    },
                    {
                        text          => 'Volatility Index 75',
                        callback_data => "/trade $trade_type R_75"
                    },
                ],
                [{
                        text          => 'Volatility Index 100',
                        callback_data => "/trade $trade_type R_100"
                    }]];
            send_message($chat_id, $response, {inline_keyboard => $keys});
        },
        2 => sub {
            my $trade_type = $args[0];
            my $underlying = $args[1];
            my $currency   = get_currency($chat_id);
            my $response   = 'Please select a payout:';
            my $keys       = [[{
                        text          => "5 $currency",
                        callback_data => "/trade $trade_type $underlying 5"
                    },
                    {
                        text          => "10 $currency",
                        callback_data => "/trade $trade_type $underlying 10"
                    },
                    {
                        text          => "25 $currency",
                        callback_data => "/trade $trade_type $underlying 25"
                    }
                ],
                [{
                        text          => "50 $currency",
                        callback_data => "/trade $trade_type $underlying 50"
                    },
                    {
                        text          => "100 $currency",
                        callback_data => "/trade $trade_type $underlying 100"
                    }]];
            send_message($chat_id, $response, {inline_keyboard => $keys});
        },
        3 => sub {
            my $trade_type = $args[0];
            my $underlying = $args[1];
            my $payout     = $args[2];
            my $response   = 'Please select a duration:';
            my $keys       = [[{
                        text          => '5 ticks',
                        callback_data => "/trade $trade_type $underlying $payout 5"
                    },
                    {
                        text          => '6 ticks',
                        callback_data => "/trade $trade_type $underlying $payout 6"
                    },
                    {
                        text          => '7 ticks',
                        callback_data => "/trade $trade_type $underlying $payout 7"
                    }
                ],
                [{
                        text          => '8 ticks',
                        callback_data => "/trade $trade_type $underlying $payout 8"
                    },
                    {
                        text          => '9 ticks',
                        callback_data => "/trade $trade_type $underlying $payout 9"
                    },
                    {
                        text          => '10 ticks',
                        callback_data => "/trade $trade_type $underlying $payout 10"
                    }]];
            send_message($chat_id, $response, {inline_keyboard => $keys});
        },
        4 => sub {
            my ($trade_type, $barrier) = split(/_/, $args[0], 2);
            my $underlying = $args[1];
            my $payout     = $args[2];
            my $duration   = $args[3];
            send_proposal(
                $chat_id,
                {
                    underlying    => $underlying,
                    payout        => $payout,
                    contract_type => $trade_type,
                    duration      => $duration,
                    barrier       => $barrier
                });
        }
    };

    $response_map->{$length}->();
}

sub ask_for_barrier {
    my ($chat_id, $args) = @_;
    my ($trade_type, $barrier) = split(/_/, $args, 2);
    print "---$barrier---\n";
    my @requires_barrrier = qw(DIGITMATCH DIGITDIFF DIGITUNDER DIGITOVER);
    if (grep(/^$trade_type$/, @requires_barrrier) && $barrier eq '') {
        my $response = 'Please select a digit:';
        my $keys     = [[{
                    text          => '1',
                    callback_data => "/trade ${trade_type}_1"
                },
                {
                    text          => '2',
                    callback_data => "/trade ${trade_type}_2"
                },
                {
                    text          => '3',
                    callback_data => "/trade ${trade_type}_3"
                },
                {
                    text          => '4',
                    callback_data => "/trade ${trade_type}_4"
                }
            ],
            [{
                    text          => '5',
                    callback_data => "/trade ${trade_type}_5"
                },
                {
                    text          => '6',
                    callback_data => "/trade ${trade_type}_6"
                },
                {
                    text          => '7',
                    callback_data => "/trade ${trade_type}_7"
                },
                {
                    text          => '8',
                    callback_data => "/trade ${trade_type}_8"
                }]];
        unshift @$keys[0],
            {
            text          => '0',
            callback_data => "/trade ${trade_type}_0"
            } if ($trade_type ne 'DIGITUNDER');
        push @$keys[1],
            {
            text          => '9',
            callback_data => "/trade ${trade_type}_9"
            } if ($trade_type ne 'DIGITOVER');
        send_message($chat_id, $response, {inline_keyboard => $keys});
        return 1;
    }
    return 0;
}

sub send_proposal {
    my ($chat_id, $params) = @_;
    my $request = {
        proposal      => 1,
        amount        => $params->{payout},
        basis         => 'payout',
        contract_type => $params->{contract_type},
        currency      => get_currency($chat_id),
        duration      => $params->{duration},
        duration_unit => 't',
        symbol        => $params->{underlying}};
    $request->{barrier} = $params->{barrier} if $params->{barrier} ne '';
    send_ws_request($request, $chat_id);
    return;
}

1;
