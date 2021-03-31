use Test;
use Template::Mustache;

plan 1;

my $m = Template::Mustache.new: :from<views>;

is $m.render('Hello, {{promise}}!', { promise => start {sleep 1; "world"} }),
    "Hello, world!",
    'Interpolate promise object';

# vim:set ft=raku:
