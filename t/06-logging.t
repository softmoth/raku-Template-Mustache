use Test;
use Template::Mustache;

plan 3;

my $out;

CONTROL {
    default {
        $out ~= "{.Str}\n";
        .resume;
    }
}

Template::Mustache.render:
    '{{missing_field1}} {{missing_field2}} {{missing.field}}\n', {},
    :log-level<Warn>;

is elems($out ~~ m:g/'Field not found ❮missing_field' \d '❯'/), 2,
    'Warn missing field(s)';
like $out, /'Field not found ❮missing.field❯'/,
    'Warn missing . field';

my $m = Template::Mustache.new: :log-level<Info>;
$m.logger.routines<Warn> = &die;

dies-ok { $m.render: '{{missing}}', {} },
    "Set log routine for Warn level to \&die";

# vim:set ft=perl6:
