package Tree::CommitGraph;
use warnings;
use strict;
use feature qw(say);

use List::Util qw(max min);

use constant ACTIVE   => 1;
use constant NEW      => 2;
use constant ORPHANED => 3;
use constant WILLDIE  => 4;

sub new {
    my ($class) = @_;
    my $self = bless({}, $class);
    $self->initState();
    return $self;
}

# for testing
sub parseLine {
    my ($self, $line) = @_;
    return if $line =~ m{^\s*\#};  # skip comments;
    return if $line =~ m{^\s*$};   # skip blank lines
    $line =~ s{#.*$}{};            # remove comments from end of line
    if ($line =~ m{^\s*---\s*$}) { # end of graph; start a new one
        $self->initState();
        print("---\n");
        return;
    }
    my (@commitAndParents) = split(' ', $line);
    $self->processCommit(@commitAndParents);
}

sub processCommit {
    my ($self, @commitAndParents) = @_;
    my ($commit, @parent) = @commitAndParents;
    my ($firstParent, @otherParent) = @parent;

    @{$self->{commitAndParents}} = @commitAndParents;
    $self->{thisCommitColumn} = $self->{commitColumn}->{$commit} //= $self->newColumn();
    $self->{columnStatus}->[$self->{thisCommitColumn}] //= ACTIVE;
    $self->{firstParentColumn} = defined $firstParent ?
      $self->{commitColumn}->{$firstParent} //= $self->{commitColumn}->{$commit} :
      undef;

    if (!scalar @parent) {
        $self->{columnStatus}->[$self->{thisCommitColumn}] = ORPHANED;
    }

    $self->{columnStatus}->[$self->{firstParentColumn}] //= NEW if defined $self->{firstParentColumn};
    @{$self->{otherParentColumn}} = ();
    foreach my $otherParent (@otherParent) {
        push(@{$self->{otherParentColumn}}, $self->{commitColumn}->{$otherParent} //= $self->newColumn());
        $self->{columnStatus}->[$self->{commitColumn}->{$otherParent}] //= NEW;
    }
    $self->{columnCount} = $self->columnCount();
    $self->printLine();
    $self->printExtraLines();
    $self->printLines();

    do { $_ = undef   if defined $_ && $_ == WILLDIE  } foreach @{$self->{columnStatus}};
    do { $_ = WILLDIE if defined $_ && $_ == ORPHANED } foreach @{$self->{columnStatus}};
    do { $_ = ACTIVE  if defined $_ && $_ == NEW      } foreach @{$self->{columnStatus}};
}

sub initState {
    my ($self) = @_;
    $self->{commitColumn}      = {};
    $self->{columnStatus}      = [];
    $self->{lastColumnCount}   = undef;
    $self->{thisCommitColumn}  = undef;
    $self->{firstParentColumn} = undef;
    $self->{otherParentColumn} = [];
    $self->{columnCount}       = undef;
    $self->{commitAndParents}  = [];
    $self->{extraLine1}     = undef;
    $self->{extraLine2}     = undef;
    $self->{extraLine3}     = undef;
}

sub newColumn {
    my ($self) = @_;
    for (my $i = 0; $i < scalar @{$self->{columnStatus}}; $i += 1) {
        return $i if !defined $self->{columnStatus}->[$i];
    }
    return scalar @{$self->{columnStatus}};
}

sub columnCount {
    my ($self) = @_;
    my $count = 0;
    for (my $i = 0; $i < scalar @{$self->{columnStatus}}; $i += 1) {
        $count = $i + 1 if defined $self->{columnStatus}->[$i];
    }
    return $count;
}

sub printLines {
    my ($self) = @_;
    print($self->{commitLine}, "\n");
    if ($self->{hasDiagonals}) {
        print($self->{extraLine1}, "\n") if defined $self->{extraLine1};
        print($self->{extraLine2}, "\n") if defined $self->{extraLine2};
    }
    print($self->{extraLine3}, "\n") if defined $self->{extraLine3};
}

sub printLine {
    my ($self) = @_;
    my $columnCount = max($self->{columnCount},
                          $self->{lastColumnCount} // 0);
    my $commitLine = '';
    for (my $i = 0; $i < $columnCount; $i += 1) {
        $commitLine .= '  ' if $i;
        if ($i == $self->{thisCommitColumn}) {
            $commitLine .= '*';
        } elsif (!defined $self->{columnStatus}->[$i]) {
            $commitLine .= ' ';
        } elsif ($self->{columnStatus}->[$i] == 1) {
            $commitLine .= '|';
        } else {
            $commitLine .= ' ';
        }
    }
    $self->{commitLine} = $commitLine;
}

sub printExtraLines {
    my ($self) = @_;
    if (!defined $self->{firstParentColumn}) {
        return;
    }

    # which columns does this commit go to?  they correspond with this
    # commit's parents.
    my @dest = ($self->{firstParentColumn}, @{$self->{otherParentColumn}});

    # if no parent commits are in the same column...
    if (!grep { $_ eq $self->{thisCommitColumn} } @dest) {
        $self->{columnStatus}->[$self->{thisCommitColumn}] = undef;
    }

    my $maxCount = max($self->{columnCount}, $self->{lastColumnCount} // 0);
    my $textColumnCount = $maxCount * 3 - 2;

    # diagonal lines from this commit to parents.  If there aren't
    # any, we may not need to print the extra lines at all.
    my @diagonalDest = grep { $_ ne $self->{thisCommitColumn} } @dest;
    if (scalar @diagonalDest) {
        $self->{hasDiagonals} = 1;

        my $extra1 = ' ' x $textColumnCount;
        my $extra2 = ' ' x $textColumnCount;
        my $extra3 = ' ' x $textColumnCount;

        # / lines go to these columns
        my @leftDest  = grep { $_ < $self->{thisCommitColumn} } @diagonalDest;
        if (scalar @leftDest) {
            my $leftmost = min(@leftDest);
            my $c1 = $self->{thisCommitColumn} * 3 - 1;
            my $c2 = $leftmost * 3 + 1;
            my $ucount = $c1 - $c2 - 1;
            substr($extra1, $c2 + 1, $ucount) = ('_' x $ucount);
            substr($extra1, $c1, 1) = '/';
            substr($extra2, $_ * 3 + 1, 1) = '/' foreach @leftDest;
        }

        # \ lines go to these columns
        my @rightDest = grep { $_ > $self->{thisCommitColumn} } @diagonalDest;
        if (scalar @rightDest) {
            my $rightmost = max(@rightDest);
            my $c1 = $self->{thisCommitColumn} * 3 + 1;
            my $c2 = $rightmost * 3 - 1;
            my $ucount = $c2 - $c1 - 1;
            substr($extra1, $c1, 1) = '\\';
            substr($extra1, $c1 + 1, $ucount) = ('_' x $ucount);
            substr($extra2, $_ * 3 - 1, 1) = '\\' foreach @rightDest;
        }

        # is there a parent in this column?
        if (grep { $_ eq $self->{thisCommitColumn} } @dest) {
            substr($extra1, $self->{thisCommitColumn} * 3, 1) = '|';
            substr($extra2, $self->{thisCommitColumn} * 3, 1) = '|';
            substr($extra3, $self->{thisCommitColumn} * 3, 1) = '|';
        }

        # draw the other lines that go straight down
        for (my $i = 0; $i < scalar @{$self->{columnStatus}}; $i += 1) {
            if (defined $self->{columnStatus}->[$i] && $self->{columnStatus}->[$i] == ACTIVE) {
                substr($extra1, $i * 3, 1) = '|';
                substr($extra2, $i * 3, 1) = '|';
                substr($extra3, $i * 3, 1) = '|';
            }
        }

        foreach my $column (@dest) {
            substr($extra3, $column * 3, 1) = '|';
        }

        $self->{extraLine1} = $extra1;
        $self->{extraLine2} = $extra2;
        $self->{extraLine3} = $extra3;
    } else {
        $self->{hasDiagonals} = 0;

        my $line = ' ' x $textColumnCount;

        # draw the other lines that go straight down
        for (my $i = 0; $i < scalar @{$self->{columnStatus}}; $i += 1) {
            if (defined $self->{columnStatus}->[$i] && $self->{columnStatus}->[$i] == ACTIVE) {
                substr($line, $i * 3, 1) = '|';
                substr($line, $i * 3, 1) = '|';
                substr($line, $i * 3, 1) = '|';
            }
        }

        $self->{extraLine1} = $line;
        $self->{extraLine2} = $line;
        $self->{extraLine3} = $line;
    }
    $self->{lastColumnCount} = $self->{columnCount};
}

1;
