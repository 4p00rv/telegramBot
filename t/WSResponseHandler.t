use strict;
use warnings;

use Test::More "no_plan";
use JSON qw | decode_json encode_json|;
use Data::Dumper;
use Binary::TelegramBot::Helper::Await qw (await_response);
use Binary::TelegramBot::WSBridge qw (send_ws_request get_property);
use Binary::TelegramBot::WSResponseHandler qw (forward_ws_response);

sub start {
    my $creds = {
        chat_id => '123',
        token   => $ENV{"BINARY_TOKEN"}};
    authorize($creds);
    balance($creds);
    my $proposal_id = proposal($creds);
    my $contract_id = buy($creds, $proposal_id);
    proposal_open_contract($creds);
}

sub authorize {
    my $creds    = shift;
    my $req      = {authorize => $creds->{token}};
    my $future   = send_ws_request($creds->{chat_id}, $req);
    my $response = await_response($future);
    my $reply    = forward_ws_response($creds->{chat_id}, $response);

    # Check reply for authorize
    ok(index($reply->{text}, "We have successfully authenticated you.") != -1)
        or diag "Unexpected reply for 'authorize' response.";
}

sub balance {
    my $creds    = shift;
    my $req      = {balance => 1};
    my $future   = send_ws_request($creds->{chat_id}, $req);
    my $response = await_response($future);
    my $reply    = forward_ws_response($creds->{chat_id}, $response);

    # Check reply for balance
    ok(index($reply->{text}, "Balance:") != -1) or "Unexpected reply for 'balance' response";
}

sub proposal {
    my $creds = shift;
    my $req   = {
        proposal      => 1,
        amount        => 10,
        basis         => 'payout',
        contract_type => 'DIGITEVEN',
        currency      => get_property($creds->{chat_id}, 'currency'),
        duration      => 5,
        duration_unit => 't',
        symbol        => 'R_10'
    };
    my $future   = send_ws_request($creds->{chat_id}, $req);
    my $response = await_response($future);
    my $reply    = forward_ws_response($creds->{chat_id}, $response);
    my $proposal = decode_json($response)->{proposal};

    # Check if proposal reply contains longcode
    ok(index($reply->{text}, $proposal->{longcode}) == 0)
        or diag "Longcode not found in response";
    # Check if proposal reply contains buy price
    ok(index($reply->{text}, "Ask Price: $proposal->{ask_price}") != -1)
        or diag "Ask price not found";
    # Check if proposal reply contains payout
    ok(index($reply->{text}, "Payout: $proposal->{payout}") != -1)
        or diag "Payout not found";

    return $proposal->{id};
}

sub buy {
    my ($creds, $id) = @_;
    my $req = {
        buy   => $id,
        price => 100
    };
    my $future         = send_ws_request($creds->{chat_id}, $req);
    my $response       = await_response($future);
    my $reply          = forward_ws_response($creds->{chat_id}, $response);
    my $buy            = decode_json($response)->{buy};
    my $currency       = get_property($creds->{chat_id}, "currency");
    my $buy_price      = $buy->{buy_price};
    my $balance        = $buy->{balance_after};
    my $expected_reply = "Succesfully bought contract at $currency $buy_price.\nYour new balance: $currency $balance";
    # Check if buy request was successful
    ok($reply->{text} eq $expected_reply)
        or diag "Buy request failed";

    return $buy->{contract_id};
}

sub proposal_open_contract {
    my $creds    = shift;
    my $response = {
        proposal_open_contract => {
            entry_tick_time   => 2,
            current_spot      => 0.5,
            current_spot_time => 1,
            date_expiry       => 3,
            is_sold           => 0,
            buy_price         => 5.15
        },
        msg_type => "proposal_open_contract"
    };
    # No repsonse if entry_tick > current_spot_time
    my $reply = forward_ws_response($creds->{chat_id}, encode_json($response));
    ok(!$reply) or diag "proposal_open_contract: Expected no response but got response";
    # Normal response
    $response->{proposal_open_contract}->{current_spot_time} = 2;
    $reply = forward_ws_response($creds->{chat_id}, encode_json($response));
    ok($reply->{text} eq "Current spot: *0.5*") or diag "proposal_open_contract: Wrong current spot";
    # Response for exit spot.
    $response->{proposal_open_contract}->{current_spot_time} = 3;
    $reply = forward_ws_response($creds->{chat_id}, encode_json($response));
    ok(index($reply->{text}, "Exit spot: *0.5*") != -1) or diag "proposal_open_contract: Wrong Exit spot";
    # Response for sold_contracts which won.
    $response->{proposal_open_contract}->{is_sold}    = 1;
    $response->{proposal_open_contract}->{sell_price} = 10;
    $reply = forward_ws_response($creds->{chat_id}, encode_json($response));
    ok(index($reply->{text}, "You won a payout of USD 10") != -1) or diag "proposal_open_contract: Wrong message for sold contracts";
    $response->{proposal_open_contract}->{sell_price} = 0;
    $reply = forward_ws_response($creds->{chat_id}, encode_json($response));
    ok(index($reply->{text}, "You lost USD 5.15") != -1) or diag "proposal_open_contract: Wrong message for sold contracts";
}

start();
