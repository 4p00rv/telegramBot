use Data::Dumper;
use Mojolicious::Lite;
use Mojo::Log;

app->config(hypnotoad => {listen => ['http://*:3000']});
my $log = Mojo::Log->new(
    path  => 'bin/mojo.log',
    level => 'warn'
);

sub listener {
    any '/telegram' => sub {
        my $self = shift;
        my $req  = $self->req;
        $log->warn(Dumper($req));
        $self->render(text => "Ok");
    };

    app->start;
}

listener();
