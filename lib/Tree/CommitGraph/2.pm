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
    local *column     = \%{$self->{column} //= {}};
    local *nextcolumn = \%{$self->{nextcolumn} //= {}};
    if (!defined $column{$commit}) {
        $column{$commit} = $self->firstAvailableColumn(%column, %nextcolumn);
    }
    $nextcolumn{$commit} = $column{$commit};
    if (defined $fparent) {
        if (!defined $column{$fparent}) {
            $nextcolumn{$fparent} = $column{$commit};
        } else {
            if ($column{$commit} != $column{$fparent}) {
                $nextcolumn{$commit} = $column{$fparent};
                $nextcolumn{$fparent} = $column{$fparent};
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
        foreach my $merge (@{$self->{merge}}) {
            if ($merge->[0] eq $commit) {
                $merge->[0] = $fparent;
            }
            if ($merge->[1] eq $commit) {
                $merge->[1] = $fparent;
            }
            if ($merge->[2] eq $commit) {
                $merge->[2] = $fparent;
                $merge->[3] = $column{$fparent};
            }
        }
        foreach my $oparent (@oparents) {
            push(@{$self->{merge}}, [$fparent, $oparent, $fparent, $column{$fparent}]);
            push(@{$self->{merge}}, [$oparent, $fparent, $fparent, $column{$fparent}]);
        }
    }

    my $maxcolumn = max(values(%nextcolumn), values(%column));

    my @stayingcommits = grep {
        defined($column{$_}) && defined($nextcolumn{$_}) && $column{$_} == $nextcolumn{$_}
    } keys %nextcolumn;
    my @stayingcolumns = map { $nextcolumn{$_} } @stayingcommits;
    my %columnstayings = map { ($_ => 1) } @stayingcolumns;

    # check for orphan
    if (defined $self->{orphaned} && $self->{orphaned} == $column{$commit}) {
        print($self->verticalLinesLine(grep { $_ != $column{$commit} } @stayingcolumns));
        print("\n");
    }

    my $line = $self->verticalLinesLine(@stayingcolumns);

    # this line
    my $line0 = $line;
    substr($line0, $column{$commit} * 3, 1) = '*';
    $line0 .= ' ' x (max(16, 64 - length($line0)));
    $line0 .= $legend;
    print("$line0\n");

    my @drawto = grep { $_ != $column{$commit} } map { $nextcolumn{$_} } grep { defined $_ } ($fparent, @oparents);
    if (scalar @drawto) {
        my ($line1, $line2) = $self->applyDiagonals($line, $column{$commit}, @drawto);
        print("$line1\n") if defined $line1;
        print("$line2\n") if defined $line2;
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

1;
