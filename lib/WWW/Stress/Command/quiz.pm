package WWW::Stress::Command::quiz;
use Moose;
extends 'WWW::Stress::Command';
with 'WWW::Stress::Role::Login';

use lib '/home/hakim/work/participo/repo/libs';
use Participo::Clean::Context;

has 'module_id' => (
    isa => 'Int',
    is  => 'rw',
);

has 'context' => (
    is      => 'rw',
    default => sub {
        Participo::Clean::Context->setup( config => 'partiso-www' ),
        },
);

sub setup {
    my $self = shift;

    my $db = $self->context->db;

    my $user = $db->resultset('User')
        ->search({ user_name => $self->username })
        ->first
        or die sprintf "Couldn't find user %s", $self->username;

    my $module = $db->resultset('Module')
        ->find($self->module_id)
        or die sprintf "Couldn't find module %d", $self->module_id;

    # make sure it's properly allocated (OTT?)
    my $item = $self->allocate($user, $module);
    $item->delete;
    $item = $self->allocate($user, $module); 

    warn sprintf "Allocated user_module %d", $item->id;
}

sub allocate {
    my ($self, $user, $module) = @_;
    my $item = $self->context->db->resultset('UserModules')->allocate(
        user_id   => $user->id,
        module_id => $module->id,
    );
}

sub get_response {
    my $self = shift;

    my $mech = $self->_ua;
    $mech->get(sprintf 'users.cgi?sub=to_do&module_id=%d&intro=yes', 
               $self->module_id);
    $mech->content =~ /This module will take you/ or die "Not on intro page";
    $mech->click_button( name => 'nextbutton' );

    {
        $mech->quiet(1);
        my $form = $mech->form_name('module_form');
        $mech->quiet(0);
        last unless $form;
        
        if (my $question_id = do {
            my $input = $form->find_input('question_id', 'hidden');
            $input && $input->value;
            })
        {
            my $radio = $form->find_input($question_id, 'radio');
            my @values = $radio->possible_values;
            warn "Answering question $question_id with question $values[0]";
            $mech->field($question_id => $values[0]); # set to first
            $mech->click_button( name => 'nextbutton' );
        }
        redo;
    }
    my $response = $mech->follow_link(text => 'dashboard');
    if ($mech->uri->path ne '/') {
        die sprintf "Not back on dashboard? '%s'", $mech->uri->path;
    }
    return $response;
}

sub process_response {
    my ($self, $id, $response) = @_;
    return 1 if $response->is_success;
}

1;
