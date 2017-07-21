package Binary::TelegramBot::WSResponseHandler;

use strict;
use warnings;

use JSON qw(decode_json);
use Binary::TelegramBot::SendMessage qw(send_message);
use Exporter qw(import);
use Data::Dumper;

our @EXPORT = qw(send_ws_response);

my $process_ws_resp = {
    "authorize" => sub {
        my ($chat_id, $resp) = @_;
        my $msg      = "We have successfully authenticated you." . "\nYour login-id is: $resp->{loginid}" . "\nYour balance is: $resp->{balance}";
        my $keyboard = {
            "keyboard" => [["Trade"], ['Balance']],
            "one_time_keyboard" => \0
        };
        send_message($chat_id, $msg, $keyboard);
    },
    "balance" => sub {
        my ($chat_id, $resp) = @_;
        my $val  = $resp->{balance};
        my $curr = $resp->{currency};
        my $msg  = "Balance: " . $curr . " $val.";
        send_message($chat_id, $msg);
    },
    "proposal" => sub {
        my ($chat_id, $resp) = @_;
        my $payout   = $resp->{payout};
        my $longcode = $resp->{longcode};
        my $currency = Binary::TelegramBot::WSBridge::get_currency($chat_id);
        my $id       = $resp->{id};
        my $msg  = "${longcode}\nYou will get a payout of $currency $payout if you win." . "\nTo buy the contract please select the following option";
        my $keys = [[{
                    text          => "Buy",
                    callback_data => "/buy $id"
                }]];
        send_message($chat_id, $msg, {inline_keyboard => $keys});
    },
    "buy" => sub {
        my ($chat_id, $resp) = @_;
        my $currency    = Binary::TelegramBot::WSBridge::get_currency($chat_id);
        my $buy_price   = $resp->{buy_price};
        my $contract_id = $resp->{contract_id};
        my $msg         = "Succesfully bought contract at $currency $buy_price.";
        send_message($chat_id, $msg);
        Binary::TelegramBot::WSBridge::send_ws_request({
                proposal_open_contract => 1,
                contract_id            => $contract_id,
                subscribe              => 1
            },
            $chat_id
        );
    },
    "proposal_open_contract" => sub {
        my ($chat_id, $resp) = @_;
        return if (!$resp->{entry_tick_time} || $resp->{current_spot_time} < $resp->{entry_tick_time});
        my $current_spot = $resp->{current_spot};
        my $msg = $resp->{current_spot_time} <= $resp->{date_expiry} ? "Current spot: *${current_spot}*" : "";
        if ($resp->{is_sold}) {
            my $currency   = Binary::TelegramBot::WSBridge::get_currency($chat_id);
            my $buy_price  = $resp->{buy_price};
            my $sell_price = $resp->{sell_price};
            $msg .= "\n\nYou won a payout of $currency $sell_price." if $sell_price > 0;
            $msg .= "\n\nYou lost $currency $buy_price." if $sell_price == 0;
            Binary::TelegramBot::WSBridge::send_ws_request({balance => 1}, $chat_id);
        }
        send_message($chat_id, $msg);
    }
};

sub send_ws_response {
    my ($resp, $chat_id) = @_;
    return if !$resp;
    $resp = decode_json($resp);
    if ($resp->{error}) {
        print Dumper($resp->{echo_req});
        my $error = "*Error:* $resp->{error}->{message}";
        send_message($chat_id, $error);
    } else {
        my $msg_type = $resp->{msg_type};
        $process_ws_resp->{$msg_type}->($chat_id, $resp->{$msg_type});
    }
}

1;
