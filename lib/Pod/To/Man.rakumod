unit class Pod::To::Man;

multi sub extract-pod-text(Str:D $pod) {
    $pod
}

multi sub extract-pod-text(Pod::Block:D $pod) {
    [~] $pod.contents.map(&extract-pod-text);
}

sub get-pod-name($pod) {

    # First look for '=NAME' block.
    for $pod<> -> $node {

        for $node.contents -> $cont {

            next unless $cont ~~ Pod::Block::Named;
            next unless $cont.name eq 'NAME';

            return extract-pod-text($cont).subst(/\s+/, '-', :g);

        }

    }

    # If there's no '=NAME' block, look for a paragraph block preceded by a
    # '=head1 NAME' heading.
    for $pod<> -> $node {

        for $node.contents.kv -> $k, $cont {

            next unless $cont ~~ Pod::Heading;
            next unless $cont.level eq '1';
            next unless extract-pod-text($cont) eq 'NAME';
            next if     $k == $node.contents.end;

            my $name-node = $node.contents[$k + 1];

            my $title-str = extract-pod-text($name-node);

            $title-str ~~ / ^ \s* (.*?) \s* [\s+ '-' \s+ .*]? $ /;

            return ~$0.subst(/\s+/, '-', :g);

        }

    }

    return Any;

}

sub pad-str(Str:D $str, Int:D $len) {
    $str ~ (' ' x ($len - $str.chars));
}

sub table2text(Pod::Block::Table:D $pod) {

    my $table;

    my @rows = $pod.contents;
    @rows.push: $pod.headers if +$pod.headers;

    my @cell-lengths = gather for @rows[0].keys -> $i {
        take max @rows>>[$i]>>.chars;
    }

    if $pod.config<caption> {
        $table ~= $pod.config<caption> ~ "\n";
    }

    if +$pod.headers {
        $table ~= join(' | ', gather for $pod.headers.kv -> $k, $v {
            take pad-str($v, @cell-lengths[$k]);
        }) ~ "\n";
        $table ~= "{'=' x (3 * (+$pod.headers - 1) + @cell-lengths.sum)}\n";
    }

    for $pod.contents -> $row {
        $table ~= join(' | ', gather for $row.kv -> $k, $v {
            take pad-str($v, @cell-lengths[$k]);
        }) ~ "\n";
    }

    return $table;

}


sub escape(Str:D $s) {
    $s.subst(:g, /\-/, Q'\-')
        .subst(:g, '.', Q'\&.');
}

sub head2man($heading) {
    qq[.SH "{$heading.uc.&escape}"\n]
}

sub pfx(Str:D $s) { $*POD2MAN-PFX = $s }

method para-ctx(&code, Int:D :$shift = 0, Int:D :$nest = 0) {
    my $*POD2MAN-PFX = "";
    my $rs = $shift + $*POD2MAN-NESTING;
    do {
        temp $*POD2MAN-NESTING = $nest;
        (".RS 2n\n" x $rs) ~ &code() ~ ("\n.RE" x $rs)
    }
}

proto method pod-node(|) {*}

multi method pod-node(Positional:D \pod) {
    # A list of nodes creates a new context.
    my @out;
    self.para-ctx: {
        for pod<> -> $node {
            my $pfx = "";
            if $node ~~ Pod::Block::Para {
                $pfx = $*POD2MAN-PFX;
                pfx "";
            }
            @out.push: $pfx ~ self.pod-node($node)
        }
        @out.join("\n")
    }
}

multi method pod-node(Pod::Heading:D $pod) {
    pfx "\n";
    my $macro = $pod.level == 1 ?? '.SH' !! '.SS';
    $macro ~ " " ~ $pod.contents.map({ self.pod-node($_) }).join
}
multi method pod-node(Pod::Block::Named:D $pod) {
    given $pod.name {
        when 'pod' { self.pod-node($pod.contents) }
        when 'para' { $pod.contents.map({ self.pod-node($_) }).join(' ') }
        default { head2man($pod.name) ~ self.pod-node($pod.contents); }
    }
}
multi method pod-node(Pod::Block::Code:D $pod) {
    pfx ".P\n";
    qq{\n.RS 4m\n.EX\n}
        ~ $pod.contents.map({ self.pod-node($_) }).join
        ~ "\n.EE\n.RE"
}
multi method pod-node(Pod::Block::Para $pod) {
    pfx "\n";
    $pod.contents.map({ self.pod-node($_) }).join
}

multi method pod-node(Pod::Defn $pod) {
    pfx ".P\n";
    ".TP\n.B "
        ~ self.para-ctx({ self.pod-node($pod.term) })
        ~ "\n"
        ~ self.para-ctx({ self.pod-node($pod.contents) })
}

multi method pod-node(Pod::Item $pod) {
    pfx "\n";
    self.para-ctx: :shift($pod.level - 1), :nest(1), {
        ".IP \\(bu 2m\n"
            ~ $pod.contents.map({ self.pod-node($_) }).join("\n.IP\n").chomp;
    }
}

# Generate a text version of the given pod table, then stuff it into a code
# block. When I was writing this, I did not realize man roff had macros for
# doing tables as apparently it's in tbl(1) instead of man(7).
# TODO: Use man table macros instead.
multi method pod-node(Pod::Block::Table:D $pod) {

    my $table = table2text($pod);

    self.pod-node(Pod::Block::Code.new(:contents($table)));

}

# Code adapted from Pod::To::Text
multi method pod-node(Pod::Block::Declarator:D $pod) {

    next unless $pod.WHEREFORE.WHY;

    my $man = do given $pod.WHEREFORE {
        when Method {
            my $res = ".SS method $_.name()\n";
            my @params = $_.signature.params.skip;
            @params.pop if @params.tail.name eq '%_';
            $res ~= self.pod-node(Pod::Block::Code.new(
                :contents("method $_.name() {signature2text(@params, $_.returns)}\n")
            ));
        }
        when Sub {
            my $res = ".SS sub $_.name()\n";
            $res ~= self.pod-node(Pod::Block::Code.new(
                :contents("sub $_.name() {signature2text($_.signature.params, $_.returns)}\n")
            ));
        }
        when Attribute {
            my $res = ".SS attribute $_.name()\n";
            $res ~= self.pod-node(Pod::Block::Code.new(
                :contents("has $_.gist()\n")
            ));
        }
        when .HOW ~~ Metamodel::EnumHOW {
            my $res = ".SS enum $_.raku()\n";
            $res ~= self.pod-node(Pod::Block::Code.new(
                :contents(
                    "enum $_.raku() " ~
                    signature2text($_.enums.pairs.sort: { .value }) ~
                    "\n"
                )
            ));
        }
        when .HOW ~~ Metamodel::ClassHOW {
            my $res = ".SS class $_.raku()\n";
        }
        when .HOW ~~ Metamodel::ModuleHOW {
            my $res = ".SS module $_.raku()\n";
        }
        when .HOW ~~ Metamodel::SubsetHOW {
            my $res = ".SS subset $_.raku()\n";
            $res ~= self.pod-node(Pod::Block::Code.new(
                :contents("subset $_.raku() of $_.^refinee().raku()")
            ));
        }
        when .HOW ~~ Metamodel::PackageHOW {
            my $res = ".SS package $_.raku()\n";
        }
        default {
            ''
        }
    }

    if my $why = $pod.WHEREFORE.WHY.contents.map({ escape $_ }) {
        $man ~= "\n.PP\n$why\n";
    }

}

# Taken from Pod::To::Text
sub signature2text($params, Mu $returns?) {

    my $result = '(';

    if $params.elems {
        $result ~= "\n\t" ~ $params.map(&param2text).join("\n\t");
    }
    unless $returns<> =:= Mu {
        $result ~= "\n\t--> " ~ $returns.raku;
    }
    if $result.chars > 1 {
        $result ~= "\n";
    }
    $result ~= ')';
    return $result;

}

# Taken from Pod::To::Text
sub param2text($p) {
    $p.raku ~ ',' ~ ( $p.WHY ?? ' # ' ~ $p.WHY !! ' ');
}

multi method pod-node(Pod::FormattingCode $pod) {
    return '' if $pod.type eq 'Z';
    my $text = $pod.contents.map({ self.pod-node($_) }).join;

    given $pod.type {
        when 'B' { "\\fB$text\\fR" }
        when 'I' { "\\fI$text\\fR" }
        when 'U' { "\\fI$text\\fR" }
        when 'F' { "\\fI$text\\fR" }
        when 'C' { $text }
        when 'L' { $text ~ ($*POD2MAN-URLS and $pod.meta[0] ?? [' [', $pod.meta[0], ']'].join !! ''); }
        default { $text }
    }

}

multi method pod-node(Pod::Block::Comment:D $pod) {
    Empty;
}

multi method pod-node(Str:D $pod) {
    escape($pod);
}

multi method pod-node(Any $pod) {
    die "Unknown POD element of type '" ~ $pod.^name ~ "': " ~ $pod.raku
}

method pod2man(
    $pod,
    Str:D  :$program = get-pod-name($pod) // $*PROGRAM.basename,
    Str:D  :$section = $*PROGRAM.basename ~~ / '.' [ 'pm6' | 'rakumod' ] $ / ?? '3rakumod' !! '1',
    Date:D :$date = now.Date,
    Str:D  :$version = $*RAKU.compiler.gist,
    Str:D  :$center = "User Contributed Raku Documentation",
    Bool:D :$urls = True,
) {
    my $*POD2MAN-NESTING = 0;
    my $*POD2MAN-URLS = $urls;

    qq:to/HERE/;
.\\" Automatically generated by Pod::To::Man {$?DISTRIBUTION.meta<ver>}
.\\"
.pc
.TH $program $section "$date" "$version" "$center"
{self.para-ctx: { self.pod-node($pod) }}
HERE

}

method pod2roff($pod) {
    self.para-ctx: { self.pod-node($pod) }
}

method render($pod) {

    my %envmap = (
        RAKUDOC2MAN_PROGRAM => { program => $_;      },
        RAKUDOC2MAN_SECTION => { section => $_;      },
        RAKUDOC2MAN_DATE    => { date    => $_.Date; },
        RAKUDOC2MAN_VERSION => { version => $_;      },
        RAKUDOC2MAN_CENTER  => { center  => $_;      },
        RAKUDOC2MAN_URLS    => { urls    => ?+$_;    },
    );

    my %args = gather for %envmap.kv -> $k, $v {
        next unless %*ENV{$k}.defined;
        take $v(%*ENV{$k});
    }

    self.pod2man($pod, |%args);
}



=begin pod

=head1 NAME

Pod::To::Man - Render Rakudoc as Roff for man

=head1 SYNOPSIS

From the command line:

=begin output

raku --doc=Man your.rakudoc > your.1

=end output

From your scripts:

=begin code :lang<raku>

use Pod::To::Man;

say Pod::To::Man.pod2man($=pod);

=end code

=head1 DESCRIPTION

Pod::To::Man is a Raku module that converts a given Rakudoc (pod6) structure
to formatted *roff input, suitable for displaying via the C<man(1)> program.

This module also comes with the C<rakudoc2man> program, which is a front-end to
Pod::To::Man that is a more robust alternative to using Pod::To::Man with Raku's
builtin C<--doc> renderer.

=head2 Methods

=head3 pod2man

=begin code :lang<raku>
method pod2man(
    $pod,
    Str  :$program,
    Str  :$section,
    Date :$date,
    Str  :$version,
    Str  :$center,
    Bool :$urls,
)
=end code

C<pod2man> converts a given pod structure to *roff, returning the string of
formatted *roff.

C<:$program> will be the name C<pod2man> will use as the name of the manpage.
By default, C<pod2man> will try to determine the manpage name by looking for
the program name specified by any C<=head1 NAME> or C<=NAME> blocks/text. If it
cannot determine the name to use from those, it will default to the value of
C<$*PROGRAM.basename>.

C<:$section> will be the manual section C<pod2man> will use. See
C<man-pages(7)> for more information on the conventions for manpage sections.
If C<$*PROGRAM.basename> ends in the C<'.pm6'> or C<'.rakumod'> suffix, the
section will be C<'3rakumod'>. Otherwise, defaults to C<'1'>.

C<:$date> is the date to use for the manpage. Defaults to the value of
C<now.Date>.

C<:$version> is the version to use for the manpage heading. Defaults to
C<$*RAKU.compiler.gist>, which will look something like
C<'rakudo (20XX.XX)'>.

C<:$center> is the text to display in the center of the manpage heading.
Defaults to C<"User Contributed Raku Documentation">.

C<:$urls> is a boolean determining whether to generate URLs for C<'L<>'> links.
Defaults to C<True>.

=head3 render

=begin code :lang<raku>
method render($pod)
=end code

C<render> is basically the same thing as C<pod2man>, but customization is done
through environment variables instead of method parameters. This is because it
allows the render to be customized when using the C<--doc> option in Raku.
If you're using Pod::To::Man in your code directly, you should just use
C<pod2man>.

The following environment variables are supported, each corresponding to their
respective C<pod2man> parameter.

=item C<RAKUDOC2MAN_PROGRAM>
=item C<RAKUDOC2MAN_SECTION>
=item C<RAKUDOC2MAN_DATE>
=item C<RAKUDOC2MAN_VERSION>
=item C<RAKUDOC2MAN_CENTER>
=item C<RAKUDOC2MAN_URLS>

Most of them accept the same values as their C<pod2man> counterparts.
C<RAKUDOC2MAN_DATE> must be given a date string following the C<YYYY-MM-DD>
format. C<RAKUDOC2MAN_URLS> must be given a number, with C<0> equating to
C<False> and any non-zero value being C<True>.

=head3 pod2roff

=begin code :lang<raku>
method pod2roff($pod)
=end code

This method exists only for compatibility reasons. You should use C<pod2man>
instead.

=head1 BUGS

Don't be ridiculous...

Report bugs on this project's GitHub page,
L<https://github.com/1-1sam-org/Pod-To-Man>.

=head1 AUTHORS

=item Mike Clarke <clarkema@clarkema.org>
=item Vadim Belman <vrurg@lflat.org>
=item Samuel Young <samyoung12788@gmail.com>

=head1 COPYRIGHT AND LICENSE

=item Copyright © 2019-2022 Mike Clarke
=item Copyright © 2022, 2025 Raku Community
=item Copyright © 2025 Samuel Young

This library is free software; you can redistribute it and/or modify it under
the Artistic License 2.0.

=head1 SEE ALSO

man(1), roff(1), man(7), man-pages(7)

=end pod

# vim: expandtab shiftwidth=4
