use Data::Dumper;
use Mojolicious::Lite;

app->config(hypnotoad => {listen => ['http://*:3000']});

sub listener {
    get '/telegram' => sub {
        my $self = shift;
        my $req = $self->req;
        print Dumper($req->content) . "\n";
        $self->render( text => "Ok");
    };
    get '/' => sub {
        my $self = shift;
        my $req = $self->req;
        print Dumper($req->content) . "\n";
        $self->render( text => "Ok");
    };
    app->start;
}

listener();
