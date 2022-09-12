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
    return $self;
}

sub commit {
    my ($self, $commit, $fparent, @oparents) = @_;
    $self->{commit} = $commit;
    $self->{fparent} = $fparent;
    $self->{oparents} = \@oparents;
    my $column = $self->{column} //= Tree::CommitGraph::State->new();
    my $nextcolumn = $self->{nextcolumn} //= Tree::CommitGraph::State->new();
    if (!defined $column->{$commit}) {
        $column->{$commit} = $self->firstAvailableColumn($column->values, $nextcolumn->values);
        if (defined $fparent) {
            $nextcolumn->{$commit} = $column->{$commit};
        }
    }
    my $nextnextcolumn;
    if (defined $fparent) {
        if (!defined $column->{$fparent}) {
            $column->{$fparent} = $column->{$commit};
            $nextcolumn->{$fparent} = $column->{$commit};
        } else {
            my ($dominator, $submittor) = $self->{archy}->dominator($commit, $fparent);
            if (defined $dominator) {
                print("# $dominator dominates $submittor\n");
                $nextcolumn->{$commit}  = $column->{$dominator};
                $nextcolumn->{$fparent} = $column->{$dominator};
            } else {
                print("# $commit vs $fparent\n");
                my $min = min($column->{$commit}, $column->{$fparent});
                $nextcolumn->{$commit}  = $min;
                $nextcolumn->{$fparent} = $min;
            }
            if ($nextcolumn->{$commit} != $column->{$commit}) {
                $nextnextcolumn = $nextcolumn->clone();
                $nextcolumn->{$commit} = $column->{$commit}; # intermediate state
            }
        }
        foreach my $oparent (@oparents) {
            if (!defined $column->{$oparent}) {
                $column->{$oparent} = $column->{$commit};
                $nextcolumn->{$oparent} = $self->firstAvailableColumn($column->values, $nextcolumn->values);
            } else {
                $nextcolumn->{$oparent} = $column->{$oparent};
            }
        }
    } else {
        delete $nextcolumn->{$commit};
    }
    if (defined $fparent) {
        $self->{archy}->addRelations($fparent, @oparents);
        $self->{archy}->replaceRelations($commit, $fparent);
    }

    # print($column->toString() . "\n") if defined $column;
    # print($nextcolumn->toString() . "\n") if defined $nextcolumn;
    # print($nextnextcolumn->toString() . "\n") if defined $nextnextcolumn;

    # orphans
    if (defined $self->{orphaned} && $self->{orphaned} == $column->{$commit}) {
        $self->{printer}->graph(verticals($column,
                                          $nextcolumn,
                                          exclude => $column->{$commit}));
        $self->{printer}->text('');
    }
    if (!defined $fparent) {
        $self->{orphaned} = $column->{$commit};
    }

    $self->{printer}->graph(verticals($column,
                                      $nextcolumn,
                                      mark => $column->{$commit}));
    $self->{printer}->graph(diagonals($column,
                                      $nextcolumn,
                                      currentcolumn => $column->{$commit}));
    if (defined $nextnextcolumn) {
        $self->{printer}->graph(diagonals($nextcolumn, $nextnextcolumn,
                                          currentcolumn => $nextcolumn->{$commit}));
    }
    delete $column->{$commit};
    delete $nextcolumn->{$commit};
    delete $nextnextcolumn->{$commit} if defined $nextnextcolumn;
    %{$column} = %{$nextnextcolumn // $nextcolumn};
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
