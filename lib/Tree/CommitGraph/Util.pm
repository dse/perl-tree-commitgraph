package Tree::CommitGraph::Util;
use warnings;
use strict;

use base 'Exporter';

our @EXPORT = qw();
our @EXPORT_OK = qw(noctlseqs
                    clone
                    terminalPadEnd
                    diagonalsAndLines);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

sub clone {
    my ($obj) = @_;
    if (!defined $obj) {
        return;
    }
    if (ref $obj eq 'ARRAY') {
        return [ map { clone($_) } @$obj ];
    }
    if (ref $obj eq 'HASH') {
        my $result = {};
        foreach my $key (keys %$obj) {
            $result->{$key} = clone($obj->{$key});
        }
        return $result;
    }
    return $obj;
}

sub terminalPadEnd {
    my ($string, $cols) = @_;
    my $length = length(noctlseqs($string));
    my $add = $cols - $length;
    if ($add > 0) {
        return $string . (' ' x $add);
    }
    return $string;
}

sub noctlseqs {
    my ($line) = @_;
    $line =~ s{\e\[(?:\d+(?:\;\d+)*)?m}{}gx;
    return $line;
}

use List::Util qw(max);

1;
