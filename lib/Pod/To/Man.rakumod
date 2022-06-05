unit class Pod::To::Man;

=begin pod

=head1 NAME

Pod::To::Man - Render Raku POD as Roff for C<man(1)>

=head1 SYNOPSIS

From the command line:

    raku --doc=Man your.rakudoc > your.1

=begin code :lang<raku>
use Pod::To::Man;

say Pod::To::Man.render(slurp("your.rakudoc"));
=end code

=head1 RESOURCES

=item L<http://www.openbsd.org/papers/eurobsdcon2014-mandoc-slides.pdf>
=item L<http://mandoc.bsd.lv/man/man.7.html>

=head1 AUTHORS

=item Mike Clarke <clarkema@clarkema.org>
=item Vadim Belman <vrurg@lflat.org>

=head1 COPYRIGHT AND LICENSE

Copyright © 2019-2022 Mike Clarke, © 2022 - Raku Community Authors

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

sub escape(Str:D $s) {
    $s.subst(:g, /\-/, Q'\-')
        .subst(:g, '.', Q'\&.');
}

sub head2man($heading) {
    qq[.SH "{$heading.uc.&escape}"\n]
}

sub pfx(Str:D $s) { $*POD2MAN-PFX = $s }

method para-ctx(&code) {
    my $*POD2MAN-PFX = "";
    &code()
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
    }
    @out.join("\n")
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
    qq{\n.RS 4\n.EX\n}
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
    self.para-ctx: {
        ".IP \\(bu 3m\n" ~ $pod.contents.map({ self.pod-node($_) }).join("\n.IP\n").chomp
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

method pod2man($pod) {
    qq«.pc\n.TH {$*PROGRAM.basename} 1 {Date.today}\n»
        ~ self.para-ctx: { self.pod-node($pod) }
}

method pod2roff($pod) {
    self.para-ctx: { self.pod-node($pod) }
}

method render($pod) {
    self.pod2man($pod);
}
