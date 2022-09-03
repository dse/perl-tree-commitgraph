package Tree::CommitGraph::Util;
use warnings;
use strict;

use base 'Exporter';

our @EXPORT = qw();
our @EXPORT_OK = qw(clone stringLengthExcludingControlSequences terminalPadEnd);
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

sub stringLengthExcludingControlSequences {
    my ($string) = @_;
    $string =~ s{\e\[.*?m}{}g;
    return length($string);
}

sub terminalPadEnd {
    my ($string, $cols) = @_;
    my $length = stringLengthExcludingControlSequences($string);
    my $add = $cols - $length;
    if ($add > 0) {
        return $string . (' ' x $add);
    }
    return $string;
}

1;
