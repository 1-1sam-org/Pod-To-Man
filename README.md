[![Actions Status](https://github.com/raku-community-modules/Pod-To-Man/actions/workflows/linux.yml/badge.svg)](https://github.com/raku-community-modules/Pod-To-Man/actions) [![Actions Status](https://github.com/raku-community-modules/Pod-To-Man/actions/workflows/macos.yml/badge.svg)](https://github.com/raku-community-modules/Pod-To-Man/actions) [![Actions Status](https://github.com/raku-community-modules/Pod-To-Man/actions/workflows/windows.yml/badge.svg)](https://github.com/raku-community-modules/Pod-To-Man/actions)

NAME
====

Pod::To::Man - Render Raku POD as Roff for `man(1)`

SYNOPSIS
========

From the command line:

    raku --doc=Man your.rakudoc > your.1

```raku
use Pod::To::Man;

say Pod::To::Man.render(slurp("your.rakudoc"));
```

RESOURCES
=========

  * [http://www.openbsd.org/papers/eurobsdcon2014-mandoc-slides.pdf](http://www.openbsd.org/papers/eurobsdcon2014-mandoc-slides.pdf)

  * [http://mandoc.bsd.lv/man/man.7.html](http://mandoc.bsd.lv/man/man.7.html)

AUTHORS
=======

  * Mike Clarke <clarkema@clarkema.org>

  * Vadim Belman <vrurg@lflat.org>

COPYRIGHT AND LICENSE
=====================

Copyright © 2019-2022 Mike Clarke

Copyright © 2022, 2025 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

