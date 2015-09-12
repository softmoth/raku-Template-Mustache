use v6;
use Test;
use Template::Mustache;

use lib 't/lib';
use Template::Mustache::TestUtil;

for load-specs '../mustache-spec/specs' {
    is Template::Mustache.render($_<template>, $_<data>, :from($_<partials>), :literal),
        $_<expected>,
        "$_<name>: $_<desc>";
}

done-testing;
