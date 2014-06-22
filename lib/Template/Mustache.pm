my class X::Template::Mustache::CannotParse is Exception {
    has $.err = 'Unable to parse';
    has $.str;
    method message() { "$!err ❮{$!str}❯" }
}

class Template::Mustache {
    has $.extension = '.mustache';
    has $.from;

    #use Grammar::Tracer;
    grammar Template::Mustache::Grammar {
        regex TOP {
            :my $*LEFT = '{{';
            :my $*RIGHT = '}}';
            ^  <hunk>* (.*) $
        }

        regex hunk { (.*?) [<linething> | <thing>] }

        token linething { ^^ (\h*) <thing> <?{
            # XXX Very ugly to use an assertion here!
            # Interpolations do NOT affect surrounding whitespace
            $<thing>.made<type> ~~ none(<var qvar mmmvar>)
        }>\h* [\n|$] }

        token name { [<ident> * % '.' | ('.')] }
        proto regex thing { <...> }
        regex thing:sym<comment> { $*LEFT '!' (.*?) $*RIGHT }
        token thing:sym<var> { $*LEFT \h* <name> \h* $*RIGHT }
        token thing:sym<qvar> { $*LEFT '&' \h* <name> \h* $*RIGHT }
        token thing:sym<mmmvar> {
            <?{ $*LEFT eq '{{' and $*RIGHT eq '}}' }>
            '{{{' \h* <name> \h* '}}}'
        }
        regex thing:sym<delim> {
            $*LEFT '=' (\N*?) '=' $*RIGHT
        }
        regex thing:sym<section> {
            $*LEFT (< # ^ / >) \h* (\S*?) \h* $*RIGHT
        }
        regex thing:sym<partial> {
            $*LEFT '>' \h* (\S*?) \h* $*RIGHT
        }
    }

    class Template::Mustache::Actions {
        method TOP($/) {
            my %x = { :val(''), :contents([]) };
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
                            #note "*****", $f.perl;
                            last if $f<val> eq $hunk<val>;
                            warn "Closing '$f<val>' section while looking for $hunk<val> section";
                            $f = Nil;
                        }
                        if !$f {
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
            for $<linething thing>.grep(*.defined)».made -> $thing {
                $thing<finalizer>() if $thing<finalizer>;
                @x.push: $thing;
            }
            make @x;
        }
        method linething($/) {
            my $thing = $<thing>.made;
            $thing<indent> = ~$0;
            make $thing;
        }
        method name($/) {
            make $0 // ~@<ident>.join('.')
        }
        method thing:sym<delim>($/) {
            my @delim = $0.comb(/\S+/);
            @delim == 2 or X::Template::Mustache::CannotParse.new(:err<Invalid delimiters>, :str($/)).throw;
            make {
                :type<delim>,
                :val(~$0),
                :finalizer({
                    #note "DEBUG Setting DELIMS ", @delim.perl;
                    ($*LEFT, $*RIGHT) = @delim;
                }),
            }
        }
        method thing:sym<comment>($/) {
            make { :type<comment>, :val(~$0) }
        }
        method thing:sym<var>($/) {
            make { :type<var>, :val(~$<name>) }
        }
        method thing:sym<qvar>($/) {
            make { :type<qvar>, :val(~$<name>) }
        }
        method thing:sym<mmmvar>($/) {
            make { :type<mmmvar>, :val(~$<name>) }
        }
        method thing:sym<section>($/) {
            make {
                :type<section>,
                :val(~$1.trim),
                :on($0 ne '/'),
                :inverted($0 eq '^'),
            }
        }
        method thing:sym<partial>($/) {
            make { :type<partial>, :val(~$0) }
        }
    }

    method render($template, %data, :$partials = {}, :$from is copy, :$extension is copy) {
        # XXX There must be a better way to use an instance var if available, but
        # use a default if called on a type object
        if !$from.defined {
            $from = $!from if self.defined;
        }
        if !$extension.defined {
            $extension = self.defined ?? $!extension !! '.mustache';
        }

        #note "TEMPLATE ", $template.perl;
        #note "DATA ", %data.perl;
        #note "PARTIALS ", $partials.perl if $partials;

        my $actions = Template::Mustache::Actions.new;
        sub parse-template($template, $indent = '') {
            my $t := $template;
            if $from ~~ Stringy {
                # RAKUDO: .slurp error seems to be un-CATCH-able?
                $t := my $str;
                my $file = IO::Spec.catfile($from, $template ~ $extension).IO;
                if $file.r {
                    $str = $file.slurp;
                }
                else {
                    #log_warn "Template '$file.path()' not found";
                    $str = '';
                }

            }

            $t := $t.subst(/^^/, $indent, :g) if $indent;

            Template::Mustache::Grammar.parse($t, :$actions)
                or X::Template::Mustache::CannotParse.new(:str($t)).throw;
            #note $/.made.perl;
            return @($/.made);
        }
        my @parsed = parse-template($template);
        return format(@parsed, [%data], %$partials);

        # Can't use this, it doesn't encode &quot; (")
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
        multi sub format(@val, @data, %partials) {
            #note "** \@ ...";
            my $j = join '', @val.map: { format($_, @data, %partials) };
            #note "** ... \@ $j";
            $j;
        }
        multi sub format($val, @data, %partials) { $val }
        multi sub format(%val, @data, %partials) {
            sub get(@data, $field) {
                #note "GET '$field' from: ", @data.perl;
                if $field eq '.' {
                    # Implicit iterator {{.}}
                    return @data[0];
                }
                my @field = $field.split: '.';
                my $ret = '';
                for @data.map({$^ctx{@field[0]}}) -> $ctx {
                    # In perl6, {} and [] are falsy, but Mustache
                    # treats them as truthy
                    if $ctx or $ctx ~~ Associative or $ctx ~~ Positional {
                        $ret = $ctx;
                        last;
                    }
                }
                while $ret and @field > 1 {
                    @field.shift;
                    $ret = $ret{@field[0]} // '';
                }
                #note "get($field) is '$ret.perl()'";
                return $ret;
            }

            #note "** \{ %val<type>: %val<val>";
            given %val<type> {
                when 'comment' { '' }
                when 'var' { encode-entities(get(@data, %val<val>)) }
                when 'qvar' { get(@data, %val<val>) }
                when 'mmmvar' { get(@data, %val<val>) }
                when 'delim' { '' }
                when 'section' {
                    #note "SECTION '%val<val>'";
                    my $datum = get(@data, %val<val>);
                    if !%val<inverted> and $datum -> $_ {
                        when Associative {
                            temp @data;
                            @data.unshift: $_;
                            format(%val<contents>, @data, %partials);
                        }
                        when Positional {
                            (gather for @$_ -> $datum {
                                temp @data;
                                @data.unshift: $datum;
                                take format(%val<contents>, @data, %partials);
                            }).join('');
                        }
                        default {
                            format(%val<contents>, @data, %partials);
                        }
                    }
                    elsif %val<inverted> and !$datum {
                        format(%val<contents>, @data, %partials);
                    }
                    else {
                        #note "!!! EMPTY SECTION '%val<val>'";
                        ''
                    }
                }
                when 'partial' {
                    my $p = %val<val>;
                    unless $from {
                        $p = %partials{$p} // '';
                        #note "#!! PARTIAL $p.perl(): %val.perl(), %partials.perl()";
                    }
                    my @partial = parse-template($p, %val<indent>);
                    #note "PARTIAL FORMAT DATA ", @data.perl;
                    format(@partial, @data, %partials);
                }
                default { die "Impossible format type: ", %val.perl }
            }
        }
    }
}

# vim:set ft=perl6:
