use v6;
use Test;

my $specs-dir = '../mustache-spec/specs';
my @specs = load-specs $specs-dir;
#diag sprintf("%-40s\t%s", $_<name desc>) for @specs;
plan @specs + 1;
todo "No specs found in '$specs-dir'" if @specs == 0;
ok @specs > 0 and @specs[0]<template>, "Specs files located";

use Template::Mustache;
for @specs {
    is Template::Mustache.render($_<template>, $_<data>, :partials($_<partials>)), $_<expected>, "$_<name>: $_<desc>"
        or last;
}

done;


sub load-specs (Str $specs-dir) {
    use JSON::Tiny;
    my ($file, $start) = '', 0;
    # Uncomment and tweak to run a specific test
    #$file = 'partials'; $start = 3;
    my @files;
    try {
        @files = dir($specs-dir).grep({/$file\.json$/}).sort;
        CATCH { return (); }
    }
    # NYI
    @files .= grep({$_ !~~ /lambda/});

    gather for @files {
        my $json = slurp $_;
        my %data = from-json $json;
        #diag "$_: {+%data<tests>}";
        take @(%data<tests>)[$start..*];
    }
}

# vim:set ft=perl6:
