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
for load-specs() {
    cleanup;
    ("$views/specs-file-main" ~ $m.extension).IO.spurt: $_<template>;
    for $_<partials>.kv -> $name, $text {
        ("$views/$name" ~ $m.extension).IO.spurt: $text;
    }
    # Raku normalizes line endings when reading from a file, so
    # we must expect only newline here
    $_<expected> .= subst(:g, "\r\n", "\n");

    my $result = try $m.render: 'specs-file-main', $_<data>;
    if $_<todo> -> $todo { todo $todo }
    is $result, $_<expected>, join(': ', $_<name desc>.grep(*.defined));
}

# vim:set ft=perl6:
