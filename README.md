Perl6 implementation of http://mustache.github.io/

# Synopsis

    use Template::Mustache;
    # Hello, world!
    Template::Mustache.render('Hello, {{planet}}!', { planet => 'world' }).say;

    my @roster =
        { :name('James T. Kirk'), :title<Captain> },
        { :name('Wesley'), :title('Dread Pirate') },
        ;
    my $stache = Template::Mustache.new: :from<./views>;
    $stache.render('roster', { :@roster });

# Tests
To run tests,

    git clone git@github.com:mustache/spec.git ../mustache-spec
    PERL6LIB=./lib prove -e perl6 -v

# TODO
- object support (not just hashes and arrays)
- lambda support
- parsed template caching
- features from PHP mustache:
    - inline loader (POD?)
    - database loader
    - pragmas (FILTERS, inheritance)
    - .new(:helpers())
- simplify and clean up code
