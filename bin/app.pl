use Data::Dumper;
use Binary::TelegramBot::GetUpdates qw(get_periodic_updates);
use Binary::TelegramBot::TelegramCommandHandler qw(process_message);

sub start_bot {
    get_periodic_updates(
        sub {
            my $messages = shift;
            foreach (@$messages) {
                my $msg = $_->{callback_query}->{data} || $_->{message}->{text};
                my $chat_id = $_->{callback_query}->{message}->{chat}->{id} || $_->{message}->{chat}->{id};
                process_message($chat_id, $msg);
            }
        });
}

start_bot();
