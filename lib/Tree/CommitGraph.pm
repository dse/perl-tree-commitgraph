package Tree::CommitGraph;
use warnings;
use strict;

use List::Util qw(max min);

sub new {
    my ($class) = @_;
    my $self = bless({}, $class);
    $self->initState();
    return $self;
}

sub parseLine {
    my ($self, $line) = @_;
    next if $line =~ m{^\s*\#};    # skip comments;
    next if $line =~ m{^\s*$};     # skip blank lines
    $line =~ s{#.*$}{};            # remove comments from end of line
    if ($line =~ m{^\s*---\s*$}) { # end of graph; start over
        $self->initState();
        next;
    }
    my (@commits) = split(' ', $_);
    $self->processCommit(@commits);
}

sub processCommit {
    my ($self, @commits) = @_;
    my ($commit, $firstParent, @otherParent) = @commits;
    @{$self->{commits}} = @commits;
    $self->{thisCommitColumn} = $self->{commitColumn}->{$commit} //= $self->newColumn();
    $self->{columnStatus}->[$self->{thisCommitColumn}] //= 1;
    $self->{firstParentColumn} = defined $firstParent ?
      $self->{commitColumn}->{$firstParent} //= $self->{commitColumn}->{$commit} :
      undef;
    $self->{columnStatus}->[$self->{firstParentColumn}] //= 2 if defined $self->{firstParentColumn};
    @{$self->{otherParentColumn}} = ();
    foreach my $otherParent (@otherParent) {
        push(@{$self->{otherParentColumn}}, $self->{commitColumn}->{$otherParent} //= $self->newColumn());
        $self->{columnStatus}->[$self->{commitColumn}->{$otherParent}] //= 2;
    }
    $self->{columnCount} = $self->columnCount();
    $self->printLine();
    $self->printDiagonals();
    do { $_ = 1 if defined $_ && $_ == 2 } foreach @{$self->{columnStatus}};
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
    $self->{commits}           = [];
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

sub printLine {
    my ($self) = @_;
    for (my $i = 0; $i < $self->{columnCount}; $i += 1) {
        print('  ') if $i;
        if ($i == $self->{thisCommitColumn}) {
            print('*');
        } elsif (!defined $self->{columnStatus}->[$i]) {
            print(' ');
        } elsif ($self->{columnStatus}->[$i] == 1) {
            print('|');
        } else {
            print(' ');
        }
    }
    print("  @{$self->{commits}}\n");
}

sub printDiagonals {
    my ($self) = @_;
    if (!defined $self->{firstParentColumn}) {
        return;
    }
    my @dest = ($self->{firstParentColumn}, @{$self->{otherParentColumn}});

    if (!grep { $_ eq $self->{thisCommitColumn} } @dest) {
        $self->{columnStatus}->[$self->{thisCommitColumn}] = undef;
    }

    my @diagonalDest = grep { $_ ne $self->{thisCommitColumn} } @dest;
    if (scalar @diagonalDest) {
        my $maxCount = $self->{columnCount};
        $maxCount = max($self->{columnCount}, $self->{lastColumnCount}) if defined $self->{lastColumnCount};
        my $textColumnCount = $maxCount * 3 - 2;
        my $diagonal1 = ' ' x $textColumnCount;
        my $diagonal2 = ' ' x $textColumnCount;
        my @leftDest  = grep { $_ < $self->{thisCommitColumn} } @diagonalDest;
        my @rightDest = grep { $_ > $self->{thisCommitColumn} } @diagonalDest;
        if (scalar @leftDest) {
            my $leftmost = min(@leftDest);
            my $c1 = $self->{thisCommitColumn} * 3 - 1;
            my $c2 = $leftmost * 3 + 1;
            my $ucount = $c1 - $c2 - 1;
            substr($diagonal1, $c2 + 1, $ucount) = ('_' x $ucount);
            substr($diagonal1, $c1, 1) = '/';
            substr($diagonal2, $_ * 3 + 1, 1) = '/' foreach @leftDest;
        }
        if (scalar @rightDest) {
            my $rightmost = max(@rightDest);
            my $c1 = $self->{thisCommitColumn} * 3 + 1;
            my $c2 = $rightmost * 3 - 1;
            my $ucount = $c2 - $c1 - 1;
            substr($diagonal1, $c1, 1) = '\\';
            substr($diagonal1, $c1 + 1, $ucount) = ('_' x $ucount);
            substr($diagonal2, $_ * 3 - 1, 1) = '\\' foreach @rightDest;
        }
        if (grep { $_ eq $self->{thisCommitColumn} } @dest) {
            substr($diagonal1, $self->{thisCommitColumn} * 3, 1) = '|';
            substr($diagonal2, $self->{thisCommitColumn} * 3, 1) = '|';
        }
        for (my $i = 0; $i < scalar @{$self->{columnStatus}}; $i += 1) {
            if (defined $self->{columnStatus}->[$i] && $self->{columnStatus}->[$i] == 1) {
                substr($diagonal1, $i * 3, 1) = '|';
                substr($diagonal2, $i * 3, 1) = '|';
            }
        }

        print("$diagonal1\n");
        print("$diagonal2\n");
    }
}

1;
