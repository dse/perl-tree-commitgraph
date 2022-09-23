package Tree::CommitGraph::GraphLines;
use warnings;
use strict;

use base 'Exporter';

use List::Util qw(min max);

sub debug {
    my ($format, @args) = @_;
    printf("$format\n", @args);
}

sub new {
    my ($class, %args) = @_;
    my $self = bless({%args}, $class);
    $self->{coldiff} //= 2;
    return $self;
}

sub verticals {
    my ($self, $state1, $state2, %args) = @_;
    my $coldiff = $self->{coldiff};
    my $maxcol = max($state1->values, $state2->values);
    my @columns = $state1->values;
    my %columns = map { ($_ => 1) } @columns;
    if (defined $args{exclude}) {
        if (ref $args{exclude} eq '') {
            delete $columns{$args{exclude}};
        }
    }
    my $line = ' ' x ($coldiff * $maxcol + 1);
    foreach my $column (keys %columns) {
        substr($line, $coldiff * $column, 1) = '|';
    }
    if (defined $args{mark}) {
        substr($line, $coldiff * $args{mark}, 1) = '*';
    }
    $line =~ s{\*}{\e[1;33m$&\e[m}g;
    return $line;
}

sub diagonals {
    my ($self, $state1, $state2, %args) = @_;
    my $useline2 = 0;
    my $coldiff = $self->{coldiff};
    my $maxcol = max($state1->values, $state2->values);
    my @attrs1 = ('' x ($coldiff * $maxcol + 1));
    my @attrs2 = ('' x ($coldiff * $maxcol + 1));
    my $line1 = ' ' x ($coldiff * $maxcol + 1);
    my $line2 = ' ' x ($coldiff * $maxcol + 1);
    my @commits = grep { defined $state2->getColumn($_) } $state1->keys;
    my @verticalcommits = grep { $state1->getColumn($_) == $state2->getColumn($_) } @commits;
    my @diagonalcommits = grep { $state1->getColumn($_) != $state2->getColumn($_) } @commits;
    if (!scalar @diagonalcommits) {
        return;
    }
    my $firstParent = $state1->getFirstParent();
    my $line1column = $state1->getColumn($firstParent);
    my $line2column = $state2->getColumn($firstParent);
    if (defined $line2column && defined $line1column) {
        if ($line2column < $line1column) {
            $attrs1[$line1column * $coldiff - 1] = "\e[1;33m";
            $attrs2[$line2column * $coldiff + 1] = "\e[1;33m";
            my $pos1 = $line2column * $coldiff + 2;
            my $pos2 = $line1column * $coldiff - 2;
            for (my $col = $pos1; $col <= $pos2; $col += 1) {
                $attrs1[$col] = "\e[1;33m";
            }
        } elsif ($line2column > $line1column) {
            $attrs1[$line1column * $coldiff + 1] = "\e[1;33m";
            $attrs2[$line2column * $coldiff - 1] = "\e[1;33m";
            my $pos1 = $line1column * $coldiff + 2;
            my $pos2 = $line2column * $coldiff - 2;
            for (my $col = $pos1; $col <= $pos2; $col += 1) {
                $attrs1[$col] = "\e[1;33m";
            }
        } else {
            $attrs1[$line1column * $coldiff] = "\e[1;33m";
            $attrs2[$line2column * $coldiff] = "\e[1;33m";
        }
    }
    my @diagonalorigins = map { $state1->getColumn($_) } @diagonalcommits;
    my %diagonalorigins = map { ($_ => 1) } @diagonalorigins;
    if (scalar keys %diagonalorigins > 1) {
        # debug("unexpected");
        # debug("    diagonal commits are @diagonalcommits");
        # foreach my $commit (@commits) {
        #     debug("        %s: %s => %s", $commit,
        #           $state1->getColumn($commit) // '-',
        #           $state2->getColumn($commit) // '-',
        #       );
        # }
        die("unexpected");
    }
    my @verticals = map { $state1->getColumn($_) } @verticalcommits;
    my @diagonals = map { $state2->getColumn($_) } @diagonalcommits;
    my $currentcolumn = $diagonalorigins[0];
    my @left  = grep { $_ < $currentcolumn } @diagonals;
    my @right = grep { $_ > $currentcolumn } @diagonals;
    if (scalar @left) {
        my $min = min(@left);
        substr($line1, $currentcolumn * $coldiff - 1, 1) = '/';
        foreach my $left (@left) {
            if ($left == $currentcolumn - 1 && $coldiff < 3) {
                # do nothing
            } else {
                substr($line2, $left * $coldiff + 1, 1) = '/';
                $useline2 = 1;
            }
        }
        my $pos1 = $min * $coldiff + 2;
        my $pos2 = $currentcolumn * $coldiff - 2;
        if ($pos2 - $pos1 + 1 > 0) {
            substr($line1, $pos1, $pos2 - $pos1 + 1) = '_' x ($pos2 - $pos1 + 1);
        }
    }
    if (scalar @right) {
        my $max = max(@right);
        substr($line1, $currentcolumn * $coldiff + 1, 1) = '\\';
        foreach my $right (@right) {
            if ($right == $currentcolumn + 1 && $coldiff < 3) {
                # do nothing
            } else {
                substr($line2, $right * $coldiff - 1, 1) = '\\';
                $useline2 = 1;
            }
        }
        my $pos1 = $currentcolumn * $coldiff + 2;
        my $pos2 = $max * $coldiff - 2;
        if ($pos2 - $pos1 + 1 > 0) {
            substr($line1, $pos1, $pos2 - $pos1 + 1) = '_' x ($pos2 - $pos1 + 1);
        }
    }
    foreach my $col (@verticals) {
        substr($line1, $col * $coldiff, 1) = '|';
        substr($line2, $col * $coldiff, 1) = '|';
    }
    # $line1 = addAttributes($line1, @attrs1);
    # $line2 = addAttributes($line2, @attrs2);
    if ($useline2) {
        return ($line1, $line2);
    }
    return ($line1);
}

sub addAttributes {
    my ($line, @attrs) = @_;
    for (my $col = scalar(@attrs); $col >= 0; $col -= 1) {
        my $b = ($col == scalar(@attrs) ? '' : $attrs[$col]) // '';
        my $a = ($col == 0              ? '' : $attrs[$col - 1]) // '';
        if ($b ne $a) {
            if ($b eq '') {
                substr($line, $col, 0) = "\e[0m";
            } else {
                substr($line, $col, 0) = $b;
            }
        }
    }
    return $line;
}

1;
