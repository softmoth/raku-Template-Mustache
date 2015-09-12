use v6;
use Test;
use Template::Mustache;

class TestObj {
    method Str() { "I am your father!" }
}

my $tm = Template::Mustache.new;
is $tm.render('{{object}}', { object => TestObj.new }),
    "I am your father!",
    'Object stringifies';

done-testing;
