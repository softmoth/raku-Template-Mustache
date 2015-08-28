Perl6 implementation of Mustache templates, [http://mustache.github.io/](http://mustache.github.io/).

[![Build Status](https://travis-ci.org/softmoth/p6-Template-Mustache.svg?branch=master)](https://travis-ci.org/softmoth/p6-Template-Mustache)

Synopsis
========

    use Template::Mustache;

    # Call .render as a class method
    Template::Mustache.render('Hello, {{planet}}!', { planet => 'world' }).say;

    # Or instantiate an instance
    my $stache = Template::Mustache.new: :from<./views>;

    # Subroutines are called
    say $stache.render('The time is {{time}}', {
        time => { ~DateTime.new($now).local }
    });

    my @people =
        { :name('James T. Kirk'), :title<Captain> },
        { :name('Wesley'), :title('Dread Pirate'), :emcee },
        { :name('Dana Scully'), :title('Special Agent') },
        ;

    # See this template in **[./t/views/roster.mustache](./t/views/roster.mustache)**
    $stache.render('roster', { :@people }).say;

    my %context =
        event => 'Masters of the Universe Convention',
        :@people,
        ;
    my %partials =
        welcome =>
            qq:b{Welcome to the {{event}}! We’re pleased to have you here.\n\n},
        ;

    # See this result in **[./t/50-readme.t](./t/50-readme.t)**
    Template::Mustache.render(q:to/EOF/,
            {{> welcome}}
            {{> roster}}

                Dinner at 7PM in the Grand Ballroom. Bring a chair!
            EOF
        %context,
        :from([%partials, './views'])
    ).say;

More Examples and Tests
=======================

The Mustache spec provides a wealth of examples to demonstrate exactly how the format behaves.

[https://github.com/mustache/spec/tree/master/specs/](https://github.com/mustache/spec/tree/master/specs/)

To run tests,

    # NB Ensure you are using the default 'perl6' branch, not 'master'
    git clone git@github.com:softmoth/mustache-spec.git ../mustache-spec
    PERL6LIB=./lib prove -e perl6 -v

All spec tests pass: [https://travis-ci.org/softmoth/p6-Template-Mustache](https://travis-ci.org/softmoth/p6-Template-Mustache). The perl6 branch just updates the .json files to match the .yml sources (needed until someone writes a Perl 6 YAML parser, hint, hint), and adds perl6 lambda code strings for that portion of the specs.

Other Mustache Implementations
==============================

There are many, many Mustache implementations in various languages. Some of note are:

  * The original Ruby version [https://github.com/defunkt/mustache](https://github.com/defunkt/mustache)

  * Twitter's hogan.js [https://github.com/twitter/hogan.js](https://github.com/twitter/hogan.js)

  * mustache.java [https://github.com/spullara/mustache.java](https://github.com/spullara/mustache.java)

  * GRMustache (Objective C) [https://github.com/groue/GRMustache](https://github.com/groue/GRMustache)

  * mustache.php [https://github.com/bobthecow/mustache.php](https://github.com/bobthecow/mustache.php)

TODO
====

  * object support (not just hashes and arrays)

  * parsed template caching

  * global helpers (context items that float at the top of the stack)

  * template inheritance: [https://github.com/mustache/spec/issues/38](https://github.com/mustache/spec/issues/38), etc.

  * database loader

  * pragmas (FILTERS?)
