package Complete::Bash::History;

our $DATE = '2015-01-03'; # DATE
our $VERSION = '0.02'; # VERSION

use 5.010001;
use strict;
use warnings;

#use Complete;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
                       complete_cmdline_from_hist
               );

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    links => [
        {url => 'pm:Complete'},
    ],
};

$SPEC{complete_cmdline_from_hist} = {
    v => 1.1,
    summary => 'Complete command line from recent entries in bash history',
    description => <<'_',

This routine will search your bash history file (recent first a.k.a. backward)
for entries for the same command, and complete option with the same name or
argument in the same position. For example, if you have history like this:

    cmd1 --opt1 val arg1 arg2
    cmd1 --opt1 valb arg1b arg2b arg3b
    cmd2 --foo

Then if you do:

    complete_cmdline_from_hist(comp_line=>'cmd1 --bar --opt1 ', comp_point=>18);

then it means the routine will search for values for option `--opt1` and will
return:

    ["val", "valb"]

Or if you do:

    complete_cmdline_from_hist(comp_line=>'cmd1 baz ', comp_point=>9);

then it means the routine will search for second argument (argv[1]) and will
return:

    ["arg2", "arg2b"]

_
    args => {
        path => {
            summary => 'Path to `.bash_history` file',
            schema => 'str*',
            description => <<'_',

Defaults to `~/.bash_history`.

If file does not exist or unreadable, will return empty completion answer.

_
        },
        max_hist_lines => {
            summary => 'Stop searching after this amount of history lines',
            schema => ['int*'],
            default => 3000,
            description => <<'_',

-1 means unlimited (search all lines in the file).

Timestamp comments are not counted.

_
        },
        max_result => {
            summary => 'Stop after finding this number of distinct results',
            schema => 'int*',
            default => 100,
            description => <<'_',

-1 means unlimited.

_
        },
        cmdline => {
            summary => 'Command line, defaults to COMP_LINE',
            schema => 'str*',
        },
        point => {
            summary => 'Command line, defaults to COMP_POINT',
            schema => 'int*',
        },
    },
    result_naked=>1,
};
sub complete_cmdline_from_hist {
    require Complete::Bash;
    require Complete::Util;
    require File::ReadBackwards;

    my %args = @_;

    my $path = $args{path} // "$ENV{HOME}/.bash_history";
    my $fh = File::ReadBackwards->new($path) or return [];

    my $max_hist_lines = $args{max_hist_lines} // 3000;
    my $max_result     = $args{max_result}     // 100;

    my $word;
    my ($cmd, $opt, $pos);
    my $cl = $args{cmdline} // $ENV{COMP_LINE} // '';
    my $res = Complete::Bash::parse_options(
        cmdline => $cl,
        point   => $args{point} // $ENV{COMP_POINT} // length($cl),
    );
    $cmd = $res->{words}[0];
    my $which;
    if ($res->{word_type} eq 'opt_val') {
        $which = 'opt_val';
        $opt   = $res->{words}->[$res->{cword}-1];
        $word  = $res->{words}->[$res->{cword}];
    } elsif ($res->{word_type} eq 'opt_name') {
        $which = 'opt_name';
        $opt   = $res->{words}->[ $res->{cword} ];
        $word  = $opt;
    } elsif ($res->{word_type} =~ /\Aarg,(\d+)\z/) {
        $which = 'arg';
        $pos  = $1;
        $word = $res->{words}->[$res->{cword}];
    } else {
        return [];
    }

    my %res;
    my $num_hist_lines = 0;
    while (my $line = $fh->readline) {
        chomp($line);

        # skip timestamp comment
        next if $line =~ /^#\d+$/;

        last if $max_hist_lines >= 0 && $num_hist_lines++ >= $max_hist_lines;

        my ($hwords, $hcword) = @{ Complete::Bash::parse_cmdline($line, 0) };
        next unless @$hwords;

        # COMP_LINE (and COMP_WORDS) is provided by bash and does not include
        # multiple commands (e.g. in '( foo; bar 1 2<tab> )' or 'foo -1 2 | bar
        # 1 2<tab>', bash already only supplies us with 'bash 1 2' instead of
        # the full command-line. This is different when we try to parse the full
        # command-line from history. Complete::Bash::parse_cmdline() is not
        # sophisticated enough to understand full bash syntax. So currently we
        # don't support multiple/complex statements. We'll need a more
        # proper/feature-complete bash parser for that.

        # strip ad-hoc environment setting, e.g.: DEBUG=1 ANOTHER="foo bar" cmd
        while (1) {
            if ($hwords->[0] =~ /\A[A-Za-z_][A-Za-z0-9_]*=/) {
                shift @$hwords; $hcword--;
                next;
            }
            last;
        }
        next unless @$hwords;

        # get the first word as command name
        my $hcmd = $hwords->[0];
        next unless $hcmd eq $cmd;

        my $hpo = Complete::Bash::parse_options(words=>$hwords, cword=>$hcword);

        if ($which eq 'opt_name') {
            for (keys %{ $hpo->{opts} }) {
                $res{length($_) > 1 ? "--$_":"-$_"}++;
            }
            next;
        }

        if ($which eq 'opt_val') {
            for (@{ $hpo->{opts} // []}) {
                next unless defined;
                $res{$_}++;
            }
            next;
        }

        if ($which eq 'arg') {
            next unless @{ $hpo->{argv} } > $pos;
            $res{ $hpo->{argv}[$pos] }++;
            next;
        }

        die "BUG: invalid which value '$which'";
    }

    Complete::Util::complete_array_elem(
        array => [keys %res],
        word  => $word // '',
    );
}

1;
# ABSTRACT: Complete command line from recent entries in bash history

__END__

=pod

=encoding UTF-8

=head1 NAME

Complete::Bash::History - Complete command line from recent entries in bash history

=head1 VERSION

This document describes version 0.02 of Complete::Bash::History (from Perl distribution Complete-Bash-History), released on 2015-01-03.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FUNCTIONS


=head2 complete_cmdline_from_hist(%args) -> any

Complete command line from recent entries in bash history.

This routine will search your bash history file (recent first a.k.a. backward)
for entries for the same command, and complete option with the same name or
argument in the same position. For example, if you have history like this:

 cmd1 --opt1 val arg1 arg2
 cmd1 --opt1 valb arg1b arg2b arg3b
 cmd2 --foo

Then if you do:

 complete_cmdline_from_hist(comp_line=>'cmd1 --bar --opt1 ', comp_point=>18);

then it means the routine will search for values for option C<--opt1> and will
return:

 ["val", "valb"]

Or if you do:

 complete_cmdline_from_hist(comp_line=>'cmd1 baz ', comp_point=>9);

then it means the routine will search for second argument (argv[1]) and will
return:

 ["arg2", "arg2b"]

Arguments ('*' denotes required arguments):

=over 4

=item * B<cmdline> => I<str>

Command line, defaults to COMP_LINE.

=item * B<max_hist_lines> => I<int> (default: 3000)

Stop searching after this amount of history lines.

-1 means unlimited (search all lines in the file).

Timestamp comments are not counted.

=item * B<max_result> => I<int> (default: 100)

Stop after finding this number of distinct results.

-1 means unlimited.

=item * B<path> => I<str>

Path to `.bash_history` file.

Defaults to C<~/.bash_history>.

If file does not exist or unreadable, will return empty completion answer.

=item * B<point> => I<int>

Command line, defaults to COMP_POINT.

=back

Return value:  (any)
=head1 SEE ALSO


L<Complete>

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Complete-Bash-History>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Complete-Bash-History>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Complete-Bash-History>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
