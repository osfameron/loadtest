package WWW::Stress::Command::table;
use Moose;
use MooseX::Types::Path::Class;
extends 'WWW::Stress::Command';
use Spreadsheet::Read qw/ReadData row/;
use List::MoreUtils qw/zip/;
use Data::Dumper;

has 'table_file' => (
    isa      => 'Path::Class::File',
    is       => 'rw',
    required => 1,
    coerce   => 1,
);

has 'spreadsheet_options' => (
    isa => 'HashRef',
    is  => 'rw',
    traits => ['Hash'],
    default => sub { {} },
    handles => {
        _spreadsheet_options => 'elements',
    },
);

has type => (
    isa => 'Maybe[Str]',
    is  => 'rw',
);

has 'runners' => (
    isa     => 'ArrayRef',
    is      => 'ro',
    lazy    => 1,
    traits => ['Array'],
    handles => {
        _runners => 'elements',
    },
    default => sub {
        my $self = shift;
        my $book = ReadData( $self->table_file, $self->_spreadsheet_options );
        my $sheet = $book->[1];
        my @header = row( $sheet, 1 );
        my %header = do {
            my $col = 0;
            map { $_ => $col++ } @header;
        };
        my $maxrow = $sheet->{maxrow};
        my @runners = map {
            my @row = row($sheet, $_);
            my %data = zip @header, @row;
            for (keys %data) {
                delete $data{$_} unless length $data{$_};
            }
            %data = (%$self, %data);
            my $type = $data{type} || 'url';
            WWW::Stress->plugin_for($type)->new(%data);
          } 2..$maxrow;
        \@runners;
    }
);

{
  my @runner_queue;
  sub get_runner {
    my $self = shift;
    @runner_queue = $self->_runners unless @runner_queue;
    shift @runner_queue;
  }
}


1;
