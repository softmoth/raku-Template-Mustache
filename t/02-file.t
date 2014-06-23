v6;
use Test;
use Template::Mustache;

plan 7;

my $stache = Template::Mustache.new(:from<t/views>);

is $stache.render('hello', { :name<Jimmy> }), "Hello, Jimmy.\n", "Basic file template";
is $stache.render('hello', { :name<Jimmy> }, :literal), 'hello', "Literal string override";
is $stache.render('hello', { :name<Jimmy> }), "Hello, Jimmy.\n", "Remembers original \$!from";
is $stache.render('not-found', {}, :!literal), '', "Renders empty template if file not found";
is $stache.render('partial', { :name<Jimmy> }),
    "Inline Hello, Jimmy.\n.\nNo indent:\nHello, Jimmy.\n.\nWith indent:\n\tHello, Jimmy.\n.\n",
    "Partial loads from file";

my $altext = Template::Mustache.new(:from<t/views>, :extension<.ms>);
is $altext.render('hi', { :name<Jimmy> }), "Hi, Jimmy.\n", "Alternate extension";

my $oddext = Template::Mustache.new(:from<t/views>, :extension<.blaaarg>);
is $oddext.render('hi', { :name<Jimmy> }, :extension<.ms>),
    "Hi, Jimmy.\n",
    "Instance extension can be overridden";
done;
