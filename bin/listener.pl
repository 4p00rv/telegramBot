use Data::Dumper;
use Mojolicious::Lite;

sub listener {
    get '/' => sub {
        my $self = shift;
        my $req = $self->req;
        print Dumper($req->content) . "\n";
        $self->render( text => "Ok");
    };
    app->start;
}

listener();
