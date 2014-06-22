use v6;
use Test;
use Template::Mustache;

constant $views = 't/spec-partials';
sub cleanup(:$rmdir = False) {
    if $views.IO.e {
        unlink $_ for dir $views;
        rmdir $views if $rmdir;
    }
}
END { cleanup(:rmdir); }

mkdir $views;
my $m = Template::Mustache.new: :from($views);
for load-specs '../mustache-spec/specs' {
    cleanup;
    ("$views/specs-file-main" ~ $m.extension).IO.spurt: $_<template>;
    for $_<partials>.kv -> $name, $text {
        ("$views/$name" ~ $m.extension).IO.spurt: $text;
    }
    is $m.render('specs-file-main', $_<data>),
        $_<expected>,
        "$_<name>: $_<desc>";
}

done;


# TODO Factor this out, it's used in 9*-specs*.t
sub load-specs (Str $specs-dir) {
    use JSON::Tiny;
    my ($file, $start) = '', 0;
    # Uncomment and tweak to run a specific test
    #$file = 'partials'; $start = 0;

    diag "Reading spec files from '$specs-dir'";
    my @files;
    try {
        # Skip optional (~*) tests, NYI
        @files = dir($specs-dir, :test(rx{^ <![~]> (.+) '.json' $ })).sort;
        CATCH { return (); }
    }

    my @specs = gather for @files {
        my %data = from-json slurp $_;
        diag "- $_: {+%data<tests>}";
        take @(%data<tests>)[$start..*];
    }

    plan @specs + 1;
    todo "You must clone github.com/mustache/spec into '{$specs-dir.path.directory}'"
        if @specs == 0;

    ok @specs > 0 && @specs[0]<template>, "Specs files located";

    return @specs;
}

# vim:set ft=perl6:
