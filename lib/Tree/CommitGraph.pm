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
    $self->{revmark} = {};
    $self->{isatty} = 0;
    $self->{started} = 0;
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

sub start {
    my ($self) = @_;
    return if $self->{started};
    $self->{started} = 1;
    my $nmarks = scalar keys %{$self->{mark}};
    if ($nmarks >= 2) {
        $self->{columnWidth} = 2 + $nmarks;
    }
}

sub processCommit {
    my ($self, %args) = @_;
    $self->start();
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
        my $append = ' ' x $self->{columnWidth};

        if ($i == $self->{thisCommitColumn}) {
            if (defined $self->{revmark} && exists $self->{revmark}->{$self->{commit}}) {
                my @key = sort keys %{$self->{revmark}->{$self->{commit}}};
                my $key = join('', @key);
                my $HILIT = $self->{isatty} ? "\e[1m" : "";
                my $RESET = $self->{isatty} ? "\e[0m" : "";
                $append = $self->terminalPadEnd("*${HILIT}${key}${RESET}", $self->{columnWidth});
            } else {
                substr($append, 0, 1) = '*';
            }
        } elsif (!defined $self->{columnStatus}->[$i]) {
            # no change
        } elsif ($self->{columnStatus}->[$i] == 1) {
            substr($append, 0, 1) = '|';
        } else {
            # no change
        }
        $graphLine .= $append;
    }
    push(@{$self->{graphLines}}, $graphLine);
    push(@{$self->{graphLinesSaved}}, $graphLine);

    my $maxCount = max($self->{columnCount}, $self->{lastColumnCount} // 0);
    my $textColumnCount = $maxCount * $self->{columnWidth};

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

    my $cw = $self->{columnWidth};
    my $secondLast = $cw - 2;

    my $maxCount = max($self->{columnCount}, $self->{lastColumnCount} // 0);
    my $textColumnCount = $maxCount * $cw;

    # diagonal lines from this commit to parents.  If there aren't
    # any, we may not need to print the extra lines at all.
    my @diagonalDest = grep { $_ ne $self->{thisCommitColumn} } @dest;
    if (scalar @diagonalDest) {
        $self->{hasDiagonals} = 1;

        my @extraLines = (' ' x $textColumnCount) x 3;

        # / lines go to these columns
        my @leftDest  = grep { $_ < $self->{thisCommitColumn} } @diagonalDest;
        if (scalar @leftDest) {
            my $leftmost = min(@leftDest);
            my $c1 = $self->{thisCommitColumn} * $cw - 1;
            my $c2 = $leftmost * $cw + 1;
            my $ucount = $c1 - $c2 - 1;
            substr($extraLines[0], $c2 + 1, $ucount) = ('_' x $ucount);
            substr($extraLines[0], $c1, 1) = '/';
            substr($extraLines[1], $_ * $cw + 1, 1) = '/' foreach @leftDest; # FIXME
        }

        # \ lines go to these columns
        my @rightDest = grep { $_ > $self->{thisCommitColumn} } @diagonalDest;
        if (scalar @rightDest) {
            my $rightmost = max(@rightDest);
            my $c1 = $self->{thisCommitColumn} * $cw + 1;
            my $c2 = $rightmost * $cw - 1;
            my $ucount = $c2 - $c1 - 1;
            substr($extraLines[0], $c1 + 1, $ucount) = ('_' x $ucount);
            substr($extraLines[0], $c1, 1) = '\\';
            substr($extraLines[1], $_ * $cw - 1, 1) = '\\' foreach @rightDest; # FIXME
        }

        # is there a parent in this column?
        if (grep { $_ eq $self->{thisCommitColumn} } @dest) {
            for (my $j = 0; $j < 3; $j += 1) {
                substr($extraLines[$j], $self->{thisCommitColumn} * $cw, 1) = '|';
            }
        }

        # draw the other lines that go straight down
        for (my $i = 0; $i < scalar @{$self->{columnStatus}}; $i += 1) {
            if (defined $self->{columnStatus}->[$i] && $self->{columnStatus}->[$i] == ACTIVE) {
                for (my $j = 0; $j < 3; $j += 1) {
                    substr($extraLines[$j], $i * $cw, 1) = '|';
                }
            }
        }

        foreach my $column (@dest) {
            substr($extraLines[2], $column * $cw, 1) = '|';
        }

        my $lastExtraLine = splice(@extraLines, -1, 1);
        push(@{$self->{graphLines}},      @extraLines);
        push(@{$self->{graphLinesSaved}}, @extraLines);
        $self->{graphContinuationLine} = $lastExtraLine;
    } else {
        $self->{hasDiagonals} = 0;
        my $extraLine = ' ' x $textColumnCount;
        # draw the lines that go straight down
        for (my $i = 0; $i < scalar @{$self->{columnStatus}}; $i += 1) {
            if (defined $self->{columnStatus}->[$i] && $self->{columnStatus}->[$i] == ACTIVE) {
                substr($extraLine, $i * $cw, 1) = '|';
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

sub terminalPadEnd {
    my ($self, $string, $cols) = @_;
    my $length = $self->stringLengthExcludingControlSequences($string);
    my $add = $cols - $length;
    if ($add > 0) {
        return $string . (' ' x $add);
    }
    return $string;
}

1;
