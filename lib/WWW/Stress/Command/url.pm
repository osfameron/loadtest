package WWW::Stress::Command::url;
use Moose;
extends 'WWW::Stress::Command';

has 'url' => (
    isa      => 'Str',
    is       => 'rw',
    required => 1,
);
has 'expect' => (
    isa         => 'Maybe[Str]',
    is          => 'rw',
);

sub on_error {
    my ($self, $response, $id) = @_;

    warn sprintf "($id) ERROR %s (%d) %s\n",
        $response->message,
        $response->code,
        $self->url;
}

sub get_response {
    my $self = shift;
    my $ua = $self->_ua;
    my $resp = $ua->get($self->url);
    # warn $resp->decoded_content;
    return $resp;
}

1;
