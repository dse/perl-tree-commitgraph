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
    my ($self, $now, $next, %args) = @_;
    my $coldiff = $self->{coldiff};
    my $maxcol = max($now->values, $next->values);
    my @columns = $now->values;
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
    my ($self, $now, $next, %args) = @_;
    my $useline2 = 0;
    my $coldiff = $self->{coldiff};
    my $maxcol = max($now->values, $next->values);
    my $line1 = ' ' x ($coldiff * $maxcol + 1);
    my $line2 = ' ' x ($coldiff * $maxcol + 1);
    my @commits = grep { defined $next->getColumn($_) } $now->keys;
    my @verticalcommits = grep { $now->getColumn($_) == $next->getColumn($_) } @commits;
    my @diagonalcommits = grep { $now->getColumn($_) != $next->getColumn($_) } @commits;
    if (!scalar @diagonalcommits) {
        return;
    }
    my $firstParent = $now->getFirstParent();
    my $line1column = $now->getColumn($firstParent);
    my $line2column = $next->getColumn($firstParent);
    my @diagonalorigins = map { $now->getColumn($_) } @diagonalcommits;
    my %diagonalorigins = map { ($_ => 1) } @diagonalorigins;
    if (scalar keys %diagonalorigins > 1) {
        die("unexpected");
    }
    my @verticals = map { $now->getColumn($_) } @verticalcommits;
    my @diagonals = map { $next->getColumn($_) } @diagonalcommits;
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
    if ($useline2) {
        return ($line1, $line2);
    }
    return ($line1);
}

1;
