Perl6 implementation of http://mustache.github.io/

# Tests
To run tests,

    git clone git@github.com:mustache/spec.git ../mustache-spec
    PERL6LIB=./lib prove -e perl6 -v

# TODO
- object support (not just hashes and arrays)
- lambda support
- parsed template caching
- features from PHP mustache (array loader, pragmas, etc.)
- simplify and clean up code
