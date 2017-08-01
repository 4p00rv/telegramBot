use strict;
use warnings;

use Test::More "no_plan";
use Binary::TelegramBot::Modules::Trade qw(get_trade_type);

sub start {
    test1();
}

sub test1 {
    my $resp = Binary::TelegramBot::Modules::Trade::get_trade_type("DIGITMATCH");
    ok($resp eq "Trade type: Digit Matches\n") or "Wrong return value for get_trade_type";
    $resp = Binary::TelegramBot::Modules::Trade::get_trade_type("DIGITMATCH_5");
    ok($resp eq "Trade type: Digit Matches\nBarrier: 5\n") or "Wrong return value for get_trade_type with barrier";
}

start();
