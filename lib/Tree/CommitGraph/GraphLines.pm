package Tree::CommitGraph::GraphLines;
use warnings;
use strict;

use base 'Exporter';

our @EXPORT = qw(verticals diagonals);
our @EXPORT_OK = qw();
our %EXPORT_TAGS = (all => [@EXPORT_OK]);

use List::Util qw(min max);

sub new {
    my ($class, %args) = @_;
    my $self = bless({%args}, $class);
    return $self;
}

sub verticals {
    my ($self, $state1, $state2, %args) = @_;
    my $maxcol = max($state1->values, $state2->values);
    my @columns = $state1->values;
    my %columns = map { ($_ => 1) } @columns;
    if (defined $args{exclude}) {
        if (ref $args{exclude} eq '') {
            delete $columns{$args{exclude}};
        }
    }
    my $line = ' ' x (3 * $maxcol + 1);
    foreach my $column (keys %columns) {
        substr($line, 3 * $column, 1) = '|';
    }
    if (defined $args{mark}) {
        substr($line, 3 * $args{mark}, 1) = '*';
    }
    return $line;
}

sub diagonals {
    my ($self, $state1, $state2, %args) = @_;
    my @state1 = $state1->values;
    my @state2 = $state2->values;
    my $maxcol = max($state1->values, $state2->values);
    my $line1 = ' ' x (3 * $maxcol + 1);
    my $line2 = ' ' x (3 * $maxcol + 1);
    my @commits = grep { defined $state2->getColumn($_) } $state1->keys;
    my @verticalcommits = grep { $state1->getColumn($_) == $state2->getColumn($_) } @commits;
    my @diagonalcommits = grep { $state1->getColumn($_) != $state2->getColumn($_) } @commits;
    if (!scalar @diagonalcommits) {
        return;
    }
    my @diagonalorigins = map { $state1->getColumn($_) } @diagonalcommits;
    my %diagonalorigins = map { ($_ => 1) } @diagonalorigins;
    if (scalar keys %diagonalorigins > 1) {
        die("unexpected");
    }
    my @verticals = map { $state1->getColumn($_) } @verticalcommits;
    my @diagonals = map { $state2->getColumn($_) } @diagonalcommits;
    my $currentcolumn = $diagonalorigins[0];
    my @left  = grep { $_ < $currentcolumn } @diagonals;
    my @right = grep { $_ > $currentcolumn } @diagonals;
    if (scalar @left) {
        my $min = min(@left);
        substr($line1, $currentcolumn * 3 - 1, 1) = '/';
        foreach my $left (@left) {
            substr($line2, $left * 3 + 1, 1) = '/';
        }
        my $pos1 = $min * 3 + 2;
        my $pos2 = $currentcolumn * 3 - 2;
        substr($line1, $pos1, $pos2 - $pos1 + 1) = '_' x ($pos2 - $pos1 + 1);
    }
    if (scalar @right) {
        my $max = max(@right);
        substr($line1, $currentcolumn * 3 + 1, 1) = '\\';
        foreach my $right (@right) {
            substr($line2, $right * 3 - 1, 1) = '\\';
        }
        my $pos1 = $currentcolumn * 3 + 2;
        my $pos2 = $max * 3 - 2;
        substr($line1, $pos1, $pos2 - $pos1 + 1) = '_' x ($pos2 - $pos1 + 1);
    }
    foreach my $col (@verticals) {
        substr($line1, $col * 3, 1) = '|';
        substr($line2, $col * 3, 1) = '|';
    }
    return ($line1, $line2);
}

1;
