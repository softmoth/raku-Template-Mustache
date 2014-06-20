Perl6 implementation of http://mustache.github.io/

# Tests

To run tests, clone git@github.com:mustache/spec.git into ../mustache-spec, then

    PERL6LIB=./lib prove -e perl6 -v t/00-specs.t

# TODO

This is a first pass, and very rough. Much is to be improved.

- read templates from files
- lambda support
- object support (not just hashes and arrays)
- flexible template loader, similar to PHP mustache
- actually, borrow other features from PHP mustache, too
