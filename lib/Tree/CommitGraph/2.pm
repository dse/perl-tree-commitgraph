package Tree::CommitGraph::2;
use warnings;
use strict;

use base 'Exporter';

use List::Util qw(min max);
use Data::Dumper qw(Dumper);

sub new {
    my ($class) = @_;
    my $self = bless({}, $class);
    return $self;
}

our %column;
our %nextcolumn;

sub commit {
    my ($self, $commit, $fparent, @oparents) = @_;
    my $legend = join(' ', grep { defined $_ } ($commit, $fparent, @oparents));
    $self->{commit} = $commit;
    $self->{fparent} = $fparent;
    $self->{oparents} = \@oparents;
    local *column = \%{$self->{column} //= {}};
    local *nextcolumn = \%{$self->{nextcolumn} //= {}};
    if (!defined $column{$commit}) {
        $column{$commit} = $self->firstAvailableColumn(%column, %nextcolumn);
    }
    $nextcolumn{$commit} = $column{$commit};
    if (defined $fparent) {
        if (!defined $column{$fparent}) {
            $nextcolumn{$fparent} = $column{$commit};
        } elsif ($column{$commit} == $column{$fparent}) {
            die("unexpected: $commit and $fparent are in the same column?\n");
        } else {
            my ($winnercommit, $winnercolumn) = $self->mergePriorityWinner($commit, $fparent);
            if (!defined $winnercommit) {
                $nextcolumn{$commit} = $column{$fparent};
                $nextcolumn{$fparent} = $column{$fparent};
            } elsif ($winnercommit eq $fparent) {
                $nextcolumn{$commit} = $column{$fparent};
                $nextcolumn{$fparent} = $column{$fparent};
            } else {
                # fparent makes a diagonal move, not the commit
                $nextcolumn{$commit} = $column{$commit};
                $nextcolumn{$fparent} = $column{$commit};
            }
        }
        foreach my $oparent (@oparents) {
            if (!defined $column{$oparent}) {
                $column{$oparent} = $column{$commit};
                $nextcolumn{$oparent} = $self->firstAvailableColumn(%column, %nextcolumn);
            } else {
                $nextcolumn{$oparent} = $column{$oparent};
            }
        }
    } else {
        delete $nextcolumn{$commit};
    }
    if (defined $fparent) {
        $self->replaceExistingMergePriorities($commit, $fparent, $column{$fparent});
        $self->addMergePriority($fparent, @oparents);
    }
    my @vert;
    my @diag;
    my %diag2;
    foreach my $c (keys %nextcolumn) {
        my $c1 = $column{$c};     next unless defined $c1;
        my $c2 = $nextcolumn{$c}; next unless defined $c2;
        if ($c1 == $c2) {
            push(@vert, $c1);
        } elsif ($c1 == $column{$commit}) {
            push(@diag, $c2);
        } else {
            push(@vert, $c1);
            $diag2{$c1}{$c2} = 1;
        }
    }
    # check for orphan
    if (defined $self->{orphaned} && $self->{orphaned} == $column{$commit}) {
        print($self->verticalLinesLine(grep { $_ != $column{$commit} } @vert));
        print("\n");
    }
    my $line = $self->verticalLinesLine(@vert);
    my $line0 = $line;          # this line
    substr($line0, $column{$commit} * 3, 1) = '*';
    $line0 .= ' ' x (max(16, 64 - length($line0)));
    $line0 .= $legend;
    print("$line0\n");
    if (scalar @diag) {
        my ($line1, $line2) = $self->applyDiagonals($line, $column{$commit}, @diag);
        print("$line1\n") if defined $line1;
        print("$line2\n") if defined $line2;
    }
    if (scalar keys %diag2) {
        foreach my $c1 (keys %diag2) {
            @vert = grep { $_ ne $c1 } @vert;
            $line = $self->verticalLinesLine(@vert);
            my ($line1, $line2) = $self->applyDiagonals($line, $c1, keys %{$diag2{$c1}});
            print("$line1\n") if defined $line1;
            print("$line2\n") if defined $line2;
        }
    }
    if (defined $fparent) {
        $self->{orphaned} = undef;
    } else {
        $self->{orphaned} = $column{$commit};
    }
    delete $column{$commit};
    delete $nextcolumn{$commit};
    %column = %nextcolumn;
}

sub firstAvailableColumn {
    my ($self, %column) = @_;
    my @columns = values(%column);
    my %columns = map { ($_ => 1) } @columns;
    for (my $i = 0; ; $i += 1) {
        return $i if !$columns{$i};
    }
}

sub verticalLinesLine {
    my ($self, @columns) = @_;
    our %column;     local *column     = \%{$self->{column} //= {}};
    our %nextcolumn; local *nextcolumn = \%{$self->{nextcolumn} //= {}};
    my $maxcolumn = max(values(%nextcolumn), values(%column));
    my $line = ' ' x ($maxcolumn * 3 + 1);
    foreach my $column (@columns) {
        substr($line, $column * 3, 1) = '|';
    }
    return $line;
}

sub applyDiagonals {
    my ($self, $line, $from, @drawto) = @_;
    my $line1 = $line;
    my $line2 = $line;
    my @left  = grep { $_ < $from } @drawto;
    my @right = grep { $_ > $from } @drawto;
    if (!scalar @left && !scalar @right) {
        return;
    }
    if (scalar @left) {
        substr($line1, 3 * $from - 1, 1) = '/';
        my $minleft = min(@drawto);
        if ($minleft <= $from - 2) {
            my $pos1 = $minleft * 3 + 2;
            my $pos2 = $from * 3 - 2;
            for (my $p = $pos1; $p <= $pos2; $p += 1) {
                substr($line1, $p, 1) = '_' if substr($line1, $p, 1) eq ' ';
            }
        }
        foreach my $left (@left) {
            substr($line2, 3 * $left + 1, 1) = '/';
        }
    }
    if (scalar @right) {
        substr($line1, 3 * $from + 1, 1) = '\\';
        my $maxright = max(@drawto);
        if ($maxright >= $from + 2) {
            my $pos1 = $from * 3 + 2;
            my $pos2 = $maxright * 3 - 2;
            for (my $p = $pos1; $p <= $pos2; $p += 1) {
                substr($line1, $p, 1) = '_' if substr($line1, $p, 1) eq ' ';
            }
        }
        foreach my $right (@right) {
            substr($line2, 3 * $right - 1, 1) = '\\';
        }
    }
    return ($line1, $line2);
}

sub mergePriorityWinner {
    my ($self, $a, $b) = @_;
    foreach my $merge (@{$self->{merge}}) {
        if ($merge->[0] eq $a && $merge->[1] eq $b) {
            return ($merge->[2], $merge->[3]);
        }
    }
    return;
}

sub addMergePriority {
    my ($self, $fparent, @oparents) = @_;
    foreach my $oparent (@oparents) {
        push(@{$self->{merge}}, [$fparent, $oparent, $fparent, $column{$fparent}]);
        push(@{$self->{merge}}, [$oparent, $fparent, $fparent, $column{$fparent}]);
    }
}

sub replaceExistingMergePriorities {
    my ($self, $commit, $fparent, $fparentcolumn) = @_;
    foreach my $merge (@{$self->{merge}}) {
        if ($merge->[0] eq $commit) {
            $merge->[0] = $fparent;
        }
        if ($merge->[1] eq $commit) {
            $merge->[1] = $fparent;
        }
        if ($merge->[2] eq $commit) {
            $merge->[2] = $fparent;
            $merge->[3] = $fparentcolumn;
        }
    }
}

1;
