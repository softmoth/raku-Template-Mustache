my class X::Template::Mustache::CannotParse is Exception {
    has $.err = 'Unable to parse';
    has $.str;
    method message() { "$!err ❮{$!str}❯" }
}

my class X::Template::Mustache::FieldNotFound is Exception {
    has $.err = 'Field not found';
    has $.str;
    method message() { "$!err ❮{$!str}❯" }
}

class Template::Mustache:ver<1.1.3>:auth<github:softmoth> {
    has $.extension = '.mustache';
    has $.from;

    #use Grammar::Tracer;
    grammar Template::Mustache::Grammar {
        regex TOP {
            ^  <hunk>* (.*) $
        }

        regex hunk { (.*?) [<linetag> | <tag>] }

        token linetag { ^^ (\h*) <tag> <?{
            # XXX Very ugly to use an assertion here!
            # Interpolations do NOT affect surrounding whitespace
            $<tag>.made<type> ~~ none(<var qvar mmmvar>)
        }>\h* [\n|$] }

        token ident { <+ graph - punct> <+ graph - [\<\>\{\}\[\]&=%]>* }
        token name { [<ident> * % '.' | ('.')] }
        proto regex tag { <...> }
        regex tag:sym<comment> { $*LEFT '!' (.*?) $*RIGHT }
        token tag:sym<var> { $*LEFT \h* <name> \h* $*RIGHT }
        token tag:sym<qvar> { $*LEFT '&' \h* <name> \h* $*RIGHT }
        token tag:sym<mmmvar> {
            <?{ $*LEFT eq '{{' and $*RIGHT eq '}}' }>

            # NB: Use $*LEFT and $*RIGHT here to force the grammar to
            # recognize that this rule is a strictly longer token than
            # sym<var>. Otherwise, '{{' might be tried before '{{{'!

            $*LEFT '{' \h* <name> \h* '}' $*RIGHT
        }
        regex tag:sym<delim> {
            $*LEFT '=' (\N*?) '=' $*RIGHT
        }
        regex tag:sym<section> {
            $*LEFT (< # ^ / >) \h* (\N*?) \h* $*RIGHT
        }
        regex tag:sym<partial> {
            $*LEFT '>' \h* (\N*?) \h* $*RIGHT
        }
    }

    class Template::Mustache::Actions {
        method TOP($/) {
            my %x = :val(''), :contents([]);
            my @frames;
            @frames.unshift: $%x;
            for $<hunk>».made.flat -> $hunk {
                if $hunk ~~ Associative and $hunk<type> eq 'section' {
                    if $hunk<on> {
                        @frames[0]<contents>.push: $hunk;
                        $hunk<contents> = [];
                        @frames.unshift: $hunk;
                    }
                    else {
                        my $f;
                        while @frames > 1 {
                            $f = @frames.shift;
                            #note "*****", $f.raku;
                            last if $f<val> eq $hunk<val>;
                            warn "Closing '$f<val>' section while looking for $hunk<val> section";
                            $f = Nil;
                        }
                        if $f {
                            # $f is the opening tag for this section
                            $f<raw-contents> = $/.substr($f<pos>, $hunk<pos> - $f<pos>);
                            $f<pos> :delete;  # Not useful outside of this parse
                        }
                        else {
                            warn "No start of section found for /$hunk<val>!";
                        }
                    }
                }
                else {
                    @frames[0]<contents>.push: $hunk;
                }
            }
            @frames[0]<contents>.push(~$0) if $0.chars;

            make %x<contents>;
        }
        method hunk($/) {
            my @x;
            @x.push(~$0) if $0.chars;
            for $<linetag tag>.grep(*.defined)».made -> $tag {
                $tag<finalizer>() if $tag<finalizer>;
                @x.push: $tag;
            }
            make @x.Slip;
        }
        method linetag($/) {
            my $tag = $<tag>.made;
            $tag<indent> = ~$0;
            make $tag;
        }
        method name($/) {
            make $0 // ~@<ident>.join('.')
        }
        method tag:sym<delim>($/) {
            my @delim = $0.comb(/\S+/);
            @delim == 2 or X::Template::Mustache::CannotParse.new(:err<Invalid delimiters>, :str($/)).throw;
            make {
                :type<delim>,
                :val(~$0),
                :finalizer({
                    #note "DEBUG Setting DELIMS ", @delim.raku;
                    ($*LEFT, $*RIGHT) = @delim;
                }),
            }
        }
        method tag:sym<comment>($/) {
            make { :type<comment>, :val(~$0) }
        }
        method tag:sym<var>($/) {
            make { :type<var>, :val(~$<name>) }
        }
        method tag:sym<qvar>($/) {
            make { :type<qvar>, :val(~$<name>) }
        }
        method tag:sym<mmmvar>($/) {
            make { :type<mmmvar>, :val(~$<name>) }
        }
        method tag:sym<section>($/) {
            make {
                :type<section>,
                :delims([$*LEFT, $*RIGHT]),
                :val(~$1.trim),
                :on($0 ne '/'),
                :inverted($0 eq '^'),
                :pos($0 eq '/' ?? $/.from !! $/.to),
            }
        }
        method tag:sym<partial>($/) {
            make { :type<partial>, :val(~$0) }
        }
    }

    method render($template, %context, Bool :$literal, :$from, :$extension is copy, Bool :$warn = False) {
        state %cache;
        my $froms = [];

        sub cacheable(Bool :$check-lambda) {
            # Only cache literals
            $literal and $template
                # Don't cache partials
                and $template !~~ /^ \s* '>' /
                # Don't cache lambdas. This check is expensive, and not
                # needed on cache retrieval.
                and (not $check-lambda or $template !~~ /lambda/)
        }

        if cacheable() and %cache{ $template }:exists {
            return format(%cache{ $template }, [%context])
        }

        if !$extension.defined {
            $extension = self ?? $!extension !! '.mustache';
        }
        $extension = [ $extension ] unless $extension ~~ Positional;

        sub push-to-froms ($_) {
            when Positional { push $froms, |$_ }
            when .defined { push $froms, $_ }
        }
        push-to-froms $from;
        push-to-froms $!from if self;

        my $initial-template;
        if $literal {
            # Use $template itself as the template text
            # Either :from(Str) was specified in caller, or no :from() and
            # called via type object (no instance to find default)
            $initial-template = $template;
        }
        elsif get-template($template, :silent) -> $t {
            $initial-template = $t;
        }
        else {
            # Couldn't find the initial template, assume literal
            # unless explicitly prohibited
            $initial-template = $template unless $literal.defined;
            #log_warn "Template '$template' undefined";
            $initial-template //= '';
        }

        #note "TEMPLATE: $template.raku()";
        #note "DATA:  %context.raku()";
        #note "FROM: $froms.raku()";
        #note "EXTENSION: $extension.raku()";

        my $actions = Template::Mustache::Actions.new;
        my @parsed = parse-template($initial-template);
        %cache{ $template } = @parsed if cacheable(:check-lambda);
        return format(@parsed, [%context]);


        sub get-template($template, :$silent) {
            sub read-template-file($dir is copy) {
                $dir = $*SPEC.catdir: $*PROGRAM-NAME.IO.dirname, $dir
                    if $dir.IO.is-relative;
                my $file = $extension.map({ $*SPEC.catfile($dir, $template ~ $_).IO }).first(*.e);
                return $file.slurp if $file;
                CATCH {
                    # RAKUDO: slurp throws X::Adhoc exception
                    default {
                        # Ignore it
                    }
                }
                #log_warn "Unable to find file for template '$template'" unless $silent;
                return Nil;
            }

            for @$froms {
                when Associative {
                    if $_{$template} -> $t { return $t; }
                }

                when any(Stringy, IO::Path) {
                    # Look for $template file in this directory
                    my $t = read-template-file($_);
                    return $t if $t.defined;
                }

                default {
                    warn "Ignoring unrecognized :from() entry $_.raku()";
                }
            }

            #log_warn "Unable to get template '$template' from anywhere" unless $silent;
            return '';
        }

        sub parse-template($template is copy, :$indent = '', :$delims) {
            $template .= subst(/^^/, $indent, :g) if $indent;
            my ($*LEFT, $*RIGHT) = $delims ?? @$delims !! ( '{{', '}}' );
            Template::Mustache::Grammar.parse($template, :$actions)
                or X::Template::Mustache::CannotParse.new(:str($template)).throw;
            #note $/.made.raku;
            return @($/.made // ());
        }

        # Can't use HTML::Entity, it doesn't encode &quot; (")
        #use HTML::Entity;
        sub encode-entities($str) {
            $str.trans:
                /'&'/  => '&amp;',
                /'"'/  => '&quot;',
                /'<'/  => '&lt;',
                /'>'/  => '&gt;',
                /\xA0/ => '&nbsp;',
                ;
        }

        # TODO Track recursion depth and throw if > 100?
        multi sub format(@val, @context) {
            #note "** \@ ...";
            my $j = join '', @val.map: { format($_, @context) };
            #note "** ... \@ $j";
            $j;
        }
        multi sub format($val, @context) { $val }
        multi sub format(%val, @context) {
            sub get(@context, $field, :$section) {
                sub resolve($obj) {
                    if $obj ~~ Callable {
                        my $str;
                        if $obj.arity > 1 {
                            warn "Ignoring '$field' lambda that takes $_ args";
                            $str = '';
                        }
                        elsif $obj.arity == 1 {
                            $str = $obj(%val<raw-contents> // '');
                        }
                        else {
                            $str = $obj();
                        }
                        #note "#** Parsing '$str'";
                        #note "#** ^ with delims %val<delims>.raku()" if %val<delims>;
                        my @parsed = parse-template($str, :indent(%val<indent>), :delims(%val<delims>));
                        my $result = format(@parsed, @context);
                        return $result, True;
                    }
                    else {
                        #note "#** Resolve of $obj.WHAT.raku() as '$obj'";
                        return $obj, False;
                    }
                }

                #note "GET '$field' from: ", @context.raku;
                my $result = '';
                my $lambda = False;
                if $field eq '.' {
                    # Implicit iterator {{.}}
                    ($result, $lambda) = resolve(@context[0]);
                }
                else {
                    my @field = $field.split: '.';
                    for @context.map({$^ctx{@field[0]}}) -> $ctx {
                        # In Raku, {} and [] are falsy, but Mustache
                        # treats them as truthy
                        #note "#** field lookup for @field[0]: '$ctx.raku()'";
                        if $ctx ~~ Promise {
                            $result = await $ctx;
                            last;
                        }
                        elsif $ctx.defined {
                            ($result, $lambda) = resolve($ctx);
                            #note "#** ^ result is $result.raku(), lambda $lambda.raku()";
                            last;
                        }
                    }
                    while $result and !$lambda and @field > 1 {
                        @field.shift;
                        #note "#** dot field lookup for @field[0]";
                        ($result, $lambda) = resolve($result{@field[0]}) // '';
                    }
                }
                #note "get($field) is '$result.raku()'";
                if !$result && $warn {
                     warn X::Template::Mustache::FieldNotFound.new(:str($field));
                }
                return $section ?? ($result, $lambda) !! $result;
            }

            #note "** \{ %val<type>: %val<val>";
            given %val<type> {
                when 'comment' { '' }
                when 'var' { encode-entities(~get(@context, %val<val>)) }
                when 'qvar' { get(@context, %val<val>) }
                when 'mmmvar' { get(@context, %val<val>) }
                when 'delim' { '' }
                when 'section' {
                    #note "SECTION '%val<val>'";
                    my ($datum, $lambda) = get(@context, %val<val>, :section);
                    if $lambda {
                        # The section was resolved by calling a lambda, which
                        # is always considered truthy, regardless of the
                        # lambda's return value
                        return %val<inverted> ?? '' !! $datum;
                    }

                    if !%val<inverted> and $datum -> $_ {
                        when Associative {
                            temp @context;
                            @context.unshift: $_;
                            format(%val<contents>, @context);
                        }
                        when Iterable | Positional {
                            $_.map( -> $datum {
                                my @ctx = @context;
                                @ctx.unshift: $datum;
                                format(%val<contents>, @ctx);
                            }).join('');
                        }
                        default {
                            format(%val<contents>, @context);
                        }
                    }
                    elsif %val<inverted> and !$datum {
                        format(%val<contents>, @context);
                    }
                    else {
                        #note "!!! EMPTY SECTION '%val<val>'";
                        ''
                    }
                }
                when 'partial' {
                    my @parsed = parse-template(get-template(%val<val>), :indent(%val<indent>));
                    #note "PARTIAL FORMAT DATA ", @context.raku;
                    format(@parsed, @context);
                }
                default { die "Impossible format type: ", %val.raku }
            }
        }
    }
}

# vim:set ft=perl6:
