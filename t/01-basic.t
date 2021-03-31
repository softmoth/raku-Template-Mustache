use Test;
use Template::Mustache;

plan 9;

is Template::Mustache.render(
        Qb[  {{string}}\n],
        { string => '---' }),
    "  ---\n",
    'Standalone interpolation should not alter surrounding whitesp';

is Template::Mustache.render(
        Qb[{{#a}}{{b.c}}{{/a}}],
        { a => {b => {}},
          b => {c => 'ERROR'} }
    ),
    '',
    'Context Precedence: Dotted names should be resolved against former resolutions';

is Template::Mustache.render(
        Qb[{{=<% %>=}}(<%text%> <% text %>)],
        {text => 'Hey!'}),
    '(Hey! Hey!)',
    'delimiter change';

is Template::Mustache.render(
        Qb[Comment -->{{! not matched } in comment }}<-- Done.],
        {}),
    'Comment --><-- Done.',
    'Comment with unmatched }';

is Template::Mustache.render(
        Qb[abc {{foo}} def],
        {foo => 123}),
    'abc 123 def',
    '{{var}} substitution';

is Template::Mustache.render(
        Qb[{{foo}} {{=<% %>=}} <% foo %> {{ foo }}],
        {foo => 123}),
    '123  123 {{ foo }}',
    '{{=delim=}} substitution';

# issue #25: The digit 0 doesn't print
is Template::Mustache.render('Zero: "{{ zero }}"', { zero => 0 }),
    'Zero: "0"',
    'The digit 0 prints';

# issue #29: Triple Mustache doesn't work when the field name
# contains a minus
is Template::Mustache.render(
    '{{{ bar }}}',
    %(:bar) ),
    'True',
    'Triple-mustache substitution works';

is Template::Mustache.render(
    '{{{ bar-x }}}',
    %(:bar-x) ),
    'True',
    'Triple-mustache substitution works when field name contains a minus';

# vim:set ft=raku:
