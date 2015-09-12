use v6;
use Test;

sub load-specs (Str $specs-dir) is export {
    use JSON::Fast;
    my ($file, $start) = '', 0;
    # Uncomment and tweak to run a specific test
    #$start = 122; #$file = '~lambdas';

    diag "Reading spec files from '$specs-dir'";
    my @files = (dir($specs-dir, :test(rx{ '.json' $ })) // ()).sort;
    @files .= grep: { .basename eq "$file.json" } if $file;

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
        take @(%data<tests>).Slip;
    }

    plan @specs + 1;
    if @specs == 0 {
        skip "You must clone git@github.com:softmoth/mustache-spec.git into '{$specs-dir.IO.dirname}'";
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
