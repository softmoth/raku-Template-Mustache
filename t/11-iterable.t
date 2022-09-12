use Test;
use Template::Mustache;

plan 6;

my $stache = Template::Mustache.new;

class Line {
    has $.line;
}

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
is $stache.render($tmpl, { a => get-data(3).map({ Line.new(| $_) }).list }), $expect, "with Positional Object";
is $stache.render($tmpl, { a => get-data(3).map({ Line.new(| $_) }) }), $expect, "with Iterable Object";

# Benchmark linear and parallel rendering

# Note that if data comes from external sources, the number of threads
# could go even higher. Thus, reading from a SQLite DB reaches the peak
# performance at about 2×$*KERNEL.cpu-cores.

# Leave one core for the linear test
my $threads = max 1, $*KERNEL.cpu-cores - 1;

sub compare-hyper-and-list($repeats) {
    my @p;
    my @ready = Promise.new xx 2;
    my $starter-pistol = Promise.new;
    my ($parallel-time, $linear-time);

    # Run both tests in parallel to eliminate the effect of CPU
    # throttling where it's used. With sequential benchmark the first
    # ran test could leave the CPU throttled thus distorting the next
    # benchmark results.

    my $st = now;

    @p.push: start {
        @ready[0].keep(True);
        await $starter-pistol;
        my $st = now;
        my $out = $stache.render($tmpl,
            { a => get-data($repeats).hyper(:degree($threads)) });
        $parallel-time = now - $st;
    }
    @p.push: start {
        @ready[1].keep(True);
        await $starter-pistol;
        my $st = now;
        my $out = $stache.render($tmpl,
            { a => get-data($repeats).list });
        $linear-time = now - $st;
    }

    CATCH {
        default {
            diag "{$*THREAD} {.^name}";
            diag $_;
            diag (.can('start-backtrace') ?? .start-backtrace !! .backtrace);
            return ($_, -1, -1);
        }
    }

    await @ready;
    $starter-pistol.keep(True);

    await @p;
    my $total-time = now - $st;

    ($linear-time, $parallel-time, $total-time)
}

# Test one small attempt, to verify that the parallelism doesn't crash
my ($linear-time, $parallel-time) = compare-hyper-and-list(5);
ok $parallel-time > 0, "Can run parallel hyper and list comparison routine";

if none(%*ENV<TEST_ALL>, %*ENV<TEST_BENCHMARK>) {
    skip "set TEST_BENCHMARK to enable this test", 1;
}
elsif $threads < 2 {
    skip "Parallel benchmarking doesn't make sense on a 1 or 2 cores CPU", 1;
}
else {
    my $repeats = 100;
    # Consider 2 seconds statistically significant to the benchmark results
    my $min-time = 2;
    my $max-total-time = $min-time * 10;
    my $linear-time;
    my $parallel-time;
    my $total-time;
    loop {
        ($linear-time, $parallel-time, $total-time) =
            compare-hyper-and-list($repeats);

        $repeats = ($repeats × ((($min-time / $parallel-time) max 1.5) min 3)).ceiling;
        diag sprintf "Finished in %.2f seconds (+ %.2f linear = %.2f total)",
                $parallel-time, $linear-time, $total-time;

        last if $parallel-time < 0;  # CATCH error result

        last if $parallel-time >= $min-time;

        # Total time can greatly dwarf parallel-time
        last if $total-time > $max-total-time;

        diag "...it's too fast, retry with {$repeats} repeats",
    }

    if $parallel-time < 0 {
        flunk "Fatal error while running parallel render comparison";
    }
    elsif $linear-time > $parallel-time {
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

# vim:set ft=raku:
