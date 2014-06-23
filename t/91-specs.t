use v6;
use Test;
use Template::Mustache;

for load-specs '../mustache-spec/specs' {
    is Template::Mustache.render($_<template>, $_<data>, :from($_<partials>)),
        $_<expected>,
        "$_<name>: $_<desc>"
            or last;
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
        take @(%data<tests>);
    }

    plan @specs + 1;
    todo "You must clone github.com/mustache/spec into '{$specs-dir.path.directory}'"
        if @specs == 0;

    ok @specs > 0 && @specs[0]<template>, "Specs files located";

    skip "Getting right to the problem", $start - 2 if $start > 1;

    return @specs;
}

# vim:set ft=perl6:
