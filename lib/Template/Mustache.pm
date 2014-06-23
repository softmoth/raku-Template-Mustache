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

    method render($template, %data, Bool :$literal, :$from is copy, :$extension is copy) {
        if !$extension.defined {
            $extension = self ?? $!extension !! '.mustache';
        }
        $extension = [ $extension ] unless $extension ~~ Positional;

        if $from.defined {
            $from = [ $from ] unless $from ~~ Positional;
            $from.push: $!from if self and $!from;
        }
        else {
            $from = self ?? $!from !! [];
        }

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

        #note "TEMPLATE: $template.perl()";
        #note "DATA:  %data.perl()";
        #note "FROM: $from.perl()";
        #note "EXTENSION: $extension.perl()";

        my $actions = Template::Mustache::Actions.new;
        my @parsed = parse-template($initial-template);
        return format(@parsed, [%data]);


        sub get-template($template, :$silent) {
            sub read-template-file($dir) {
                for @$extension -> $ext {
                    my $file = IO::Spec.catfile($dir, $template ~ $ext).IO;
                    return $file.slurp;
                    CATCH {
                        # RAKUDO: slurp throws X::Adhoc exception
                        default {
                            # Ignore it
                        }
                    }
                }
                #log_warn "Unable to find file for template '$template'" unless $silent;
                return Nil;
            }

            for @$from {
                when Associative {
                    if $_{$template} -> $t { return $t; }
                }

                when any(Stringy, IO::Path) {
                    # Look for $template file in this directory
                    my $t = read-template-file($_);
                    return $t if $t.defined;
                }

                default {
                    warn "Ignoring unrecognized :from() entry $_.perl()";
                }
            }

            #log_warn "Unable to get template '$template' from anywhere" unless $silent;
            return '';
        }

        sub parse-template($template is copy, $indent = '') {
            $template .= subst(/^^/, $indent, :g) if $indent;
            Template::Mustache::Grammar.parse($template, :$actions)
                or X::Template::Mustache::CannotParse.new(:str($template)).throw;
            #note $/.made.perl;
            return @($/.made);
        }

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
        multi sub format(@val, @data) {
            #note "** \@ ...";
            my $j = join '', @val.map: { format($_, @data) };
            #note "** ... \@ $j";
            $j;
        }
        multi sub format($val, @data) { $val }
        multi sub format(%val, @data) {
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
                            format(%val<contents>, @data);
                        }
                        when Positional {
                            (gather for @$_ -> $datum {
                                temp @data;
                                @data.unshift: $datum;
                                take format(%val<contents>, @data);
                            }).join('');
                        }
                        default {
                            format(%val<contents>, @data);
                        }
                    }
                    elsif %val<inverted> and !$datum {
                        format(%val<contents>, @data);
                    }
                    else {
                        #note "!!! EMPTY SECTION '%val<val>'";
                        ''
                    }
                }
                when 'partial' {
                    my @partial = parse-template(get-template(%val<val>), %val<indent>);
                    #note "PARTIAL FORMAT DATA ", @data.perl;
                    format(@partial, @data);
                }
                default { die "Impossible format type: ", %val.perl }
            }
        }
    }
}

# vim:set ft=perl6:
