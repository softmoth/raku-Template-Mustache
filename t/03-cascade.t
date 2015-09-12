use v6;
use Test;
use Template::Mustache;

plan 5;

my $m = Template::Mustache.new: :from<views>;

is $m.render(
        'hello',
        {name => 'Jimmy'},
        :from({ hello => 'override' })
    ),
    'override',
    '.render(:from) overrides instance $.from';

is $m.render(
        'hello',
        {name => 'Jimmy'},
        :from({ foo => 'override' })
    ),
    "Hello, Jimmy.\n",
    '.render(:from) doesn\'t obliterate instance $.from';

is $m.render(
        'partial',
        {name => 'Jimmy'},
        :from({ hello => 'override' })
    ),
    q:to<EOF>,
    Inline override.
    No indent:
    override.
    With indent:
          override.
    EOF
    '.render(:from) overrides instance $.from for partials';

is $m.render(
        'partial',
        {name => 'Jimmy'},
        :from({ foo => 'override' })
    ),
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
    '.render(:from) doesn\'t obliterate instance $.from for partials';

is $m.render(
        'Say {{> hello}}, and {{> hi}}',
        { name => 'Jimmy' },
        :from({ hi => 'find me a {{> hello}}' }),
        :extension(['.ms', '.mustache'])
    ),
    q:to<EOF>,
    Say Hello, Jimmy.
    , and find me a Hello, Jimmy.
    EOF
    'Inline partial can get filesystem partial';

done-testing;
