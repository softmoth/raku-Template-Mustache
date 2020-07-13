use Test;
use Template::Mustache;

plan 1;

my $stache = Template::Mustache.new: :from<views>;

is $stache.render('article', {
        article => {
            title => 'Superman Saves the Day',
            author => "Lois Lane",
            body => q:to/EOF/.trim,
                <p>Faster than a speeding bullet, he leapt the building in a
                single bound.</p>
                EOF
        },
    }),
    q:to/EOF/,
        <html>
        <head>
            <title>Superman Saves the Day</title>
        </head>
        <body>
            <h1>Superman Saves the Day</h1>
            by <i>Lois Lane</i>

            <p>Faster than a speeding bullet, he leapt the building in a
        single bound.</p>
        </body>
        </html>
        EOF
    "'article' inherits 'layout' with overrides"
    ;
