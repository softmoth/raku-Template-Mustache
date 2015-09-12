use v6;
use Test;
use Template::Mustache;

plan 8;

my $stache = Template::Mustache.new(:from<views>);

is $stache.render('hello', { :name<Jimmy> }), "Hello, Jimmy.\n", 'Basic file template';
is $stache.render('hello', { :name<Jimmy> }, :literal), 'hello', 'Literal string override';
is $stache.render('hello', { :name<Jimmy> }), "Hello, Jimmy.\n", 'Remembers original $!from';
is $stache.render('not-found', {}, :!literal), '', 'Renders empty template if file not found';
is $stache.render('partial', { :name<Jimmy> }),
    q:to<EOF>,
    Inline Hello, Jimmy.
    .
    No indent:
    Hello, Jimmy.
    .
    With indent:
          Hello, Jimmy.
    .
    EOF
    'Partial loads from file';

my $altext = Template::Mustache.new(:from<views>, :extension<.ms>);
is $altext.render('hi', { :name<Jimmy> }), "Hi, Jimmy.\n", 'Alternate extension';

my $oddext = Template::Mustache.new(:from<views>, :extension<.blaaarg>);
is $oddext.render('hi', { :name<Jimmy> }, :extension<.ms>),
    "Hi, Jimmy.\n",
    'Instance extension can be overridden';

is Template::Mustache.render('hello', { :name<Jimmy> },
        :from($*SPEC.catdir($*CWD, 't', 'views'))),
    "Hello, Jimmy.\n",
    'Absolute path to templates';

done-testing;
