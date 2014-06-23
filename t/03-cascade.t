v6;
use Test;
use Template::Mustache;

plan 5;

my $m = Template::Mustache.new: :from<t/views>;

is $m.render(
        'hello',
        {name => 'Jimmy'},
        :from({ hello => 'override' })
    ),
    'override',
    'render(:from) overrides instance $.from';

is $m.render(
        'hello',
        {name => 'Jimmy'},
        :from({ foo => 'override' })
    ),
    "Hello, Jimmy.\n",
    'render(:from) doesn\'t obliterate instance $.from';

is $m.render(
        'partial',
        {name => 'Jimmy'},
        :from({ hello => 'override' })
    ),
    "Inline override.\nNo indent:\noverride.\nWith indent:\n\toverride.\n",
    'render(:from) overrides instance $.from for partials';

is $m.render(
        'partial',
        {name => 'Jimmy'},
        :from({ foo => 'override' })
    ),
    "Inline Hello, Jimmy.\n.\nNo indent:\nHello, Jimmy.\n.\nWith indent:\n\tHello, Jimmy.\n.\n",
    'render(:from) doesn\'t obliterate instance $.from for partials';

is $m.render(
        'Say {{> hello}}, and {{> hi}}',
        { name => 'Jimmy' },
        :from({ hi => 'find me a {{> hello}}' }),
        :extension(['.ms', '.mustache'])
    ),
    "Say Hello, Jimmy.\n, and find me a Hello, Jimmy.\n",
    'inline partial can get filesystem partial';

done;
