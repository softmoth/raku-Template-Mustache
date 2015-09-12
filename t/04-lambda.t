use v6;
use Test;
use Template::Mustache;

plan 1;

my $m = Template::Mustache.new: :from<views>;

my $l = 'sub { "world" }';
is $m.render('Hello, {{lambda}}!', { lambda => $l.EVAL }),
    "Hello, world!",
    'Interpolate lambda value';

done-testing;
# vim:set ft=perl6:
