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
    if (!defined $thisstate->get($commit)) {
        $thisstate->set($commit, $self->firstAvailableColumn($thisstate->values, $nextstate->values));
        if (defined $fparent) {
            $nextstate->set($commit, $thisstate->get($commit));
        }
    }
    my $nextnextstate;
    if (defined $fparent) {
        if (!defined $thisstate->get($fparent)) {
            $thisstate->set($fparent, $thisstate->get($commit));
            $nextstate->set($fparent, $thisstate->get($commit));
        } else {
            my ($dominator, $submittor) = $self->{archy}->dominator($commit, $fparent);
            if (defined $dominator) {
                $nextstate->set($commit,  $thisstate->get($dominator));
                $nextstate->set($fparent, $thisstate->get($dominator));
            } else {
                my $min = min($thisstate->get($commit), $thisstate->get($fparent));
                $nextstate->set($commit, $min);
                $nextstate->set($fparent, $min);
            }
            if ($nextstate->get($commit) != $thisstate->get($commit)) {
                $nextnextstate = $nextstate->clone();
                $nextstate->set($commit, $thisstate->get($commit)); # intermediate state
            }
        }
        foreach my $oparent (@oparents) {
            if (!defined $thisstate->get($oparent)) {
                $thisstate->set($oparent, $thisstate->get($commit));
                $nextstate->set($oparent, $self->firstAvailableColumn($thisstate->values, $nextstate->values));
            } else {
                $nextstate->set($oparent, $thisstate->get($oparent));
            }
        }
    } else {
        $nextstate->delete($commit);
    }
    if (defined $fparent) {
        $self->{archy}->addRelations($fparent, @oparents);
        $self->{archy}->replaceRelations($commit, $fparent);
    }

    # orphans
    if (defined $self->{orphaned} && $self->{orphaned} == $thisstate->get($commit)) {
        $self->{printer}->graph($self->{graphlines}->verticals(
            $thisstate,
            $nextstate,
            exclude => $thisstate->get($commit)
        ));
        $self->{printer}->text('');
    }
    if (!defined $fparent) {
        $self->{orphaned} = $thisstate->get($commit);
    }

    $self->{printer}->graph($self->{graphlines}->verticals(
        $thisstate,
        $nextstate,
        mark => $thisstate->get($commit)
    ));
    $self->{printer}->graph($self->{graphlines}->diagonals(
        $thisstate,
        $nextstate,
        currentcolumn => $thisstate->get($commit)
    ));
    if (defined $nextnextstate) {
        $self->{printer}->graph($self->{graphlines}->diagonals(
            $nextstate, $nextnextstate,
            currentcolumn => $nextstate->get($commit)
        ));
    }
    $thisstate->delete($commit);
    $nextstate->delete($commit);
    $nextnextstate->delete($commit) if defined $nextnextstate;
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
