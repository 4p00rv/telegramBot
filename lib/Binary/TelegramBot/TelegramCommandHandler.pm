package Binary::TelegramBot::TelegramCommandHandler;

use strict;
use warnings;

use Exporter qw(import);
use Binary::TelegramBot::SendMessage qw(send_message);
use Binary::TelegramBot::WSBridge qw(send_ws_request is_authenticated);
use Binary::TelegramBot::WSResponseHandler qw(forward_ws_response);
use Binary::TelegramBot::Modules::Trade qw(process_trade subscribe_proposal);
use JSON qw(decode_json);

our @EXPORT = qw(process_message);

my $commands = {
    'start' => sub {
        my ($chat_id, $token) = @_;
        my $response =
              "Hi there! Welcome to [Binary.com\'s](https://www.binary.com) bot."
            . "\nWe\'re glad to see you here."
            . "\n\nPlease wait while we authorize you.";
        send_message({
            chat_id => $chat_id,
            text    => $response
        });
        my $future = send_ws_request($chat_id, {authorize => $token});
        send_response_on_ready($chat_id, $future);
    },
    'undef' => sub {
        my $chat_id  = shift;
        my $response = 'A reply to that query is still being designed. Please hold on tight while this BOT evolves.';
        send_message({
            chat_id => $chat_id,
            text    => $response
        });
    },
    "balance" => sub {
        my $chat_id  = shift;
        my $response = '';
        if (is_authenticated($chat_id)) {
            my $future = send_ws_request($chat_id, {balance => 1});
            send_response_on_ready($chat_id, $future);
        } else {
            send_un_authenticated_msg($chat_id);
            return;
        }
    },
    "trade" => sub {
        my ($chat_id, $arguments) = @_;
        my $response = '';
        if (!is_authenticated($chat_id)) {
            send_un_authenticated_msg($chat_id);
            return;
        } else {
            Binary::TelegramBot::Modules::Trade::process_trade($chat_id, $arguments);
        }
    },
    "buy" => sub {
        my ($chat_id, $arguments) = @_;
        my @args = split(/ /, $arguments, 2);
        my $response = 'Processing buy request.';
        send_message({
            chat_id => $chat_id,
            text    => $response
        });
        my $future = send_ws_request(
            $chat_id,
            {
                buy   => $args[0],
                price => $args[1]});
        $future->on_ready(
            sub {
                my $response = $future->get;
                my $reply = forward_ws_response($chat_id, $response);
                send_message($reply);
                my $contract_id = decode_json($response)->{buy}->{contract_id};
                Binary::TelegramBot::Modules::Trade::subscribe_proposal($chat_id, $contract_id);
            });
    }
};

sub process_message {
    my ($chat_id, $msg) = @_;
    return if !$msg;
    if ($msg =~ m/^\/?([A-Za-z]+)\s?(.+)?/) {
        my $command   = lc($1);
        my $arguments = $2;
        $commands->{$command} ? $commands->{$command}->($chat_id, $arguments) : $commands->{'undef'}->($chat_id);
        return;
    }
    $commands->{'undef'}->($chat_id);
}

sub send_un_authenticated_msg {
    my $chat_id  = shift;
    my $response = "You need to authenticate first. \nVisit https://4p00rv.github.io/BinaryTelegramBotLanding/index.html to authorize the bot.";
    send_message({
        chat_id => $chat_id,
        text    => $response
    });
}

sub send_response_on_ready {
    my ($chat_id, $future) = @_;
    $future->on_ready(
        sub {
            my $response = $future->get;
            my $reply = forward_ws_response($chat_id, $response);
            send_message($reply);
        });
}

# # Expects first parameter as field name. All other arguments are values that needs to be validated
# sub validate {
#     my $field       = shift;
#     my $validations = {
#         trade => sub {
#             my ($underlying, $trade_type, $stake, $duration) = @_;
#             my @valid_underlyings = qw(R_10 R_25 R_50 R_75 R_100);
#             my @valid_trades      = qw(DIGITMATCH DIGITDIFF DIGITEVEN DIGITODD DIGITUNDER DIGITOVER);
#             return "Invalid underlying." if !$underlying || !grep(/^$underlying$/, @valid_underlyings);
#             return "Invalid trade type." if !$trade_type || !grep(/^$trade_type$/, @valid_trades);
#             return "Invalid duration." if !$duration || !($duration =~ m/^[\d]{1,2}$/) || !($duration >= 5 && $duration <= 10);
#             return "Invalid stake." if !$stake || !($stake =~ m/^[\d]+\.?[\d]*$/) || !($stake > 0);
#         }
#     };

#     return $validations->{$field}->(@_);
# }

1;
