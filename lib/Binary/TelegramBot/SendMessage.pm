package Binary::TelegramBot::SendMessage;

use strict;
use warnings;

use Binary::TelegramBot::WSBridge;
use Mojo::UserAgent;
use JSON qw(encode_json decode_json);
use Exporter qw(import);
use Data::Dumper;

our @EXPORT = qw(send_message);

my $ua              = Mojo::UserAgent->new;
my $token           = $ENV{'TELEGRAM_BOT'};
my $update_url      = "https://api.telegram.org/bot$token/sendMessage";
my $authenticated   = {};
my $process_ws_resp = {
    "authorize" => sub {
        my ($chat_id, $resp) = @_;
        my $msg      = "We have successfully authenticated you. Please choose an option to continue.";
        my $keyboard = {
            "keyboard" => [[{
                        text          => "Trade",
                        callback_data => "/trade"
                    },
                    {
                        text          => "Balance",
                        callback_data => "/balance"
                    }]
            ],
            "one_time_keyboard" => \1
        };
        _send($chat_id, $msg, $keyboard);
    },
    "balance" => sub {
        my ($chat_id, $resp) = @_;
        my $val  = $resp->{balance};
        my $curr = $resp->{currency};
        my $msg  = "You have " . $curr . " $val.";
        _send($chat_id, $msg);
    }
};

sub get_response {
    my ($msg, $chat_id, $arguments) = @_;
    my $msg_map = {
        'start' => sub {
            my $response =
                'Hi there! Welcome to [Binary.com\'s](https://www.binary.com) bot. Please provide API token to start using this bot. You can obtain API token by visiting [this link](https://www.binary.com/en/user/security/api_tokenws.html).'
                . ' Please use this format to authorize:\n`/authorize <token>`';
            _send($chat_id, $response);
        },
        'authorize' => sub {
            my $response = 'Please wait while we authorize you.';
            _send($chat_id, $response);
            authorize($chat_id, $arguments);    # Here $arguments is token
        },
        'undef' => sub {
            my $response = 'A reply to that query is still being designed. Please hold on tight while this BOT evolves.';
            _send($chat_id, $response);
        },
        "balance" => sub {
            my $response = '';
            if (is_authenticated($chat_id)) {
                $response = 'Please wait while we are retrieving your balance.';
                send_ws_request({balance => 1}, $chat_id);
            } else {
                send_un_authenticated_msg($chat_id);
                return;
            }
            _send($chat_id, $response);
        },
        "trade" => sub {
            my $response = '';
            if (!is_authenticated($chat_id)) {
                send_un_authenticated_msg($chat_id);
                return;
            } elsif (!$arguments) {
                $response =
                      "Please reply in the following format:" . "\n```"
                    . "\n/trade <symbol> <stake> <duration>" . "\n```"
                    . "\n\nWhere:"
                    . "\n`<symbol>`: Is the underlying you want to trade on."
                    . "\n`<stake>`: Is the amount you're willing to pay."
                    . "\n`<duration>`: Duration of contract in ticks ( minimum: 5, maximum: 10). "
                    . "\n\nHere's the list of symbols you can choose from (case sensitive):"
                    . "\n1. Volatility Index 10   - R\\_10"
                    . "\n2. Volatility Index 25   - R\\_25"
                    . "\n3. Volatility Index 50   - R\\_50"
                    . "\n4. Volatility Index 75   - R\\_75"
                    . "\n5. Volatility Index 100  - R\\_100"
                    . "\n\nExample usage: /trade R\\_50 100 7";
            } else {
                my @args = split(/\s/, $arguments, 3);
                $args[0] =~ s/_/\\_/g;
                $response =
                      "You passed the following trade parameters:"
                    . "\n1. Symbol   : ${args[0]}\n2. Stake    : ${args[1]}\n3. Duration : ${args[2]} ticks.";
            }

            _send($chat_id, $response);
        }
    };

    return $msg_map->{$msg} ? $msg_map->{$msg}->() : $msg_map->{'undef'}->();
}

sub send_message {
    my ($msg, $chat_id) = @_;
    return if !$msg;
    if ($msg =~ m/^\/([a-z]+)\s?([\w\s]+)?/) {
        my $command   = $1;
        my $arguments = $2;
        get_response(lc($command), $chat_id, $arguments);
        return;
    }

    get_response(lc($msg), $chat_id);
}

sub send_ws_response {
    my ($resp, $chat_id) = @_;
    return if !$resp;
    $resp = decode_json($resp);
    if ($resp->{error}) {
        my $error = "*Error:* $resp->{error}->{message}";
        _send($chat_id, $error);
    } else {
        my $msg_type = $resp->{msg_type};
        $process_ws_resp->{$msg_type}->($chat_id, $resp->{$msg_type});
    }
}

sub _send {
    my ($chat_id, $response, $keyboard) = @_;
    my $reply = {
        chat_id    => $chat_id,
        text       => $response,
        parse_mode => "Markdown",
    };
    $reply->{reply_markup} = $keyboard if $keyboard;
    $ua->post(
        "$update_url" => json => $reply => sub {
            my ($agent, $tx) = @_;
            #To do retry on error
            #print Dumper($tx->result->body);
        });
}

sub send_un_authenticated_msg {
    my $chat_id  = shift;
    my $response = "You need to authenticate first. \nUse `/authorize <token>` to authenticate" . "\nFor more info on how to get token try `/start`.";
    _send($chat_id, $response);
}

1;
