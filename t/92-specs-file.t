use v6;
use Test;

my $specs-dir = '../mustache-spec/specs';
my @specs = load-specs $specs-dir;
plan @specs + 1;
todo "You must clone github.com/mustache/spec into '{$specs-dir.path.directory}'"
    if @specs == 0;

ok @specs > 0 && @specs[0]<template>, "Specs files located";

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
my $m = Template::Mustache.new: :from();
for @specs {
    cleanup;
    "$views/specs-file-main.mustache".IO.spurt: $_<template>;
    for $_<partials>.kv -> $name, $text {
        "$views/$name.mustache".IO.spurt: $text;
    }
    is Template::Mustache.render('specs-file-main', $_<data>, :from($views)),
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
    my @files;
    try {
        @files = dir($specs-dir).grep({/$file\.json$/}).sort;
        CATCH { return (); }
    }
    # NYI
    @files .= grep({$_ !~~ /lambda/});

    diag "Reading spec files from '$specs-dir'";
    gather for @files {
        my $json = slurp $_;
        my %data = from-json $json;
        diag "- $_: {+%data<tests>}";
        take @(%data<tests>)[$start..*];
    }
}

# vim:set ft=perl6:
