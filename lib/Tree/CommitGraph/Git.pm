package Tree::CommitGraph::Git;
use warnings;
use strict;

use lib "$ENV{HOME}/git/dse.d/perl-tree-commitgraph/lib";
use Tree::CommitGraph::2;
use Tree::CommitGraph::Util qw(noctlseqs);

use lib "$ENV{HOME}/git/dse.d/perl-io-pager-self/lib";
use IO::Pager::Self qw(pager);

sub new {
    my ($class) = @_;
    my $self = bless({}, $class);
    $self->{graph} = Tree::CommitGraph::2->new();
    $self->{gitargs} = [];
    return $self;
}

sub run {
    my ($self, @args) = @_;
    if (pager()) {
        push(@{$self->{gitargs}}, '--color=always');
    }
    if ($self->{stdin}) {
        $self->stdin(@args);
    } else {
        $self->git(@args);
    }
}

sub stdin {
    my ($self, @args) = @_;
    $self->fh(\*ARGV);
}

sub git {
    my ($self, @args) = @_;
    my @cmd = (
        'git',
        'log',
        '--parents',
        @{$self->{gitargs}},
        @args
    );
    my $ph;
    if (!open($ph, '-|', @cmd)) {
        die("pipe git: $!\n");
    }
    $self->fh($ph);
}

sub fh {
    my ($self, $fh) = @_;
    local $_ = undef;
    local $/ = "\n";
    while (<$fh>) {
        s{\R\z}{};              # safer chomp
        my $origLine = $_;
        $_ = noctlseqs($_);
        if (s{^commit(?=\s+)}{}) {
            if (s{^
                  (?<commits>(?:\s+[[:xdigit:]]{7,})+)
                  (?=$|\s)}
                 {}x) {
                my @commits = split(' ', $+{commits});
                $self->{graph}->flush();
                $self->{graph}->commit(@commits);
            }
        } else {
            if (s{^
                  (?<commits>
                      \s*[[:xdigit:]]{7,}
                      (?:\s+[[:xdigit:]]{7,})*
                  )}
                {}x) {
                my @commits = split(' ', $+{commits});
                $self->{graph}->flush();
                $self->{graph}->commit(@commits);
            }
        }
        $self->{graph}->textlines($origLine);
    }
    $self->{graph}->flush();
}

1;
