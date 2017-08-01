use strict;
use warnings;

use Future;
use Test::More "no_plan";
use JSON qw | decode_json encode_json|;
use Binary::TelegramBot::Helper::Await qw (await_response);
use Binary::TelegramBot::WSBridge qw(send_ws_request is_authenticated get_property);

sub start {
    my $creds = {
        chat_id => '123',
        token   => $ENV{"BINARY_TOKEN"}};
    authorize($creds);
    # get_balance($creds);
    test_callback($creds);
}

sub authorize {
    my $creds    = shift;
    my $req      = {authorize => 'invalid_token'};
    my $future   = send_ws_request($creds->{chat_id}, $req);
    my $response = decode_json(await_response($future));
    # Invalid token
    ok($response->{error}->{code} eq "InvalidToken") or diag "Unexpected response:\n" . encode_json($response) . "\n";

    $req = {authorize => $creds->{token}};
    $future = send_ws_request($creds->{chat_id}, $req);
    $response = decode_json(await_response($future));
    # Valid token
    ok($response->{authorize}) or diag "Unexpected error: '$response->{error}->{message}'";
    # Check if status has changed to authenticated
    ok(is_authenticated($creds->{chat_id}) eq 1) or diag "Client is not authenticated";
    # Check if authorize object has been saved succesfully
    ok(get_property($creds->{chat_id}, "loginid")) or diag "No loginid in authorize response?";
}

sub get_balance {
    my $creds    = shift;
    my $req      = {balance => 1};
    my $future   = send_ws_request($creds->{chat_id}, $req);
    my $response = decode_json(await_response($future));
    # Send ws request for getting balance.
    ok($response->{balance}) or diag "Cannot fetch balance";
}

sub test_callback {
    my $creds = shift;
    my $req = {ping => 1};
    my $future = Future->new;
    send_ws_request(
        $creds->{chat_id},
        $req,
        sub {
            my ($chat_id, $response) = @_;
            $response = decode_json($response);
            ok($response->{ping} eq "pong") or diag "Callback are not working";
            $future->done();
        });
    await_response($future);
}

start();
