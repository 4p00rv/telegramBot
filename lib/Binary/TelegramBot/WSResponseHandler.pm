package Binary::TelegramBot::WSResponseHandler;

use strict;
use warnings;

use JSON qw(decode_json);
use Binary::TelegramBot::WSBridge qw(send_ws_request get_property);
use Exporter qw(import);
use Data::Dumper;

our @EXPORT = qw(forward_ws_response);

my $process_ws_resp = {
    "authorize" => sub {
        my ($chat_id, $resp) = @_;
        my $msg      = "We have successfully authenticated you." . "\nYour login-id is: $resp->{loginid}" . "\nYour balance is: $resp->{balance}";
        my $keyboard = {
            "keyboard" => [["Trade"], ['Balance']],
            "one_time_keyboard" => \0
        };

        return {
            chat_id      => $chat_id,
            text         => $msg,
            reply_markup => $keyboard
        };
    },
    "balance" => sub {
        my ($chat_id, $resp) = @_;
        my $val  = $resp->{balance};
        my $curr = $resp->{currency};
        my $msg  = "Balance: " . $curr . " $val.";

        return {
            chat_id => $chat_id,
            text    => $msg
        };
    },
    "proposal" => sub {
        my ($chat_id, $resp) = @_;
        my $currency = get_property($chat_id, "currency");
        my $id = $resp->{id};
        my $msg =
              "$resp->{longcode}"
            . "\nAsk Price: $resp->{ask_price}"
            . "\nPayout: $resp->{payout}"
            . "\n\nTo buy the contract please select the following option";
        my $keyboard = {
            inline_keyboard => [[{
                        text          => "Buy",
                        callback_data => "/buy $id $resp->{ask_price}"
                    }]]};

        return {
            chat_id      => $chat_id,
            text         => $msg,
            reply_markup => $keyboard
        };
    },
    "buy" => sub {
        my ($chat_id, $resp) = @_;
        my $currency    = get_property($chat_id, "currency");
        my $buy_price   = $resp->{buy_price};
        my $balance     = $resp->{balance_after};
        my $msg         = "Succesfully bought contract at $currency $buy_price.\nYour new balance: $currency $balance";

        return {
            chat_id => $chat_id,
            text    => $msg
        };
    },
    "proposal_open_contract" => sub {
        my ($chat_id, $resp) = @_;
        return if (!$resp->{entry_tick_time} || $resp->{current_spot_time} < $resp->{entry_tick_time});
        my $current_spot = $resp->{current_spot};
        my $msg = $resp->{current_spot_time} < $resp->{date_expiry} ? "Current spot: *${current_spot}*" : "";
        if (!$msg) {
            $msg = $resp->{current_spot_time} == $resp->{date_expiry} ? "Exit spot: *${current_spot}*" : "";
        }

        if ($resp->{is_sold}) {
            my $currency   = get_property($chat_id, "currency");
            my $buy_price  = $resp->{buy_price};
            my $sell_price = $resp->{sell_price};
            $msg .= "\n\nYou won a payout of $currency $sell_price." if $sell_price > 0;
            $msg .= "\n\nYou lost $currency $buy_price." if $sell_price == 0;
        }

        return {
            chat_id => $chat_id,
            text    => $msg
        };
    },
    "error" => sub {
        my ($chat_id, $msg) = @_;

        return {
            chat_id => $chat_id,
            text    => "*Error:* $msg",
        };
    }
};

sub forward_ws_response {
    my ($chat_id, $resp) = @_;
    return if !$resp;
    $resp = decode_json($resp);
    if ($resp->{error}) {
        return $process_ws_resp->{error}->($chat_id, $resp->{error}->{message});
    } else {
        my $msg_type = $resp->{msg_type};
        return $process_ws_resp->{$msg_type}->($chat_id, $resp->{$msg_type});
    }
}

1;
