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
    my $column = $self->{column} //= Tree::CommitGraph::State->new();
    my $nextcolumn = $self->{nextcolumn} //= Tree::CommitGraph::State->new();
    if (!defined $column->get($commit)) {
        $column->set($commit, $self->firstAvailableColumn($column->values, $nextcolumn->values));
        if (defined $fparent) {
            $nextcolumn->set($commit, $column->get($commit));
        }
    }
    my $nextnextcolumn;
    if (defined $fparent) {
        if (!defined $column->get($fparent)) {
            $column->set($fparent, $column->get($commit));
            $nextcolumn->set($fparent, $column->get($commit));
        } else {
            my ($dominator, $submittor) = $self->{archy}->dominator($commit, $fparent);
            if (defined $dominator) {
                $nextcolumn->set($commit,  $column->get($dominator));
                $nextcolumn->set($fparent, $column->get($dominator));
            } else {
                my $min = min($column->get($commit), $column->get($fparent));
                $nextcolumn->set($commit, $min);
                $nextcolumn->set($fparent, $min);
            }
            if ($nextcolumn->get($commit) != $column->get($commit)) {
                $nextnextcolumn = $nextcolumn->clone();
                $nextcolumn->set($commit, $column->get($commit)); # intermediate state
            }
        }
        foreach my $oparent (@oparents) {
            if (!defined $column->get($oparent)) {
                $column->set($oparent, $column->get($commit));
                $nextcolumn->set($oparent, $self->firstAvailableColumn($column->values, $nextcolumn->values));
            } else {
                $nextcolumn->set($oparent, $column->get($oparent));
            }
        }
    } else {
        $nextcolumn->delete($commit);
    }
    if (defined $fparent) {
        $self->{archy}->addRelations($fparent, @oparents);
        $self->{archy}->replaceRelations($commit, $fparent);
    }

    # orphans
    if (defined $self->{orphaned} && $self->{orphaned} == $column->get($commit)) {
        $self->{printer}->graph($self->{graphlines}->verticals(
            $column,
            $nextcolumn,
            exclude => $column->get($commit)
        ));
        $self->{printer}->text('');
    }
    if (!defined $fparent) {
        $self->{orphaned} = $column->get($commit);
    }

    $self->{printer}->graph($self->{graphlines}->verticals(
        $column,
        $nextcolumn,
        mark => $column->get($commit)
    ));
    $self->{printer}->graph($self->{graphlines}->diagonals(
        $column,
        $nextcolumn,
        currentcolumn => $column->get($commit)
    ));
    if (defined $nextnextcolumn) {
        $self->{printer}->graph($self->{graphlines}->diagonals(
            $nextcolumn, $nextnextcolumn,
            currentcolumn => $nextcolumn->get($commit)
        ));
    }
    $column->delete($commit);
    $nextcolumn->delete($commit);
    $nextnextcolumn->delete($commit) if defined $nextnextcolumn;
    $column->setfrom($nextnextcolumn // $nextcolumn);
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
