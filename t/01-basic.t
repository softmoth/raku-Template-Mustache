use v6;
use Test;
use Template::Mustache;

is Template::Mustache.render(
        "  \{\{string}}\n",
        ("string" => "---").hash
    ),
    "  ---\n",
    "Standalone interpolation should not alter surrounding whitesp"
        or die;

is Template::Mustache.render(
        "\{\{#a}}\{\{b.c}}\{\{/a}}",
        ("a" => {"b" => {}}, "b" => {"c" => "ERROR"}).hash
    ),
    '',
    "Context Precedence: Dotted names should be resolved against former resolutions"
        or die;

is Template::Mustache.render("\{\{=<\% \%>=}}(<\%text\%>)", {text => 'Hey!'}), '(Hey!)', "delimiter change"
    or die;
is Template::Mustache.render(q,Comment -->{{! not matched } in comment }}<-- Done.,, {}), 'Comment --><-- Done.', 'Comment with unmatched }';

is Template::Mustache.render(q,abc {{foo}} def,, {foo => 123}), 'abc 123 def', '{{var}} substitution';

is Template::Mustache.render(q,{{foo}} {{=<% %>=}} <% foo %> {{ foo }},, {foo => 123}), '123  123 {{ foo }}', '{{=delim=}} substitution';

done-testing;
