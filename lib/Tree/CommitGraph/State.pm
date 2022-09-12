package Tree::CommitGraph::State;
use warnings;
use strict;

sub new {
    my ($class, %args) = @_;
    my $self = bless({}, $class);
    my $source = $args{source};
    if (defined $source) {
        %{$self->hashref} = %{$source->hashref};
    }
    return $self;
}

sub hashref {
    my ($self) = @_;
    return $self->{commit} //= {};
}

sub setfrom {
    my ($self, $source) = @_;
    %{$self->hashref} = %{$source->hashref};
}

sub set {
    my ($self, $commit, $column) = @_;
    $self->hashref->{$commit} = $column;
}

sub get {
    my ($self, $commit) = @_;
    return $self->hashref->{$commit};
}

sub delete {
    my ($self, $commit) = @_;
    delete $self->hashref->{$commit};
}

sub keys {
    my ($self) = @_;
    return keys %{$self->hashref};
}

sub values {
    my ($self) = @_;
    return values %{$self->hashref};
}

sub clone {
    my ($self) = @_;
    return __PACKAGE__->new(source => $self);
}

sub toString {
    my ($self) = @_;
    my @keys = $self->keys;
    @keys = sort @keys;
    return "$self " . join('; ', map { "$_ => " . $self->hashref->{$_} } @keys);
}

1;