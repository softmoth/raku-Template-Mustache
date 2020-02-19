use v6;
use Test;
use Template::Mustache;

my $stache = Template::Mustache.new;

sub get-data(Int:D $count = 5) {
    gather {
        for ^$count {
            take $(:line("line $_"));
        }
    }
}

my $tmpl = q:to/TMPL/;
    {{#a}}{{line}}
    {{/a}}
    TMPL

my $expect = q:to/EXP/;
    line 0
    line 1
    line 2
    EXP

is $stache.render($tmpl, { a => get-data(3).list }), $expect, "with Positional";
is $stache.render($tmpl, { a => get-data(3) }), $expect, "with Iterable";

# Benchmark linear and parallel rendering.

# Note that if data comes from external sources, the number of threads could go even higher. Thus, reading from a SQLite
# DB reaches the peak performance at about 2×$*KERNEL.cpu-cores.
my $threads = max 1, $*KERNEL.cpu-cores - 1; # Leave one core for the linear test

if $threads < 2 {
    skip "Parallel benchmarking doesn't make sense on a 1 or 2 cores CPU", 1;
}
else {
    my $repeats = 100;
    # Consider 2 seconds statistically significant to consider the benchmark results.
    my $min-time = 2;
    my $linear-time;
    my $parallel-time;
    loop {
        my @p;
        my @ready = Promise.new xx 2;
        my $starter_pistol = Promise.new;

        # Run both tests in parallel to eliminate the effect of CPU throttling where it's used. With sequential
        # benchmark the first ran test could leave the CPU throttled thus distorting the next benchmark results.
        @p.push: start {
            @ready[0].keep(True);
            await $starter_pistol;
            my $st = now;
            my $out = $stache.render($tmpl, { a => get-data($repeats).hyper(:degree($threads)) });
            $parallel-time = now - $st;
        }
        @p.push: start {
            @ready[1].keep(True);
            await $starter_pistol;
            my $st = now;
            my $out = $stache.render($tmpl, { a => get-data($repeats).list });
            $linear-time = now - $st;
        }

        await @ready;
        $starter_pistol.keep(True);

        await @p;
        if $parallel-time < $min-time {
            $repeats = ($repeats × (($min-time / $parallel-time) max 2)).ceiling;
            diag "Finished in {$parallel-time.fmt('%.2f')} seconds; it's too fast, retry with " ~ $repeats ~ " repeats";
            $parallel-time = $linear-time = Nil;
        }
        else {
            last;
        }
    }
    if $linear-time > $parallel-time {
        pass "Parallel execution wins by "
                ~ ($linear-time / $parallel-time).fmt('%.2f')
                ~ " times using {$threads} threads";
    }
    else {
        flunk "Something is wrong: parallel execution lost by "
                ~ ($parallel-time / $linear-time).fmt('%.2f')
                ~ " times using {$threads} threads";
    }
}
