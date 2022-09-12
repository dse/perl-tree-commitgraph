package Tree::CommitGraph::CommitArchy;
use warnings;
use strict;

sub new {
    my ($class) = @_;
    my $self = bless({}, $class);
    return $self;
}

sub addRelations {
    my ($self, $dominator, @submittor) = @_;
    # print("# addRelations $dominator @submittor\n");
    my $dominates = $self->{dominates} //= {};
    foreach my $submittor (@submittor) {
        next if eval { $dominates->{$submittor}->{$dominator} };
        $dominates->{$dominator}->{$submittor} = 1;
        # print("# $dominator defats $submittor\n");
    }
    # $self->print();
}

sub replaceRelations {
    my ($self, $old, $new) = @_;
    # print("# replaceRelations $old $new\n");
    my $dominates = $self->{dominates} //= {};
    foreach my $submittor (keys %{$dominates->{$old}}) {
        next if eval { $dominates->{$submittor}->{$new} };
        if ($new ne $submittor) {
            $dominates->{$new}->{$submittor} = 1;
            # print("# $new defats $submittor\n");
        }
    }
    delete $dominates->{$old};
    foreach my $dominator (keys %$dominates) {
        next if !eval { $dominates->{$dominator}->{$old} };
        next if  eval { $dominates->{$new}->{$dominator} };
        if ($new ne $dominator) {
            $dominates->{$dominator}->{$new} = 1;
            # print("# $dominator defats $new\n");
        }
        delete $dominates->{$dominator}->{$old};
    }
    # $self->print();
}

sub print {
    my ($self) = @_;
    print("# =>");
    my $dominates = $self->{dominates};
    foreach my $dom (keys %$dominates) {
        foreach my $sub (keys %{$dominates->{$dom}}) {
            print(" $dom $sub;");
        }
    }
    print("\n");
};

sub dominator {
    my ($self, $a, $b) = @_;
    my $dominates = $self->{dominates} //= {};
    if (eval { $dominates->{$a}->{$b} }) {
        return ($a, $b) if wantarray;
        return $a;
    }
    if (eval { $dominates->{$b}->{$a} }) {
        return ($b, $a) if wantarray;
        return $b;
    }
    return;
}

1;
