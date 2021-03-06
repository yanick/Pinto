# ABSTRACT: Force a package to stay in a stack

package Pinto::Action::Pin;

use Moose;

use Pinto::Types qw(Specs StackName StackDefault);
use Pinto::Exception qw(throw);

use namespace::autoclean;

#------------------------------------------------------------------------------

# VERSION

#------------------------------------------------------------------------------

extends qw( Pinto::Action );

#------------------------------------------------------------------------------

with qw( Pinto::Role::Committable );

#------------------------------------------------------------------------------

has stack => (
    is        => 'ro',
    isa       => StackName | StackDefault,
    default   => undef,
    coerce    => 1
);


has targets => (
    isa      => Specs,
    traits   => [ qw(Array) ],
    handles  => {targets => 'elements'},
    required => 1,
    coerce   => 1,
);

#------------------------------------------------------------------------------

sub execute {
    my ($self) = @_;

    my $stack = $self->repos->open_stack(name => $self->stack);
    $self->_pin($_, $stack) for $self->targets;

    if ($self->result->made_changes and not $self->dryrun) {
        my $message = $self->edit_message(stacks => [$stack]);
        $stack->close(message => $message);
    }

    return $self->result;
}

#------------------------------------------------------------------------------

sub _pin {
    my ($self, $spec, $stack) = @_;

    my $dist = $self->repos->get_distribution_by_spec(spec => $spec, stack => $stack);

    $self->fatal("$spec does not exist in the repository") if not $dist;

    $self->notice("Pinning distribution $dist to stack $stack");

    $self->result->changed if $dist->pin(stack => $stack);

    return;
}

#------------------------------------------------------------------------------

sub message_primer {
    my ($self) = @_;

    my $targets  = join ', ', $self->targets;

    return "Pinned ${targets}.";
}

#------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

#------------------------------------------------------------------------------

1;

__END__
