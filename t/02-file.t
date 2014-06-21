v6;
use Test;
use Template::Mustache;

plan 5;

my $stache = Template::Mustache.new(:from<t/views>);

is $stache.render('hello', { :name<Jimmy> }), "Hello, Jimmy.\n", "Basic file template";
is $stache.render('hello', { :name<Jimmy> }, :from(False)), 'hello', "Direct load with :from(False)";
is $stache.render('hello', { :name<Jimmy> }), "Hello, Jimmy.\n", "Remembers original \$!from";
is $stache.render('not-found', {}), '', "Renders empty template if file not found";
is $stache.render('partial', { :name<Jimmy> }),
    "Inline Hello, Jimmy.\n.\nNo indent:\nHello, Jimmy.\n.\nWith indent:\n\tHello, Jimmy.\n.\n",
    "Partial loads from file";

done;
