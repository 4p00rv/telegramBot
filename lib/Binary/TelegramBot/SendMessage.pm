package Binary::TelegramBot::SendMessage;

use strict;
use warnings;

use Mojo::UserAgent;
use Exporter qw(import);
use Data::Dumper;
use JSON qw(decode_json);

# This should be used for only communicating with telegram.

our @EXPORT = qw(send_message);

my $ua         = Mojo::UserAgent->new;
my $token      = $ENV{'TELEGRAM_BOT'};
my $update_url = "https://api.telegram.org/bot$token/sendMessage";

sub send_message {
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
            #todo better error handling.
            my $result = decode_json($tx->result->body);
            if ($result->{error_code}) {
                print "$result->{description}\n";
            }
        });
}

1;
