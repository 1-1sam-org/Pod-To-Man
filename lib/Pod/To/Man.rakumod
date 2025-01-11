unit class Pod::To::Man;

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
        ".IP \\(bu 2m\n" ~ $pod.contents.map({ self.pod-node($_) }).join("\n.IP\n").chomp
    }
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
        when 'L' { $text ~ ($pod.meta[0] ?? [' [', $pod.meta[0], ']'].join !! ''); }
        default { $text }
    }

}
multi method pod-node(Str:D $pod) {
    escape($pod);
}

multi method pod-node(Any $pod) {
    die "Unknown POD element of type '" ~ $pod.^name ~ "': " ~ $pod.raku
}

method pod2man($pod, Str:D :$program = $*PROGRAM.basename) {
    my $*POD2MAN-NESTING = 0;
    qq«.pc\n.TH $program 1 {Date.today}\n»
        ~ self.para-ctx: { self.pod-node($pod) }
}

method pod2roff($pod) {
    self.para-ctx: { self.pod-node($pod) }
}

method render($pod, Str:D :$program = $*PROGRAM.basename) {
    self.pod2man($pod, :program($program));
}

# vim: expandtab shiftwidth=4
