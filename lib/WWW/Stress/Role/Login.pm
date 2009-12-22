package WWW::Stress::Role::Login;
use Moose::Role;

requires '_ua';

has login_url => (
    isa      => 'Str',
    is       => 'rw',
    required => 1,
);
has username => (
    isa      => 'Str',
    is       => 'rw',
    required => 1,
);
has password => (
    isa      => 'Str',
    is       => 'rw',
    required => 1,
);
has form_spec => (
    isa     => 'HashRef',
    is      => 'rw',
    default => sub { +{ form_name => 'login' } }, # button => 'login' etc.
);
has form_fields => (  # login
    isa     => 'HashRef',
    is      => 'rw',
    default => sub { +{} },
);

sub form_field {
    my ($self, $field) = @_;
    return $self->form_fields->{$field} || $field;
}

before execute => sub {
    my ($self, $opt, $args) = @_;

    my $ua = $self->_ua;

    my $response = $ua->get($self->login_url);
    die "Couldn't retrieve login form" unless $response->is_success;

    my $form_response = $ua->submit_form(
        %{ $self->form_spec },
        fields => {
            $self->form_field('username') => $self->username,
            $self->form_field('password') => $self->password,
        },
    );

    unless (my $success = $self->check_login_success($form_response)) {
        die sprintf "Couldn't login as %s!", $self->username;
    }
};

sub check_login_success {
    my ($self, $response) = @_;

    # assume that successful login has 200 response
    # class should override this if, for example, failure is also 200, and
    # have to check what's in content instead...

    return 0 if $response->decoded_content =~ /incorrect/;

    return $response->is_success;
}

1;
