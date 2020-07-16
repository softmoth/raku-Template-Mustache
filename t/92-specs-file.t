use Test;
use Template::Mustache;

use lib 't/lib';
use Template::Mustache::TestUtil;

constant views = 't/spec-partials'.IO;

my $m = Template::Mustache.new;

for load-specs().sort -> $spec {
    subtest $spec.key => sub {
        plan +$spec.value;
        for $spec.value<> {
            # Make a unique directory for each test, since we re-use names
            # of partials in many tests, and they would be in the cache
            my $subdir = $spec.key.IO.add(++$);
            my $from = views.basename.IO.add($subdir);
            my $full-path = views.add($subdir).mkdir;
            for 'specs-file-main', $_<template>, |$_<partials>.kv
                -> $name, $text
            {
                $full-path.add($name).extension(:0parts, $m.extension)
                    .spurt: $text;
            }
            # Raku normalizes line endings when reading from a file, so
            # we must expect only newline here
            $_<expected> .= subst(:g, "\r\n", "\n");

            my $result = try $m.render: 'specs-file-main', :$from, $_<data>;
            if $_<todo> -> $todo { todo $todo }
            is $result // $!, $_<expected>, join(': ', $_<name desc>.grep(*.defined));

            LEAVE {
                if %*ENV<TEST_SPEC_KEEP>.not and $full-path.IO.e {
                    # t/spec-partials / spec-file / 1      / foo.mustache
                    .unlink for dir $full-path;
                    # .parent.parent  /  .parent  / $full-path /
                    rmdir $full-path, $full-path.parent, $full-path.parent.parent;
                }
            }
        }
    }
}

diag "Templates from spec test left in {views}" if %*ENV<TEST_SPEC_KEEP>;

# vim:set ft=perl6:
