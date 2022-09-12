package Tree::CommitGraph::2;
use warnings;
use strict;

use List::Util qw(min max);
use Data::Dumper qw(Dumper);

use lib "../..";
use Tree::CommitGraph::CommitArchy;
use Tree::CommitGraph::State;
use Tree::CommitGraph::GraphLines qw(verticals diagonals);
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
    my ($self, $commit, $fparent, @oparents) = @_;
    $self->{commit} = $commit;
    $self->{fparent} = $fparent;
    $self->{oparents} = \@oparents;
    my $thisstate = $self->{column} //= Tree::CommitGraph::State->new();
    my $nextstate = $self->{nextcolumn} //= Tree::CommitGraph::State->new();
    if (!defined $thisstate->getColumn($commit)) {
        $thisstate->setColumn($commit, $self->firstAvailableColumn($thisstate->values, $nextstate->values));
        if (defined $fparent) {
            $nextstate->setColumn($commit, $thisstate->getColumn($commit));
        }
    }
    my $nextnextstate;
    if (defined $fparent) {
        if (!defined $thisstate->getColumn($fparent)) {
            $thisstate->setColumn($fparent, $thisstate->getColumn($commit));
            $nextstate->setColumn($fparent, $thisstate->getColumn($commit));
        } else {
            my ($dominator, $submittor) = $self->{archy}->dominator($commit, $fparent);
            if (defined $dominator) {
                $nextstate->setColumn($commit,  $thisstate->getColumn($dominator));
                $nextstate->setColumn($fparent, $thisstate->getColumn($dominator));
            } else {
                my $min = min($thisstate->getColumn($commit), $thisstate->getColumn($fparent));
                $nextstate->setColumn($commit, $min);
                $nextstate->setColumn($fparent, $min);
            }
            if ($nextstate->getColumn($commit) != $thisstate->getColumn($commit)) {
                $nextnextstate = $nextstate->clone();
                $nextstate->setColumn($commit, $thisstate->getColumn($commit)); # intermediate state
            }
        }
        foreach my $oparent (@oparents) {
            if (!defined $thisstate->getColumn($oparent)) {
                $thisstate->setColumn($oparent, $thisstate->getColumn($commit));
                $nextstate->setColumn($oparent, $self->firstAvailableColumn($thisstate->values, $nextstate->values));
            } else {
                $nextstate->setColumn($oparent, $thisstate->getColumn($oparent));
            }
        }
    } else {
        $nextstate->deleteColumn($commit);
    }
    if (defined $fparent) {
        $self->{archy}->addRelations($fparent, @oparents);
        $self->{archy}->replaceRelations($commit, $fparent);
    }

    # orphans
    if (defined $self->{orphaned} && $self->{orphaned} == $thisstate->getColumn($commit)) {
        $self->{printer}->graph($self->{graphlines}->verticals(
            $thisstate,
            $nextstate,
            exclude => $thisstate->getColumn($commit)
        ));
        $self->{printer}->text('');
    }
    if (!defined $fparent) {
        $self->{orphaned} = $thisstate->getColumn($commit);
    }

    $self->{printer}->graph($self->{graphlines}->verticals(
        $thisstate,
        $nextstate,
        mark => $thisstate->getColumn($commit)
    ));
    $self->{printer}->graph($self->{graphlines}->diagonals(
        $thisstate,
        $nextstate,
        currentcolumn => $thisstate->getColumn($commit)
    ));
    if (defined $nextnextstate) {
        $self->{printer}->graph($self->{graphlines}->diagonals(
            $nextstate, $nextnextstate,
            currentcolumn => $nextstate->getColumn($commit)
        ));
    }
    $thisstate->deleteColumn($commit);
    $nextstate->deleteColumn($commit);
    $nextnextstate->deleteColumn($commit) if defined $nextnextstate;
    $thisstate->setfrom($nextnextstate // $nextstate);
}

sub firstAvailableColumn {
    my ($self, @columns) = @_;
    my %columns = map { ($_ => 1) } @columns;
    for (my $i = 0; ; $i += 1) {
        return $i if !$columns{$i};
    }
}

sub graph {
    my ($self, @lines) = @_;
    $self->{printer}->graph(@lines);
    $self->{printer}->out();
}

sub text {
    my ($self, @lines) = @_;
    $self->{printer}->text(@lines);
    $self->{printer}->out();
}

sub flush {
    my ($self) = @_;
    $self->{printer}->flush();
}

1;
