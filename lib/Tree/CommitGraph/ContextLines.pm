package Tree::CommitGraph::ContextLines;
use warnings;
use strict;

sub new {
    my ($class) = @_;
    my $self = bless({}, $class);
    $self->{contextLines} //= 3;
    $self->{contextLineCount} = 0;
    $self->[queue] = [];
    return $self;
}

sub addLine {
    my ($self, $line, $isChange) = @_;
    if ($isChange) {
        $self->{contextLineCount} += 1;
        if ($self->{contextLineCount} <= $self->{contextLines}) {
            print("$line\n");
        } else {
            push(@{$self->{queue}}, $line);
            if ($self->{contextLineCount} == 2 + $self->{contextLines} * 2) {
                print("...\n");
            }
            if (scalar @{$self->{queue}} > $self->{contextLines}) {
                splice(@{$self->{queue}}, 0, -$self->{contextLines});
            }
        }
    } else {
        foreach my $lineq (@{$self->{queue}}) {
            print("$lineq\n");
        }
        @{$self->{queue}} = ();
        print("$line\n");
    }
}

sub end {
    my ($self) = @_;
    if ($self->{contextLineCount} > 0 && $self->{contextLineCount} < 2 + $self->{contextLines} * 2) {
        print("...\n");
    }
}

1;
