package Tree::CommitGraph::State;
use warnings;
use strict;

sub new {
    my ($class, %args) = @_;
    my $self = bless({}, $class);
    my $source = $args{source};
    if (defined $source) {
        %$self = %$source;
    }
    return $self;
}

sub set {
    my ($self, $commit, $column) = @_;
    $self->{$commit} = $column;
}

sub get {
    my ($self, $commit) = @_;
    return $self->{$commit};
}

sub keys {
    my ($self) = @_;
    return keys %$self;
}

sub values {
    my ($self) = @_;
    return values %$self;
}

sub clone {
    my ($self) = @_;
    return __PACKAGE__->new(source => $self);
}

sub toString {
    my ($self) = @_;
    my @keys = $self->keys;
    @keys = sort @keys;
    return "$self " . join('; ', map { "$_ => $self->{$_}" } @keys);
}

1;
