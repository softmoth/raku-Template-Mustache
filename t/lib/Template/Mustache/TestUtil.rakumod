use Test;

sub load-specs (*@specs-dirs) is export {
    use JSON::Fast;
    # Set to run a specific test (e.g. '~lambda:5')
    my ($file, $start, $count) = split ':', %*ENV<TEST_SPEC_START> // '';
    $file ||= '';
    $start ||= 0;
    $count ||= Inf;

    my @files;
    @specs-dirs ||= < ../mustache-spec/specs t/specs >;
    for @specs-dirs {
        .IO.e or next;
        #diag "Reading spec files from '$_'";
        @files = .IO.dir(:test(rx{ '.json' $ })).sort;
        last;
    }
    @files .= grep: { .basename eq "$file.json" } if $file;

    my %specs;
    for @files {
        my %data = %(from-json slurp $_);
        #diag "- $_: {+%data<tests>}";
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
        %specs{ .basename } := %data<tests>;
    }

    plan +%specs + 1;
    if %specs.values».elems.sum == 0 {
        skip "To run Mustache spec tests, clone git@github.com:softmoth/mustache-spec.git into '{@specs-dirs.head.IO.dirname}'";
    }
    else {
        ok %specs.head.value.head<template>, "Valid specs files located";

        if $start > 0 {
            $start = min($start, %specs.head.value.elems) - 1;
            %specs.head.value = %specs.head.value[$start .. $start + $count - 1];
        }
    }

    return %specs;
}

# vim:set ft=perl6:
