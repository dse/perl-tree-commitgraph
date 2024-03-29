package Tree::CommitGraph::Printer;
use warnings;
use strict;

use lib "../..";
use Tree::CommitGraph::Util qw(noctlseqs);

sub new {
    my ($class) = @_;
    my $self = bless({
        graph => [],
        text => [],
        mincol => 24,
        minspace => 6,
        fill => '',
    }, $class);
    return $self;
}

sub graph {
    my ($self, @lines) = @_;
    push(@{$self->{graph}}, @lines);
}

sub text {
    my ($self, @lines) = @_;
    push(@{$self->{text}}, @lines);
}

sub fill {
    my ($self, $fill) = @_;
    $self->{fill} = $fill;
}

sub out {
    my ($self) = @_;
    while (scalar @{$self->{graph}} && scalar @{$self->{text}}) {
        my $graph = shift(@{$self->{graph}});
        my $text  = shift(@{$self->{text}});
        $self->lineout($graph, $text);
    }
}

sub flush {
    my ($self) = @_;
    $self->out();
    if (scalar @{$self->{graph}}) {
        while (scalar @{$self->{graph}}) {
            my $graph = shift(@{$self->{graph}});
            $self->lineout($graph);
        }
    }
    if (scalar @{$self->{text}}) {
        while (scalar @{$self->{text}}) {
            my $text = shift(@{$self->{text}});
            $self->lineout($self->{fill}, $text);
        }
    }
}

sub lineout {
    my ($self, $graph, $text) = @_;
    if (!defined $text || $text eq '') {
        print("$graph\n");
    } else {
        $graph .= ' ' x $self->{minspace};
        $graph .= ' ' x ($self->{mincol} - length(noctlseqs($graph)));
        print("$graph$text\n");
    }
}

1;
