use Test;
use Template::Mustache;

plan 1;

class TestObj {
    method Str() { "I am your father!" }
    method name() { "TestObj" }
}

my $tm = Template::Mustache.new;
is $tm.render('{{object.name}}: {{object}}', { object => TestObj.new }),
    "TestObj: I am your father!",
    'Object stringifies';

# vim:set ft=raku:
