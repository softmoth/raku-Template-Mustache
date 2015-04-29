use v6;
use Test;
use Template::Mustache;

for load-specs '../mustache-spec/specs' {
    is Template::Mustache.render($_<template>, $_<data>, :from($_<partials>), :literal),
        $_<expected>,
        "$_<name>: $_<desc>"
            ;#or last;
}

done;


# TODO Factor this out, it's used in 9*-specs*.t
sub load-specs (Str $specs-dir) {
    use JSON::Tiny;
    my ($file, $start) = '', 0;
    # Uncomment and tweak to run a specific test
    #$start = 122; #$file = '~lambdas';

    diag "Reading spec files from '$specs-dir'";
    my @files;
    try {
        # Skip optional (~*) tests, NYI
        @files = dir($specs-dir, :test(rx{ '.json' $ })).sort;
        @files = () unless @files[0]; # handle failure of dir()
        @files .= grep: { .basename eq "$file.json" } if $file;
        CATCH { @files = () }
    }

    my @specs = gather for @files {
        my %data = %(from-json slurp $_);
        diag "- $_: {+%data<tests>}";
        for %data<tests>.list -> $t {
            if $t<data><lambda> -> $l {
                if $l<perl6> {
                    $t<data><lambda> = $l<perl6>.EVAL;
                }
                else {
                    $t<data><lambda> :delete;
                }
            }
        }
        take @(%data<tests>);
    }

    plan @specs + 1;
    if @specs == 0 {
        skip "You must clone clone git@github.com:softmoth/mustache-spec.git into '{$specs-dir.IO.dirname}'";
    }
    else {
        ok @specs[0]<template>, "Valid specs files located";
    }

    if $start > 1 {
        $start -= 2;
        $start = min($start, +@specs);
        skip "Getting right to the problem", $start;
    }
    else {
        $start = 0;
    }

    return @specs[$start .. *];
}

# vim:set ft=perl6:
