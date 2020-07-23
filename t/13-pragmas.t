use Test;
use Template::Mustache;

plan 1;

subtest "KEEP-UNUSED-VARIABLES" => sub {
    plan 3;

    is Template::Mustache.render('{{replace}} {{keep}}', { replace => 'hi' },
            :pragma<keep-unused-variables>),
        'hi {{keep}}',
        'Keeps unused variable (render-time pragma)';

    my $tm = Template::Mustache.new: :pragma<keep-unused-variables>;
    is $tm.render('{{replace}} {{keep}}', { replace => 'hi' }),
        'hi {{keep}}',
        'Keeps unused variable (instance pragma)';

    # NB: The delimiter is kept, but the tag *specifying* the delimiter is
    # removed! There isn't really a sensible alternative to that, but it is
    # probably best to use the default delimiters with this pragma.
    is $tm.render('{{= <% %> =}}<% replace %> <% keep %>', { replace => 'hi' }),
        'hi <% keep %>',
        'Keeps unused variable (instance pragma)';
}

# vim:set ft=perl6:
