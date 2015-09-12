use v6;
use Test;
use Template::Mustache;

use lib 't/lib';
use Template::Mustache::TestUtil;

constant $views = 't/spec-partials';
sub cleanup(:$rmdir = False) {
    if $views.IO.e {
        unlink $_ for dir $views;
        rmdir $views if $rmdir;
    }
}
END { cleanup(:rmdir); }

mkdir $views;
my $m = Template::Mustache.new: :from($views.IO.basename);
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

done-testing;
