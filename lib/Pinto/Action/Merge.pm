# ABSTRACT: Merge packages from one stack into another

package Pinto::Action::Merge;

use Moose;
use MooseX::Types::Moose qw(Bool);

use Pinto::Types qw(StackName);

use namespace::autoclean;

#------------------------------------------------------------------------------

# VERSION

#------------------------------------------------------------------------------

extends qw( Pinto::Action );

#------------------------------------------------------------------------------

with qw( Pinto::Role::Committable );

#------------------------------------------------------------------------------

has from_stack => (
    is       => 'ro',
    isa      => StackName,
    required => 1,
    coerce   => 1,
);


has to_stack => (
    is       => 'ro',
    isa      => StackName,
    required => 1,
    coerce   => 1,
);

#------------------------------------------------------------------------------

sub execute {
    my ($self) = @_;

    my $from_stack = $self->repos->get_stack(name => $self->from_stack);
    my $to_stack   = $self->repos->open_stack(name => $self->to_stack);

    $self->notice("Merging stack $from_stack into stack $to_stack");

    $from_stack->merge(to => $to_stack);
    $self->result->changed if $to_stack->refresh->has_changed;

    if ($to_stack->has_changed and not $self->dryrun) {
        my $message = $self->edit_message(stacks => [$to_stack]);
        $to_stack->close(message => $message);
        $self->repos->write_index(stack => $to_stack);
    }

    return $self->result;
}

#------------------------------------------------------------------------------

sub message_primer {
    my ($self) = @_;

    my $from_stack = $self->from_stack;
    my $to_stack   = $self->to_stack;

    return "Merged stack $from_stack into stack $to_stack.";
}

#------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#------------------------------------------------------------------------------
1;

__END__
