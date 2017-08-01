package Binary::TelegramBot::GetUpdates;

use strict;
use warnings;

use Mojo::UserAgent;
use Mojo::IOLoop;
use JSON qw( decode_json );
use Data::Dumper;
use Exporter qw(import);

our @EXPORT = qw(get_periodic_updates);

my $token              = $ENV{'TELEGRAM_BOT'};
my $update_url         = "https://api.telegram.org/bot$token/getUpdates";
my $ua                 = Mojo::UserAgent->new;
my $processed_messages = {};
my $last_update_id     = undef;

$ua = $ua->inactivity_timeout(0);

sub get_updates {
    $update_url = $last_update_id ? $update_url . "?offset=" . ($last_update_id + 1) : $update_url;
    my $response = $ua->get($update_url)->result;
    if ($response->is_error) {
        print "ErrorCode::" . $response->error->{code} . "\n";
        return;
    }

    my $result   = decode_json($response->body);
    my $messages = [];

    for (@{$result->{result}}) {
        my $update_id = $_->{update_id};
        if (!$processed_messages->{$update_id}) {
            push $messages, $_;
            $processed_messages->{$update_id} = 1;
            $last_update_id = $update_id;
        }
    }
    return $messages;
}

sub get_periodic_updates {
    my $callback = shift;
    if (!$callback) {
        return;
    }
    # while (1) {
    #     my $messages = get_updates();
    #     $callback->($messages) if ($messages && scalar @$messages);
    #     sleep(1);
    # }
    Mojo::IOLoop->recurring(
        1 => sub {
            my $messages = get_updates();
            $callback->($messages) if ($messages && scalar @$messages);
        });

    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

1;
