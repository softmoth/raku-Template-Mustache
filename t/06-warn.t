use v6;
use Test;
use Test::Output;
use Template::Mustache;

my $out = output-from {
    try {
        Template::Mustache.render('{{missing_field1}} {{missing_field2}} {{missing.field}}\n', {}, :warn);
    }
}

is elems($out ~~ m:g/'Field not found ❮missing_field' \d '❯'/), 2, 'Warn missing field(s)';
like $out, /'Field not found ❮missing.field❯'/, 'Warn missing . field';

done-testing;
