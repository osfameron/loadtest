package WWW::Stress::Command;
use Moose;
extends 'MooseX::App::Cmd::Command';
with 'MooseX::SimpleConfig';

use Parallel::ForkManager;
use WWW::Mechanize;
use Time::HiRes qw/ sleep time /;
use Text::SimpleTable;

use feature 'say';

our $VERSION = 0.01;

has configfile => (
    isa     => 'Str',
    is      => 'rw',
    default => 'www-stress.conf',
);

has 'max_processes' => (
    traits      => ['Getopt'],
    cmd_aliases => 'p', # 'c' seems to be taken by --configfile
    isa         => 'Int',
    is          => 'rw',
    default     => 1,
);

has 'num_processes' => (
    traits      => ['Getopt'],
    cmd_aliases => 'n',
    isa         => 'Int',
    is          => 'rw',
    default     => 1,
);

has 'time_between_requests' => ( # in fractional seconds
    traits      => ['Getopt'],
    cmd_aliases => 't',
    isa         => 'Num',
    is          => 'rw',
    default     => 1,
);

has 'user_agent' => (
    isa     => 'Str',
    is      => 'rw',
    default => "WWW-Stress/$VERSION",
);

has '_ua' => (
    isa     => 'WWW::Mechanize',
    is      => 'rw',
    lazy    => 1,
    default => sub 
        { 
            my $self = shift;
            WWW::Mechanize->new( 
                agent     => $self->user_agent,
                autocheck => 0,
             ) 
        },
);
has '_pm' => (
    isa     => 'Parallel::ForkManager',
    is      => 'rw',
    lazy    => 1,
    default => sub 
        { 
            my $self = shift;
            Parallel::ForkManager->new( $self->max_processes );
        },
);

has requests => (
    traits  => ['Array'],
    isa     => 'ArrayRef[HashRef]',
    is      => 'rw',
    default => sub { [] },
    handles => {
        set_request  => 'set',
        get_request  => 'get',
        all_requests => 'elements',
    },
);

has table => (
    traits  => ['Array'],
    is  => 'rw',
    isa => 'ArrayRef[HashRef]',
    handles => {
        all_columns => 'elements',
    },
    default => sub {
        [
            {
                width => 5,
                label => 'Id',
                field => 'id',
            },
            {
                width => 20,
                label => 'Time taken',
                field => 'delta',
            },
            {
                width => 10,
                label => 'Exit code',
                field => 'exit_code',
            },
        ],
    },
);

sub get_runner {
    my ($self, $id) = shift;
    return $self; # to be overridden, e.g. in ::table
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $ua = $self->_ua;
    my $pm = $self->_pm;

    $pm->run_on_finish( sub { $self->run_on_finish(@_) } );
    $pm->run_on_start ( sub { $self->run_on_start (@_) } );
    # see also run_on_wait
    
    for my $id (1.. $self->num_processes) {
        my $runner = $self->get_runner;
        my $pid = $pm->start($id) and do {
            sleep $self->time_between_requests;
            next;
            };
        $runner->setup;
        my $response = $runner->get_response;

        if ($response->is_error) {
            $runner->on_error($response, $id);
            $pm->finish(0); # failure
        } else {
            my $status = $runner->process_response($id, $response);

            $runner->teardown($status);
            $pm->finish($status);
        }
    }

    $pm->wait_all_children;

    my (undef, @requests) = $self->all_requests;

    my @columns = $self->all_columns;
    my $table = Text::SimpleTable->new(
        map { [ $_->{width}, $_->{label} ] }
            @columns
    );

    for my $request (@requests) {
        $table->row( @{$request}{ map $_->{field}, @columns } );
    }

    say $table->draw;
}

sub setup    { warn "SETUP"    }
sub teardown { warn "TEARDOWN" }

sub on_error {
    my ($self, $response, $id) = @_;
    warn sprintf "($id) ERROR %s (%d)\n", 
        $response->message, 
        $response->code;
}

after on_error => sub { my $self = shift; $self->teardown(0) };

sub get_response {
    my $self = shift;
    die "Abstract method get_response called";
}

sub process_response {
    my ($self, $id, $response) = @_;
    my $content_type = $response->header('content-type');

    warn "($id) Content-type: $content_type\n";

    if (my $expect = $self->expect) {
        unless ($content_type eq $expect) {
            warn "($id) ERROR!  Wrong content-type, expected $expect, got $content_type";
            return 0;
        }
    }

    return length $response->decoded_content; 
        # e.g. so user can check file is nonzero size
}

sub run_on_start {
    my ($self, $pid, $id) = @_;

    my $time = time();

    $self->set_request($id => {
        start => $time,
        id    => $id,
        pid   => $pid,
    });

    warn "($id) Started $pid";
}

sub run_on_finish {
    my ($self, $pid, $exit_code, $id) = @_;

    my $time = time();
    my $request = $self->get_request($id);
    my $delta = $time - $request->{start};

    $request->{end}       = $time;
    $request->{delta}     = $delta;
    $request->{exit_code} = $exit_code;

    warn "($id) Finished in $delta ($exit_code)";
}

1;
