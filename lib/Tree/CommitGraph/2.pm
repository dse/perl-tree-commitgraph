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

sub commit {
    my ($self, $commit, $fparent, @oparents) = @_;
    my $legend = join(' ', grep { defined $_ } ($commit, $fparent, @oparents));
    $self->{commit} = $commit;
    $self->{fparent} = $fparent;
    $self->{oparents} = \@oparents;
    our %column;     local *column     = \%{$self->{column} //= {}};
    our %nextcolumn; local *nextcolumn = \%{$self->{nextcolumn} //= {}};
    # { my @nc = %nextcolumn; print("@nc\n"); }
    if (!defined $column{$commit}) {
        $column{$commit} = $self->firstAvailableColumn(%column, %nextcolumn);
    }
    $nextcolumn{$commit} = $column{$commit};

    local $Data::Dumper::Terse = 1;

    if (defined $fparent) {
        if (!defined $column{$fparent}) {
            $nextcolumn{$fparent} = $column{$commit};
        } else {
            if ($column{$commit} != $column{$fparent}) {
                print(":-/\n");
            }
            my ($merge) = grep { $_->[0] eq $commit && $_->[1] eq $fparent } @{$self->{merge}};
            # if (defined $merge) {
            #     print("@$merge\n");
            #     $nextcolumn{$commit} = $merge->[2];
            #     $nextcolumn{$fparent} = $merge->[2];
            # } else {
                $nextcolumn{$commit} = $column{$fparent};
                $nextcolumn{$fparent} = $column{$fparent};
            # }
        }
        foreach my $oparent (@oparents) {
            if (!defined $column{$oparent}) {
                $nextcolumn{$oparent} = $self->firstAvailableColumn(%column, %nextcolumn);
            } else {
                $nextcolumn{$oparent} = $column{$oparent};
            }
        }
    } else {
        delete $nextcolumn{$commit};
    }

    if (defined $fparent) {
        if (scalar @oparents) {
            foreach my $oparent (@oparents) {
                push(@{$self->{merge}}, [$fparent, $oparent, $nextcolumn{$fparent}]);
                push(@{$self->{merge}}, [$oparent, $fparent, $nextcolumn{$fparent}]);
            }
        } else {
            foreach my $merge (@{$self->{merge}}) {
                $merge->[0] = $fparent if $merge->[0] eq $commit;
                $merge->[1] = $fparent if $merge->[1] eq $commit;
            }
        }
    }

    my $maxcolumn = max(values(%nextcolumn), values(%column));
    my @commits = grep { defined($column{$_}) && $column{$_} == $nextcolumn{$_} } keys %nextcolumn;
    my @nextcols = map { $nextcolumn{$_} } @commits;
    my %columns = map { ($_ => 1) } @nextcols;
    if (defined $self->{orphaned} && $self->{orphaned} == $column{$commit}) {
        my $line = '';
        for (my $column = 0; $column <= $maxcolumn; $column += 1) {
            $line .= '  ' if $column > 0;
            if ($column == $column{$commit}) {
                $line .= ' ';
            } elsif ($columns{$column}) {
                $line .= ('|');
            } else {
                $line .= (' ');
            }
        }
        print("$line\n");
    }
    my $line1 = '';
    for (my $column = 0; $column <= $maxcolumn; $column += 1) {
        $line1 .= ('  ') if $column > 0;
        if ($columns{$column}) {
            $line1 .= ('|');
        } else {
            $line1 .= (' ');
        }
    }
    my $line0 = $line1;
    substr($line0, $column{$commit} * 3, 1) = '*';
    $line0 .= ' ' x (max(16, 64 - length($line0)));
    $line0 .= $legend;
    print("$line0\n");
    {
        my $line2 = $line1;
        my @drawto = map { $nextcolumn{$_} } grep { defined($_) } ($fparent, @oparents);
        my @left  = grep { $_ < $column{$commit} } @drawto;
        my @right = grep { $_ > $column{$commit} } @drawto;
        if (scalar @left || scalar @right) {
            if (scalar @left) {
                substr($line1, 3 * $column{$commit} - 1, 1) = '/';
                my $minleft = min(values %nextcolumn);
                if ($minleft <= $column{$commit} - 2) {
                    my $pos1 = $minleft * 3 + 2;
                    my $pos2 = $column{$commit} * 3 - 2;
                    for (my $p = $pos1; $p <= $pos2; $p += 1) {
                        substr($line1, $p, 1) = '_' if substr($line1, $p, 1) eq ' ';
                    }
                }
                foreach my $left (@left) {
                    substr($line2, 3 * $left + 1, 1) = '/';
                }
            }
            if (scalar @right) {
                substr($line1, 3 * $column{$commit} + 1, 1) = '\\';
                my $maxright = max(values %nextcolumn);
                if ($maxright >= $column{$commit} + 2) {
                    my $pos1 = $column{$commit} * 3 + 2;
                    my $pos2 = $maxright * 3 - 2;
                    for (my $p = $pos1; $p <= $pos2; $p += 1) {
                        substr($line1, $p, 1) = '_' if substr($line1, $p, 1) eq ' ';
                    }
                }
                foreach my $right (@right) {
                    substr($line2, 3 * $right - 1, 1) = '\\';
                }
            }
            print("$line1\n");
            print("$line2\n");
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

1;
