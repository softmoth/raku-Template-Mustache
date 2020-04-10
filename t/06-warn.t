use v6;
use Test;
use Template::Mustache;

plan 2;

my $out;

CONTROL {
    default {
        $out ~= "{.Str}\n";
        .resume;
    }
}

Template::Mustache.render('{{missing_field1}} {{missing_field2}} {{missing.field}}\n', {}, :warn);

is elems($out ~~ m:g/'Field not found ❮missing_field' \d '❯'/), 2, 'Warn missing field(s)';
like $out, /'Field not found ❮missing.field❯'/, 'Warn missing . field';

# vim:set ft=perl6:
