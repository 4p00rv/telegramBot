use Data::Dumper;
use Binary::TelegramBot::SendMessage;
use Binary::TelegramBot::GetUpdates;
use Binary::TelegramBot::WSBridge;

sub start_bot {
    get_periodic_updates(
        sub {
            my $messages = shift;
            foreach (@$messages) {
                send_message($_->{message}->{text}, $_->{message}->{chat}->{id});
            }
        });
}

start_bot();
