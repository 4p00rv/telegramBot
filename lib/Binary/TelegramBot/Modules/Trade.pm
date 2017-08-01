package Binary::TelegramBot::Modules::Trade;

use Binary::TelegramBot::WSBridge qw(send_ws_request get_property);
use Binary::TelegramBot::SendMessage qw(send_message);
use Binary::TelegramBot::Helper::Await qw (await_response);
use Binary::TelegramBot::WSResponseHandler qw(forward_ws_response);
use Future;
use Data::Dumper;
use JSON qw(decode_json);

our @EXPORT = qw(process_trade subscribe_proposal get_trade_type);

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
            send_message({
                    chat_id      => $chat_id,
                    text         => $response,
                    reply_markup => {inline_keyboard => $keys}});
        },
        1 => sub {
            my $trade_type = $args[0];
            return if ask_for_barrier($chat_id, $args[0]);    #Check if contract requires barrier.
            my $response = get_trade_type($trade_type) . "\nPlease select an underlying:";
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
            send_message({
                    chat_id      => $chat_id,
                    text         => $response,
                    reply_markup => {inline_keyboard => $keys}});
        },
        2 => sub {
            my $trade_type = $args[0];
            my $underlying = $args[1];
            my $currency   = get_property($chat_id, "currency");
            my $response   = get_trade_type($trade_type) . "Underlying: " . get_underlying_name($underlying) . " \n\nPlease select a payout:";
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
            send_message({
                    chat_id      => $chat_id,
                    text         => $response,
                    reply_markup => {inline_keyboard => $keys}});
        },
        3 => sub {
            my $trade_type = $args[0];
            my $underlying = $args[1];
            my $payout     = $args[2];
            my $response =
                  get_trade_type($trade_type)
                . "Underlying: "
                . get_underlying_name($underlying)
                . "\nPayout: "
                . get_property($chat_id, "currency")
                . " $payout"
                . "\n\nPlease select a duration:";
            my $keys = [[{
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
            send_message({
                    chat_id      => $chat_id,
                    text         => $response,
                    reply_markup => {inline_keyboard => $keys}});
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
    my @requires_barrrier = qw(DIGITMATCH DIGITDIFF DIGITUNDER DIGITOVER);
    if (grep(/^$trade_type$/, @requires_barrrier) && $barrier eq '') {
        my $response = get_trade_type($trade_type) . "\nPlease select a digit:";
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
        send_message({
                chat_id      => $chat_id,
                text         => $response,
                reply_markup => {inline_keyboard => $keys}});
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
        currency      => get_property($chat_id, "currency"),
        duration      => $params->{duration},
        duration_unit => 't',
        symbol        => $params->{underlying}};
    $request->{barrier} = $params->{barrier} if $params->{barrier} ne '';
    my $future = send_ws_request($chat_id, $request);
    $future->on_ready(
        sub {
            my $response = $future->get;
            my $reply = forward_ws_response($chat_id, $response);
            send_message($reply);
        });
    return;
}

sub subscribe_proposal {
    my ($chat_id, $contract_id) = @_;
    my $request = {
        proposal_open_contract => 1,
        contract_id            => $contract_id,
        subscribe              => 1
    };
    my $future = Future->new;
    send_ws_request(
        $chat_id, $request,
        sub {
            my ($chat_id, $response) = @_;
            my $resp_obj = decode_json($response);
            my $reply = forward_ws_response($chat_id, $response);
            send_message($reply);
        });
}

sub get_trade_type {
    my $arguments = shift;
    my @args      = split(/_/, $arguments, 2);
    my $name      = {
        "DIGITMATCH" => "Digit Matches",
        "DIGITDIFF"  => "Digit Differs",
        "DIGITOVER"  => "Digit Over",
        "DIGITUNDER" => "Digit Under",
        "DIGITEVEN"  => "Digit Even",
        "DIGITODD"   => "Digit Odd"
    }->{$args[0]};
    $ret_val = "Trade type: $name\n";
    $ret_val .= "Barrier: $args[1]\n" if $args[1];
    return $ret_val;
}

sub get_underlying_name {
    my $symbol = shift;
    return {
        R_10  => "Volatility Index 10",
        R_25  => "Volatility Index 25",
        R_50  => "Volatility Index 50",
        R_75  => "Volatility Index 75",
        R_100 => "Volatility Index 100"
    }->{$symbol};
}

1;
