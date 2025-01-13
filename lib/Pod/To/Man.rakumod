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
    # '=HEAD1 NAME' heading.
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
        $table ~= "{'=' x (([+] @cell-lengths) + (+$pod.headers - 1) * 3)}\n";
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
        ".IP \\(bu 2m\n" ~ $pod.contents.map({ self.pod-node($_) }).join("\n.IP\n").chomp
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
    Str:D :$program = get-pod-name($pod) // $*PROGRAM.basename,
    Str:D :$section = '1',
) {
    my $*POD2MAN-NESTING = 0;
    qq«.pc\n.TH $program $section {Date.today}\n»
        ~ self.para-ctx: { self.pod-node($pod) }
}

method pod2roff($pod) {
    self.para-ctx: { self.pod-node($pod) }
}

method render(
    $pod,
    Str:D :$program = get-pod-name($pod) // $*PROGRAM.basename,
    Str:D :$section = '1',
) {
    self.pod2man($pod, :program($program), :section($section));
}

# vim: expandtab shiftwidth=4
