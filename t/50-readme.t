use v6;
use Test;
use Template::Mustache;

plan 4;

is
    Template::Mustache.render('Hello, {{planet}}!', { planet => 'world' }),
    "Hello, world!",
    'Hello world';

    my $stache = Template::Mustache.new: :from<./views>;

# Adjust example a bit to avoid racing on the time
my $now = now;
is
    $stache.render('The time is {{time}}', {
        time => { ~DateTime.new($now).local }
    }),
    "The time is { ~DateTime.new($now).local }",
    'Local time';


my @people =
    { :name('James T. Kirk'), :title<Captain> },
    { :name('Wesley'), :title('Dread Pirate'), :emcee },
    { :name('Dana Scully'), :title('Special Agent') },
    ;
is
    $stache.render('roster', { :@people }),
    q:to<EOF>,
        Our esteemed guests:
        - The honorable James T. Kirk (Captain)
        - The honorable Wesley (Dread Pirate) *TONIGHT’S EMCEE*
        - The honorable Dana Scully (Special Agent)

        Enjoy!
        EOF
    'Roster';

my %data =
    event => 'Masters of the Universe Convention',
    :@people,
    ;
my %partials =
    welcome =>
        Qb[Welcome to the {{event}}! We’re pleased to have you here.\n\n],
    ;
is
    Template::Mustache.render(q:to<EOF>,
            {{> welcome}}
            {{> roster}}

                Dinner at 7PM in the Grand Ballroom. Bring a chair!
            EOF
        %data,
        :from([%partials, './views'])
    ),
    q:to<EOF>,
        Welcome to the Masters of the Universe Convention! We’re pleased to have you here.

        Our esteemed guests:
        - The honorable James T. Kirk (Captain)
        - The honorable Wesley (Dread Pirate) *TONIGHT’S EMCEE*
        - The honorable Dana Scully (Special Agent)

        Enjoy!

            Dinner at 7PM in the Grand Ballroom. Bring a chair!
        EOF
    'Event';

done-testing;
