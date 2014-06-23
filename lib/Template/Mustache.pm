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
            $*LEFT (< # ^ / >) \h* (\N*?) \h* $*RIGHT
        }
        regex thing:sym<partial> {
            $*LEFT '>' \h* (\N*?) \h* $*RIGHT
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
                        if $f {
                            # $f is the opening thing for this section
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
                :delims([$*LEFT, $*RIGHT]),
                :val(~$1.trim),
                :on($0 ne '/'),
                :inverted($0 eq '^'),
                :pos($0 eq '/' ?? $/.from !! $/.to),
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
            sub read-template-file($dir is copy) {
                $dir = IO::Spec.catdir: $*PROGRAM_NAME.path.directory, $dir
                    if $dir.path.is-relative;
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

        sub parse-template($template is copy, :$indent = '', :$delims) {
            $template .= subst(/^^/, $indent, :g) if $indent;
            my ($*LEFT, $*RIGHT) = @$delims || ( '{{', '}}' );
            Template::Mustache::Grammar.parse($template, :$actions)
                or X::Template::Mustache::CannotParse.new(:str($template)).throw;
            #note $/.made.perl;
            return @($/.made);
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
        multi sub format(@val, @data) {
            #note "** \@ ...";
            my $j = join '', @val.map: { format($_, @data) };
            #note "** ... \@ $j";
            $j;
        }
        multi sub format($val, @data) { $val }
        multi sub format(%val, @data) {
            sub get(@data, $field, :$section) {
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
                        #note "#** ^ with delims %val<delims>.perl()" if %val<delims>;
                        my @parsed = parse-template($str, :indent(%val<indent>), :delims(%val<delims>));
                        my $result = format(@parsed, @data);
                        return $result, True;
                    }
                    else {
                        #note "#** Resolve of $obj.WHAT.perl() as '$obj'";
                        return $obj, False;
                    }
                }

                #note "GET '$field' from: ", @data.perl;
                my $result = '';
                my $lambda = False;
                if $field eq '.' {
                    # Implicit iterator {{.}}
                    ($result, $lambda) = resolve(@data[0]);
                }
                else {
                    my @field = $field.split: '.';
                    for @data.map({$^ctx{@field[0]}}) -> $ctx {
                        # In perl6, {} and [] are falsy, but Mustache
                        # treats them as truthy
                        #note "#** field lookup for @field[0]: '$ctx.perl()'";
                        if $ctx or $ctx ~~ Associative or $ctx ~~ Positional {
                            ($result, $lambda) = resolve($ctx);
                            #note "#** ^ result is $result.perl(), lambda $lambda.perl()";
                            last;
                        }
                    }
                    while $result and !$lambda and @field > 1 {
                        @field.shift;
                        #note "#** dot field lookup for @field[0]";
                        ($result, $lambda) = resolve($result{@field[0]}) // '';
                    }
                }
                #note "get($field) is '$result.perl()'";
                return $section ?? ($result, $lambda) !! $result;
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
                    my ($datum, $lambda) = get(@data, %val<val>, :section);
                    if $lambda {
                        # The section was resolved by calling a lambda, which
                        # is always considered truthy, regardless of the
                        # lambda's return value
                        return %val<inverted> ?? '' !! $datum;
                    }

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
                    my @parsed = parse-template(get-template(%val<val>), :indent(%val<indent>));
                    #note "PARTIAL FORMAT DATA ", @data.perl;
                    format(@parsed, @data);
                }
                default { die "Impossible format type: ", %val.perl }
            }
        }
    }
}

=begin pod
Perl6 implementation of http://mustache.github.io/

=head1 Synopsis

    use Template::Mustache;
    # Hello, world!
    Template::Mustache.render('Hello, {{planet}}!', { planet => 'world' }).say;

    my @roster =
        { :name('James T. Kirk'), :title<Captain> },
        { :name('Wesley'), :title('Dread Pirate') },
        ;
    my $stache = Template::Mustache.new: :from<./views>;
    $stache.render('roster', { :@roster });

=head1 Tests

To run tests,

    git clone git@github.com:mustache/spec.git ../mustache-spec
    PERL6LIB=./lib prove -e perl6 -v

=head1 TODO

=item object support (not just hashes and arrays)
=item lambda support
=item parsed template caching
=item features from PHP mustache:
=item2 inline loader (POD?)
=item2 database loader
=item2 pragmas (FILTERS, inheritance)
=item2 .new(:helpers())
=item simplify and clean up code

=end pod

# vim:set ft=perl6:
