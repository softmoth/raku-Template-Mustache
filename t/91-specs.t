use Test;
use Template::Mustache;

use lib 't/lib';
use Template::Mustache::TestUtil;

for load-specs().sort -> $spec {
    subtest $spec.key => sub {
        plan +$spec.value;
        for $spec.value<> {
            my $result = try Template::Mustache.render:
                    $_<template>, $_<data>, :from($_<partials>), :literal;
            if $_<todo> -> $todo { todo $todo }
            is $result // $!, $_<expected>, join(': ', $_<name desc>.grep(*.defined));
        }
    }
}

# vim:set ft=raku:
