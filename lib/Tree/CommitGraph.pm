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
    $self->{padding} = 32;
    $self->{mark} = {};
    $self->{isatty} = 0;
    $self->initState();
    return $self;
}

# for testing
sub parseLine {
    my ($self, $line) = @_;
    $line =~ s{\R\z}{};            # safer chomp;
    return if $line =~ m{^\s*\#};  # skip comments;
    return if $line =~ m{^\s*$};   # skip blank lines
    $line =~ s{#.*$}{};            # remove comments from end of line
    $line =~ s{^\s+}{};
    $line =~ s{\s+$}{};
    if ($line =~ m{^\s*---+\s*$}) { # end of graph; start a new one
        $self->initState();
        print("---\n");
        return;
    }
    my ($commit, @parents) = split(' ', $line);
    $self->processCommit(commit => $commit, parents => \@parents);
}

sub processCommit {
    my ($self, %args) = @_;
    my $commit = $args{commit};
    my @parents = defined $args{parents} ? @{$args{parents}} : ();
    my $line = $args{line};
    my ($firstParent, @otherParent) = @parents;

    $self->{commit} = $commit;
    $self->{thisCommitColumn} = $self->{commitColumn}->{$commit} //= $self->newColumn();
    $self->{columnStatus}->[$self->{thisCommitColumn}] //= ACTIVE;
    $self->{firstParentColumn} = defined $firstParent ?
      $self->{commitColumn}->{$firstParent} //= $self->{commitColumn}->{$commit} :
      undef;

    if (!scalar @parents) {
        $self->{columnStatus}->[$self->{thisCommitColumn}] = ORPHANED;
    }

    $self->{columnStatus}->[$self->{firstParentColumn}] //= NEW if defined $self->{firstParentColumn};
    @{$self->{otherParentColumn}} = ();
    foreach my $otherParent (@otherParent) {
        push(@{$self->{otherParentColumn}}, $self->{commitColumn}->{$otherParent} //= $self->newColumn());
        $self->{columnStatus}->[$self->{commitColumn}->{$otherParent}] //= NEW;
    }
    $self->{columnCount} = $self->columnCount();
    $self->setGraphLines();

    do { $_ = undef   if defined $_ && $_ == WILLDIE  } foreach @{$self->{columnStatus}};
    do { $_ = WILLDIE if defined $_ && $_ == ORPHANED } foreach @{$self->{columnStatus}};
    do { $_ = ACTIVE  if defined $_ && $_ == NEW      } foreach @{$self->{columnStatus}};
}

sub endCommit {
    my ($self) = @_;
    while (scalar @{$self->{graphLines}}) {
        my $graphLine = shift(@{$self->{graphLines}});
        print($graphLine . "\n");
    }
}

sub printCommitLine {
    my ($self, $line) = @_;
    my $graphLine;
    if (scalar @{$self->{graphLines}}) {
        $graphLine = shift(@{$self->{graphLines}});
    } else {
        $graphLine = $self->{graphContinuationLine};
    }
    $graphLine .= '  ';
    my $length = $self->stringLengthExcludingControlSequences($graphLine);
    my $additionalSpaceCount = $self->{padding} - $length;
    if ($additionalSpaceCount > 0) {
        $graphLine .= ' ' x $additionalSpaceCount;
    }
    print($graphLine . $line . "\n");
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
    $self->{commit}            = undef;
    $self->{parents}           = [];
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

sub setGraphLines {
    my ($self) = @_;
    $self->{graphLines} = [];
    $self->{graphLinesSaved} = [];
    $self->{graphContinuationLine} = undef;
    $self->setFirstGraphLine();
    $self->setExtraGraphLines();
}

sub setFirstGraphLine {
    my ($self) = @_;
    my $columnCount = max($self->{columnCount},
                          $self->{lastColumnCount} // 0);
    my $graphLine = '';
    for (my $i = 0; $i < $columnCount; $i += 1) {
        $graphLine .= '  ' if $i;
        if ($i == $self->{thisCommitColumn}) {
            if (defined $self->{mark} && exists $self->{mark}->{$self->{commit}}) {
                $graphLine .= "\e[1m" if $self->{isatty};
                $graphLine .= $self->{mark}->{$self->{commit}};
                $graphLine .= "\e[0m" if $self->{isatty};
            } else {
                $graphLine .= '*';
            }
        } elsif (!defined $self->{columnStatus}->[$i]) {
            $graphLine .= ' ';
        } elsif ($self->{columnStatus}->[$i] == 1) {
            $graphLine .= '|';
        } else {
            $graphLine .= ' ';
        }
    }
    push(@{$self->{graphLines}}, $graphLine);
    push(@{$self->{graphLinesSaved}}, $graphLine);

    my $maxCount = max($self->{columnCount}, $self->{lastColumnCount} // 0);
    my $textColumnCount = $maxCount * 3 - 2;

    $self->{graphContinuationLine} = ' ' x $textColumnCount;
}

sub setExtraGraphLines {
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

        my $extraLine1 = ' ' x $textColumnCount;
        my $extraLine2 = ' ' x $textColumnCount;
        my $extraLine3 = ' ' x $textColumnCount;

        # / lines go to these columns
        my @leftDest  = grep { $_ < $self->{thisCommitColumn} } @diagonalDest;
        if (scalar @leftDest) {
            my $leftmost = min(@leftDest);
            my $c1 = $self->{thisCommitColumn} * 3 - 1;
            my $c2 = $leftmost * 3 + 1;
            my $ucount = $c1 - $c2 - 1;
            substr($extraLine1, $c2 + 1, $ucount) = ('_' x $ucount);
            substr($extraLine1, $c1, 1) = '/';
            substr($extraLine2, $_ * 3 + 1, 1) = '/' foreach @leftDest;
        }

        # \ lines go to these columns
        my @rightDest = grep { $_ > $self->{thisCommitColumn} } @diagonalDest;
        if (scalar @rightDest) {
            my $rightmost = max(@rightDest);
            my $c1 = $self->{thisCommitColumn} * 3 + 1;
            my $c2 = $rightmost * 3 - 1;
            my $ucount = $c2 - $c1 - 1;
            substr($extraLine1, $c1, 1) = '\\';
            substr($extraLine1, $c1 + 1, $ucount) = ('_' x $ucount);
            substr($extraLine2, $_ * 3 - 1, 1) = '\\' foreach @rightDest;
        }

        # is there a parent in this column?
        if (grep { $_ eq $self->{thisCommitColumn} } @dest) {
            substr($extraLine1, $self->{thisCommitColumn} * 3, 1) = '|';
            substr($extraLine2, $self->{thisCommitColumn} * 3, 1) = '|';
            substr($extraLine3, $self->{thisCommitColumn} * 3, 1) = '|';
        }

        # draw the other lines that go straight down
        for (my $i = 0; $i < scalar @{$self->{columnStatus}}; $i += 1) {
            if (defined $self->{columnStatus}->[$i] && $self->{columnStatus}->[$i] == ACTIVE) {
                substr($extraLine1, $i * 3, 1) = '|';
                substr($extraLine2, $i * 3, 1) = '|';
                substr($extraLine3, $i * 3, 1) = '|';
            }
        }

        foreach my $column (@dest) {
            substr($extraLine3, $column * 3, 1) = '|';
        }
        push(@{$self->{graphLines}},      $extraLine1, $extraLine2);
        push(@{$self->{graphLinesSaved}}, $extraLine1, $extraLine2);
        $self->{graphContinuationLine} = $extraLine3;
    } else {
        $self->{hasDiagonals} = 0;
        my $extraLine = ' ' x $textColumnCount;
        # draw the lines that go straight down
        for (my $i = 0; $i < scalar @{$self->{columnStatus}}; $i += 1) {
            if (defined $self->{columnStatus}->[$i] && $self->{columnStatus}->[$i] == ACTIVE) {
                substr($extraLine, $i * 3, 1) = '|';
                substr($extraLine, $i * 3, 1) = '|';
                substr($extraLine, $i * 3, 1) = '|';
            }
        }
        $self->{graphContinuationLine} = $extraLine;
    }
    $self->{lastColumnCount} = $self->{columnCount};
}

sub stringLengthExcludingControlSequences {
    my ($self, $string) = @_;
    $string =~ s{\e\[.*?m}{}g;
    return length($string);
}

1;
