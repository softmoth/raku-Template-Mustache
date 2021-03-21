use Test;
use Template::Mustache;

plan 3;

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

# Benchmark linear and parallel rendering

# Note that if data comes from external sources, the number of threads
# could go even higher. Thus, reading from a SQLite DB reaches the peak
# performance at about 2×$*KERNEL.cpu-cores.

# Leave one core for the linear test
my $threads = max 1, $*KERNEL.cpu-cores - 1;

if none(%*ENV<TEST_ALL>, %*ENV<TEST_BENCHMARK>) {
    skip "set TEST_BENCHMARK to enable this test", 1;
}
elsif $threads < 2 {
    skip "Parallel benchmarking doesn't make sense on a 1 or 2 cores CPU", 1;
}
else {
    todo "Test dies on Rakudo (as of 2021-03-21)";

    sub compare-hyper-and-list($repeats) {
        my @p;
        my @ready = Promise.new xx 2;
        my $starter-pistol = Promise.new;
        my ($parallel-time, $linear-time);

        # Run both tests in parallel to eliminate the effect of CPU
        # throttling where it's used. With sequential benchmark the first
        # ran test could leave the CPU throttled thus distorting the next
        # benchmark results.
        @p.push: start {
            @ready[0].keep(True);
            await $starter-pistol;
            my $st = now;
            my $out = $stache.render($tmpl, { a => get-data($repeats)
                        .hyper(:degree($threads)) });
            $parallel-time = now - $st;
        }
        @p.push: start {
            @ready[1].keep(True);
            await $starter-pistol;
            my $st = now;
            my $out = $stache.render($tmpl, { a => get-data($repeats)
                        .list });
            $linear-time = now - $st;
        }

        await @ready;
        $starter-pistol.keep(True);

        await @p;

        ($linear-time, $parallel-time)
    }

    my $repeats = 100;
    # Consider 2 seconds statistically significant to the benchmark results
    my $min-time = 2;
    my $linear-time;
    my $parallel-time;
    loop {
        ($linear-time, $parallel-time) = compare-hyper-and-list($repeats);
        last if $parallel-time >= $min-time;

        $repeats = ($repeats × (($min-time / $parallel-time) max 2)).ceiling;
        diag "Finished in {$parallel-time.fmt('%.2f')} seconds"
                ~ "; it's too fast, retry with {$repeats} repeats";
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

    CATCH {
        default {
            flunk "Fatal error while running parallel render comparison";
            diag "{.^name} $_";
            diag .start-backtrace.Str;
        }
    }
}

# vim:set ft=perl6:
