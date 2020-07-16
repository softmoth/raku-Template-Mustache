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

my class X::Template::Mustache::InheritenceLost is Exception {
    has $.err = 'Non-override content in inheritence section';
    has $.str;
    method message() { "$!err ❮{$!str}❯" }
}

class Template::Mustache:ver<1.1.4>:auth<github:softmoth> {
    has $.extension = 'mustache';
    has $.from;
    has %!cache;

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

        token ident { <+ graph - punct> <+ graph - [\<\>\{\}\[\]&=%$]>* }
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
            $*LEFT (< # ^ / \< $ >) \h* (\N*?) \h* $*RIGHT
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
                ($tag<finalizer>:delete)() if $tag<finalizer>;
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
                :inherits($0 eq '<'),
                :override($0 eq '$'),
                :pos($0 eq '/' ?? $/.from !! $/.to),
            }
        }
        method tag:sym<partial>($/) {
            make { :type<partial>, :val(~$0) }
        }
    }

    method render(|c (
        $template,
        %context,
        :$from,
        :$extension is copy,
        Bool :$literal,
        Bool :$warn = False,
    )) {
        unless self.DEFINITE {
            # If called as Template::Mustache.render(), create an instance
            # to run with
            return self.new.render: |c;
        }

        my $froms = [];
        my %*overrides;

        if not $extension.defined {
            $extension = ($!extension if self) // 'mustache';
        }
        # Allow user to specify '.mustache' or 'mustache' as extension
        $extension = map { .starts-with('.') ?? .substr(1) !! $_ }, @$extension;
        $extension = [ $extension<> ] unless $extension ~~ Positional;

        sub push-to-froms ($_) {
            when Positional { push $froms, |$_ }
            when .defined { push $froms, $_ }
        }
        push-to-froms $from;
        push-to-froms $!from if self;

        my $actions = Template::Mustache::Actions.new;

        #note "TEMPLATE: $template.raku()";
        #note "FROM: $froms.raku()";
        #note "EXTENSION: $extension.raku()";
        my @parsed = get-template($template, :$literal);

        #note "PARSED: @parsed.raku()";
        #note "CONTEXT:  %context.raku()";
        return format(@parsed, [%context]);

        sub find-template-file($template, $dir is copy) {
            $dir = $dir.IO;
            $dir = $*PROGRAM.sibling($dir).resolve(:completely) if $dir.is-relative;
            $extension.map({
                $dir.add($template).extension(:0parts, $_)
            }).first(*.e);
        }

        sub get-template($template, :$delims, :$indent, :$literal) {
            my $specific = specify-template;
            my $key = "{$indent // ''}>$specific";
            my @parsed;
            if %!cache{ $key }:exists {
                @parsed = %!cache{ $key };
            }
            else {
                my $str = do given $specific {
                    when IO::Path {
                        CATCH {
                            # RAKUDO: slurp throws X::Adhoc exception
                            default {
                                # Ignore it
                            }
                        }

                        .slurp;
                    }

                    default {
                        $_
                    }
                }

                # TODO Organize the parsed results so they can be indented
                # on the fly, and move indent action into format(). That way
                # we can cache just one version of the template and use that
                # everywhere it is used.
                $str .= subst(/^^/, $indent, :g) if $indent;

                @parsed = parse-template($str, :$delims);
                %!cache{ $key } = @parsed;
            }

            #note "Template for '$key': ", @parsed.raku;
            return @parsed;

            sub specify-template {
                if $literal {
                    # Use $template itself as the template text
                    return $template
                }

                for @$froms {
                    when Associative {
                        .return with $_{$template};
                    }

                    when any(Stringy, IO::Path) {
                        .resolve(:completely).return
                            with find-template-file($template, $_);
                    }

                    default {
                        warn "Ignoring unrecognized :from() entry $_.raku()";
                    }
                }

                # Couldn't find the initial template, assume literal unless
                # explicitly prohibited
                return $template unless $literal.defined;

                #warn "Template '$template' undefined";
                return '';
            }
        }

        sub parse-template($str, :$delims) {
            my ($*LEFT, $*RIGHT) = $delims ?? @$delims !! ( '{{', '}}' );
            Template::Mustache::Grammar.parse($str, :$actions)
                or X::Template::Mustache::CannotParse.new(:$str).throw;
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
        proto sub format(|) {*}
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
                        # literal: don't allow lambda return a template name
                        my @parsed = get-template($str, :delims(%val<delims>), :indent(%val<indent>), :literal);
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

            sub extract-overrides(@contents) {
                for @contents {
                    when Associative {
                        when *.<override> {
                            %*overrides{.<val>} = .<contents>;
                        }

                        when { .<type> eq 'comment' } {
                            # Ignore
                        }

                        when *.<inherits> {
                            my @parsed = get-template
                                            .<val>,
                                            :delims(.<delims>),
                                            :indent(.<indent>),
                                            :!literal,
                                            ;

                            # Contents override parent
                            extract-overrides @parsed;
                            extract-overrides .<contents>;
                        }

                        when { .<type> eq 'partial' } {
                            my @parsed = get-template
                                            .<val>,
                                            :delims(.<delims>),
                                            :indent(.<indent>),
                                            :!literal,
                                            ;

                            extract-overrides @parsed;
                        }

                        default {
                            # Ignore
                            #warn X::Template::Mustache::InheritenceLost
                            #    .new: :str((.<val>).fmt('< # %s'));
                        }
                    }
                    when Str {
                        # Ignore
                        #warn X::Template::Mustache::InheritenceLost
                        #    .new: :str(($_).fmt('< $ %s'));
                    }
                    default {
                        # Ignore
                        #warn X::Template::Mustache::InheritenceLost
                        #    .new: :str((.gist).fmt('< ? %s'));
                    }
                }
            }

            #note "** \{ %val<type>: %val<val>";
            given %val<type> {
                when 'comment' { '' }
                when 'var' { encode-entities(~get(@context, %val<val>)) }
                when 'qvar' { get(@context, %val<val>) }
                when 'mmmvar' { get(@context, %val<val>) }
                when 'delim' { '' }
                when 'section' {
                    my ($datum, $lambda) = get(@context, %val<val>, :section);
                    if $lambda {
                        # The section was resolved by calling a lambda, which
                        # is always considered truthy, regardless of the
                        # lambda's return value
                        return %val<inverted> ?? '' !! $datum;
                    }

                    if %val<inherits> {
                        temp %*overrides;

                        my @parsed = get-template
                                        %val<val>,
                                        :delims(%val<delims>),
                                        :indent(%val<indent>),
                                        :!literal,
                                        ;

                        extract-overrides %val<contents>;

                        format(@parsed, @context);
                    }
                    elsif %val<override> {
                        format(%*overrides{%val<val>} // %val<contents>, @context);
                    }
                    elsif !%val<inverted> and $datum -> $_ {
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
                    #note "- Looking up partial for {%val<val>}";
                    my @parsed = get-template
                                    %val<val>,
                                    :delims(%val<delims>),
                                    :indent(%val<indent>),
                                    :!literal,
                                    ;
                    #note "PARTIAL FORMAT DATA ", @context.raku;
                    format(@parsed, @context);
                }
                default { die "Impossible format type: ", %val.raku }
            }
        }
    }
}

# vim:set ft=perl6:
