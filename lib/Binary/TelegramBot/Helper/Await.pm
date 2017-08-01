package Binary::TelegramBot::Helper::Await;

use Exporter qw(import);
use Mojo::IOLoop;
use Binary::TelegramBot::WSBridge qw(send_ws_request);
use Data::Dumper;

our @EXPORT_OK = qw(await_response);

sub await_response {
    my ($future) = @_;
    my $loop     = Mojo::IOLoop->new;
    my $delay    = Mojo::IOLoop->delay;
    my $end = $delay->begin;    
    # Fail future if no response within 5 seconds.
    my $timer = $loop->timer(
        5 => sub {
            $future->fail("Timed out.");
            $end->();
        });
    $future->on_ready(
        sub {
            $loop->remove($timer);
            $end->();
        });
    $delay->wait;
    return $future->get;
}

1;
