package Tree::CommitGraph::2;
use warnings;
use strict;

use List::Util qw(min max);
use Data::Dumper qw(Dumper);

use lib "../..";
use Tree::CommitGraph::CommitArchy;
use Tree::CommitGraph::State;
use Tree::CommitGraph::GraphLines;
use Tree::CommitGraph::Printer;

sub new {
    my ($class) = @_;
    my $self = bless({}, $class);
    $self->{archy} = Tree::CommitGraph::CommitArchy->new();
    $self->{printer} = Tree::CommitGraph::Printer->new();
    $self->{graphlines} = Tree::CommitGraph::GraphLines->new();
    return $self;
}

sub commit {
    my ($self, $commit, $firstParent, @otherParents) = @_;
    $self->{commit} = $commit;
    $self->{firstParent} = $firstParent;
    $self->{otherParents} = \@otherParents;
    my $thisState = $self->{thisState} //= Tree::CommitGraph::State->new();
    my $nextState = $self->{nextState} //= Tree::CommitGraph::State->new();
    if (!defined $thisState->getColumn($commit)) {
        $thisState->setColumn($commit, $self->firstAvailableColumn($thisState->values, $nextState->values));
        if (defined $firstParent) {
            $nextState->setColumn($commit, $thisState->getColumn($commit));
        }
    }
    my $nextNextState;
    if (defined $firstParent) {
        if (!defined $thisState->getColumn($firstParent)) {
            $thisState->setColumn($firstParent, $thisState->getColumn($commit));
            $nextState->setColumn($firstParent, $thisState->getColumn($commit));
        } else {
            my ($dominator, $submittor) = $self->{archy}->dominator($commit, $firstParent);
            if (defined $dominator) {
                $nextState->setColumn($commit,  $thisState->getColumn($dominator));
                $nextState->setColumn($firstParent, $thisState->getColumn($dominator));
            } else {
                my $min = min($thisState->getColumn($commit), $thisState->getColumn($firstParent));
                $nextState->setColumn($commit, $min);
                $nextState->setColumn($firstParent, $min);
            }
            if ($nextState->getColumn($commit) != $thisState->getColumn($commit)) {
                $nextNextState = $nextState->clone();
                $nextState->setColumn($commit, $thisState->getColumn($commit)); # intermediate state
            }
        }
        foreach my $otherParent (@otherParents) {
            if (!defined $thisState->getColumn($otherParent)) {
                $thisState->setColumn($otherParent, $thisState->getColumn($commit));
                $nextState->setColumn($otherParent, $self->firstAvailableColumn($thisState->values, $nextState->values));
            } else {
                $nextState->setColumn($otherParent, $thisState->getColumn($otherParent));
            }
        }
    } else {
        $nextState->deleteColumn($commit);
    }
    if (defined $firstParent) {
        $self->{archy}->addRelations($firstParent, @otherParents);
        $self->{archy}->replaceRelations($commit, $firstParent);
    }

    my $thisColumn = $thisState->getColumn($commit);

    # orphans
    if (defined $self->{orphaned} && $self->{orphaned} == $thisColumn) {
        $self->graphlines($self->verticals($thisState, $nextState, exclude => $thisColumn));
        $self->textlines('');
    }
    if (!defined $firstParent) {
        $self->{orphaned} = $thisColumn;
    } else {
        delete $self->{orphaned};
    }

    $self->graphlines($self->verticals($thisState, $nextState, mark => $thisColumn));
    $self->graphlines($self->diagonals($thisState, $nextState, currentcolumn => $thisColumn));
    if (defined $nextNextState) {
        $self->graphlines($self->diagonals($nextState, $nextNextState, currentcolumn => $nextState->getColumn($commit)));
    }
    $thisState->deleteColumn($commit);
    $nextState->deleteColumn($commit);
    $nextNextState->deleteColumn($commit) if defined $nextNextState;
    $thisState->setfrom($nextNextState // $nextState);
}

# delegates
sub verticals { my ($self, @args) = @_; return $self->{graphlines}->verticals(@args); }
sub diagonals { my ($self, @args) = @_; return $self->{graphlines}->diagonals(@args); }

sub firstAvailableColumn {
    my ($self, @columns) = @_;
    my %columns = map { ($_ => 1) } @columns;
    for (my $i = 0; ; $i += 1) {
        return $i if !$columns{$i};
    }
}

sub graphlines {
    my ($self, @lines) = @_;
    $self->{printer}->graph(@lines);
    $self->{printer}->out();
}

sub textlines {
    my ($self, @lines) = @_;
    $self->{printer}->text(@lines);
    $self->{printer}->out();
}

sub flush {
    my ($self) = @_;
    $self->{printer}->flush();
}

1;
