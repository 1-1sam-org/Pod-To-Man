NAME
====

Pod::To::Man - Render Rakudoc as Roff for man

SYNOPSIS
========

From the command line:

    raku --doc=Man your.rakudoc > your.1

From your scripts:

```raku
use Pod::To::Man;

say Pod::To::Man.pod2man($=pod);
```

DESCRIPTION
===========

Pod::To::Man is a Raku module that converts a given Rakudoc (pod6) structure to formatted *roff input, suitable for displaying via the `man(1)` program.

This module also comes with the `rakudoc2man` program, which is a front-end to Pod::To::Man that is a more robust alternative to using Pod::To::Man with Raku's builtin `--doc` renderer.

Methods
-------

### pod2man

```raku
method pod2man(
    $pod,
    Str  :$program,
    Str  :$section,
    Date :$date,
    Str  :$version,
    Str  :$center,
    Bool :$urls,
)
```

`pod2man` converts a given pod structure to *roff, returning the string of formatted *roff.

`:$program` will be the name `pod2man` will use as the name of the manpage. By default, `pod2man` will try to determine the manpage name by looking for the program name specified by any `=head1 NAME` or `=NAME` blocks/text. If it cannot determine the name to use from those, it will default to the value of `$*PROGRAM.basename`.

`:$section` will be the manual section `pod2man` will use. See `man-pages(7)` for more information on the conventions for manpage sections. If `$*PROGRAM.basename` ends in the `'.pm6'` or `'.rakumod'` suffix, the section will be `'3rakumod'`. Otherwise, defaults to `'1'`.

`:$date` is the date to use for the manpage. Defaults to the value of `now.Date`.

`:$version` is the version to use for the manpage heading. Defaults to `$*RAKU.compiler.gist`, which will look something like `'rakudo (20XX.XX)'`.

`:$center` is the text to display in the center of the manpage heading. Defaults to `"User Contributed Raku Documentation"`.

`:$urls` is a boolean determining whether to generate URLs for `'L<>'` links. Defaults to `True`.

### render

```raku
method render($pod)
```

`render` is basically the same thing as `pod2man`, but customization is done through environment variables instead of method parameters. This is because it allows the render to be customized when using the `--doc` option in Raku. If you're using Pod::To::Man in your code directly, you should just use `pod2man`.

The following environment variables are supported, each corresponding to their respective `pod2man` parameter.

  * `RAKUDOC2MAN_PROGRAM`

  * `RAKUDOC2MAN_SECTION`

  * `RAKUDOC2MAN_DATE`

  * `RAKUDOC2MAN_VERSION`

  * `RAKUDOC2MAN_CENTER`

  * `RAKUDOC2MAN_URLS`

Most of them accept the same values as their `pod2man` counterparts. `RAKUDOC2MAN_DATE` must be given a date string following the `YYYY-MM-DD` format. `RAKUDOC2MAN_URLS` must be given a number, with `0` equating to `False` and any non-zero value being `True`.

### pod2roff

```raku
method pod2roff($pod)
```

This method exists only for compatibility reasons. You should use `pod2man` instead.

BUGS
====

Don't be ridiculous...

Report bugs on this project's GitHub page, [https://github.com/1-1sam-org/Pod-To-Man](https://github.com/1-1sam-org/Pod-To-Man).

AUTHORS
=======

  * Mike Clarke <clarkema@clarkema.org>

  * Vadim Belman <vrurg@lflat.org>

  * Samuel Young <samyoung12788@gmail.com>

COPYRIGHT AND LICENSE
=====================

  * Copyright © 2019-2022 Mike Clarke

  * Copyright © 2022, 2025 Raku Community

  * Copyright © 2025 Samuel Young

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

SEE ALSO
========

man(1), roff(1), man(7), man-pages(7)

