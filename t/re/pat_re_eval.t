#!./perl
#
# This is a home for regular expression tests that don't fit into
# the format supported by re/regexp.t.  If you want to add a test
# that does fit that format, add it to re/re_tests, not here.

use strict;
use warnings;
use 5.010;


sub run_tests;

$| = 1;


BEGIN {
    chdir 't' if -d 't';
    @INC = ('../lib','.');
    require './test.pl';
    skip_all_if_miniperl("no dynamic loading on miniperl, no re");
}


plan tests => 252;  # Update this when adding/deleting tests.

run_tests() unless caller;

#
# Tests start here.
#
sub run_tests {
    {
        my $message =  "Call code from qr //";
        local $_ = 'var="foo"';
        $a = qr/(?{++$b})/;
        $b = 7;
        ok(/$a$a/ && $b eq '9', $message);

        my $c="$a";
        ok(/$a$a/ && $b eq '11', $message);

        undef $@;
        eval {/$c/};
        like($@, qr/not allowed at runtime/, $message);

        use re "eval";
        /$a$c$a/;
        is($b, '14', $message);

        our $lex_a = 43;
        our $lex_b = 17;
        our $lex_c = 27;
        my $lex_res = ($lex_b =~ qr/$lex_b(?{ $lex_c = $lex_a++ })/);

        is($lex_res, 1, $message);
        is($lex_a, 44, $message);
        is($lex_c, 43, $message);

        no re "eval";
        undef $@;
        my $d = '(?{1})';
        my $match = eval { /$a$c$a$d/ };
        ok($@ && $@ =~ /Eval-group not allowed/ && !$match, $message);
        is($b, '14', $message);

        $lex_a = 2;
        $lex_a = 43;
        $lex_b = 17;
        $lex_c = 27;
        $lex_res = ($lex_b =~ qr/17(?{ $lex_c = $lex_a++ })/);

        is($lex_res, 1, $message);
        is($lex_a, 44, $message);
        is($lex_c, 43, $message);

    }

    {
        our $a = bless qr /foo/ => 'Foo';
        ok 'goodfood' =~ $a,     "Reblessed qr // matches";
        is($a, '(?^:foo)', "Reblessed qr // stringifies");
        my $x = "\x{3fe}";
        my $z = my $y = "\317\276";  # Byte representation of $x
        $a = qr /$x/;
        ok $x =~ $a, "UTF-8 interpolation in qr //";
        ok "a$a" =~ $x, "Stringified qr // preserves UTF-8";
        ok "a$x" =~ /^a$a\z/, "Interpolated qr // preserves UTF-8";
        ok "a$x" =~ /^a(??{$a})\z/,
                        "Postponed interpolation of qr // preserves UTF-8";


        is(length qr /##/x, 9, "## in qr // doesn't corrupt memory; Bug 17776");

        {
            use re 'eval';
            ok "$x$x" =~ /^$x(??{$x})\z/,
               "Postponed UTF-8 string in UTF-8 re matches UTF-8";
            ok "$y$x" =~ /^$y(??{$x})\z/,
               "Postponed UTF-8 string in non-UTF-8 re matches UTF-8";
            ok "$y$x" !~ /^$y(??{$y})\z/,
               "Postponed non-UTF-8 string in non-UTF-8 re doesn't match UTF-8";
            ok "$x$x" !~ /^$x(??{$y})\z/,
               "Postponed non-UTF-8 string in UTF-8 re doesn't match UTF-8";
            ok "$y$y" =~ /^$y(??{$y})\z/,
               "Postponed non-UTF-8 string in non-UTF-8 re matches non-UTF8";
            ok "$x$y" =~ /^$x(??{$y})\z/,
               "Postponed non-UTF-8 string in UTF-8 re matches non-UTF8";

            $y = $z;  # Reset $y after upgrade.
            ok "$x$y" !~ /^$x(??{$x})\z/,
               "Postponed UTF-8 string in UTF-8 re doesn't match non-UTF-8";
            ok "$y$y" !~ /^$y(??{$x})\z/,
               "Postponed UTF-8 string in non-UTF-8 re doesn't match non-UTF-8";
        }
    }


    {
        use re 'eval';
        # Test if $^N and $+ work in (?{{})
        our @ctl_n = ();
        our @plus = ();
        our $nested_tags;
        $nested_tags = qr{
            <
               ((\w)+)
               (?{
                       push @ctl_n, (defined $^N ? $^N : "undef");
                       push @plus, (defined $+ ? $+ : "undef");
               })
            >
            (??{$nested_tags})*
            </\s* \w+ \s*>
        }x;


        my $c = 0;
        for my $test (
            # Test structure:
            #  [ Expected result, Regex, Expected value(s) of $^N, Expected value(s) of $+ ]
            [ 1, qr#^$nested_tags$#, "bla blubb bla", "a b a" ],
            [ 1, qr#^($nested_tags)$#, "bla blubb <bla><blubb></blubb></bla>", "a b a" ],
            [ 1, qr#^(|)$nested_tags$#, "bla blubb bla", "a b a" ],
            [ 1, qr#^(?:|)$nested_tags$#, "bla blubb bla", "a b a" ],
            [ 1, qr#^<(bl|bla)>$nested_tags<(/\1)>$#, "blubb /bla", "b /bla" ],
            [ 1, qr#(??{"(|)"})$nested_tags$#, "bla blubb bla", "a b a" ],
            [ 1, qr#^(??{"(bla|)"})$nested_tags$#, "bla blubb bla", "a b a" ],
            [ 1, qr#^(??{"(|)"})(??{$nested_tags})$#, "bla blubb undef", "a b undef" ],
            [ 1, qr#^(??{"(?:|)"})$nested_tags$#, "bla blubb bla", "a b a" ],
            [ 1, qr#^((??{"(?:bla|)"}))((??{$nested_tags}))$#, "bla blubb <bla><blubb></blubb></bla>", "a b <bla><blubb></blubb></bla>" ],
            [ 1, qr#^((??{"(?!)?"}))((??{$nested_tags}))$#, "bla blubb <bla><blubb></blubb></bla>", "a b <bla><blubb></blubb></bla>" ],
            [ 1, qr#^((??{"(?:|<(/?bla)>)"}))((??{$nested_tags}))\1$#, "bla blubb <bla><blubb></blubb></bla>", "a b <bla><blubb></blubb></bla>" ],
            [ 0, qr#^((??{"(?!)"}))?((??{$nested_tags}))(?!)$#, "bla blubb undef", "a b undef" ],

        ) { #"#silence vim highlighting
            $c++;
            @ctl_n = ();
            @plus = ();
            my $match = (("<bla><blubb></blubb></bla>" =~ $test->[1]) ? 1 : 0);
            push @ctl_n, (defined $^N ? $^N : "undef");
            push @plus, (defined $+ ? $+ : "undef");
            ok($test->[0] == $match, "match $c");
            if ($test->[0] != $match) {
              # unset @ctl_n and @plus
              @ctl_n = @plus = ();
            }
            is("@ctl_n", $test->[2], "ctl_n $c");
            is("@plus", $test->[3], "plus $c");
        }
    }

    {
        use re 'eval';


        our $f;
        local $f;
        $f = sub {
            defined $_[0] ? $_[0] : "undef";
        };

        like("123", qr/^(\d)(((??{1 + $^N})))+$/, 'Bug 56194');

        our @ctl_n;
        our @plus;

        my $re  = qr#(1)((??{ push @ctl_n, $f->($^N); push @plus, $f->($+); $^N + 1}))*(?{$^N})#;
        my $re2 = qr#(1)((??{ push @ctl_n, $f->($^N); push @plus, $f->($+); $^N + 1}))*(?{$^N})(|a(b)c|def)(??{"$^R"})#;
        my $re3 = qr#(1)((??{ push @ctl_n, $f->($^N); push @plus, $f->($+); $^N + 1})){2}(?{$^N})(|a(b)c|def)(??{"$^R"})#;
        our $re5;
        local $re5 = qr#(1)((??{ push @ctl_n, $f->($^N); push @plus, $f->($+); $^N + 1})){2}(?{$^N})#;
        my $re6 = qr#(??{ push @ctl_n, $f->($^N); push @plus, $f->($+); $^N + 1})#;
        my $re7 = qr#(??{ push @ctl_n, $f->($^N); push @plus, $f->($+); $^N + 1})#;
        my $re8 = qr/(\d+)/;
        my $c = 0;
        for my $test (
             # Test structure:
             #  [
             #    String to match
             #    Regex too match
             #    Expected values of $^N
             #    Expected values of $+
             #    Expected values of $1, $2, $3, $4 and $5
             #  ]
             [
                  "1233",
                  qr#^(1)((??{ push @ctl_n, $f->($^N); push @plus, $f->($+); $^N + 1}))+(??{$^N})$#,
                  "1 2 3 3",
                  "1 2 3 3",
                  "\$1 = 1, \$2 = 3, \$3 = undef, \$4 = undef, \$5 = undef",
             ],
             [
                  "1233",
                  qr#^(1)((??{ push @ctl_n, $f->($^N); push @plus, $f->($+); $^N + 1}))+(abc|def|)?(??{$+})$#,
                  "1 2 3 3",
                  "1 2 3 3",
                  "\$1 = 1, \$2 = 3, \$3 = undef, \$4 = undef, \$5 = undef",
             ],
             [
                  "1233",
                  qr#^(1)((??{ push @ctl_n, $f->($^N); push @plus, $f->($+); $^N + 1}))+(|abc|def)?(??{$+})$#,
                  "1 2 3 3",
                  "1 2 3 3",
                  "\$1 = 1, \$2 = 3, \$3 = undef, \$4 = undef, \$5 = undef",
             ],
             [
                  "1233",
                  qr#^(1)((??{ push @ctl_n, $f->($^N); push @plus, $f->($+); $^N + 1}))+(abc|def|)?(??{$^N})$#,
                  "1 2 3 3",
                  "1 2 3 3",
                  "\$1 = 1, \$2 = 3, \$3 = undef, \$4 = undef, \$5 = undef",
             ],
             [
                  "1233",
                  qr#^(1)((??{ push @ctl_n, $f->($^N); push @plus, $f->($+); $^N + 1}))+(|abc|def)?(??{$^N})$#,
                  "1 2 3 3",
                  "1 2 3 3",
                  "\$1 = 1, \$2 = 3, \$3 = undef, \$4 = undef, \$5 = undef",
              ],
              [
                  "123abc3",
                   qr#^($re)(|a(b)c|def)(??{$^R})$#,
                   "1 2 3 abc",
                   "1 2 3 b",
                   "\$1 = 123, \$2 = 1, \$3 = 3, \$4 = abc, \$5 = b",
              ],
              [
                  "123abc3",
                   qr#^($re2)$#,
                   "1 2 3 123abc3",
                   "1 2 3 b",
                   "\$1 = 123abc3, \$2 = 1, \$3 = 3, \$4 = abc, \$5 = b",
              ],
              [
                  "123abc3",
                   qr#^($re3)$#,
                   "1 2 123abc3",
                   "1 2 b",
                   "\$1 = 123abc3, \$2 = 1, \$3 = 3, \$4 = abc, \$5 = b",
              ],
              [
                  "123abc3",
                   qr#^(??{$re5})(|abc|def)(??{"$^R"})$#,
                   "1 2 abc",
                   "1 2 abc",
                   "\$1 = abc, \$2 = undef, \$3 = undef, \$4 = undef, \$5 = undef",
              ],
              [
                  "123abc3",
                   qr#^(??{$re5})(|a(b)c|def)(??{"$^R"})$#,
                   "1 2 abc",
                   "1 2 b",
                   "\$1 = abc, \$2 = b, \$3 = undef, \$4 = undef, \$5 = undef",
              ],
              [
                  "1234",
                   qr#^((\d+)((??{push @ctl_n, $f->($^N); push @plus, $f->($+);$^N + 1}))((??{push @ctl_n, $f->($^N); push @plus, $f->($+);$^N + 1}))((??{push @ctl_n, $f->($^N); push @plus, $f->($+);$^N + 1})))$#,
                   "1234 123 12 1 2 3 1234",
                   "1234 123 12 1 2 3 4",
                   "\$1 = 1234, \$2 = 1, \$3 = 2, \$4 = 3, \$5 = 4",
              ],
              [
                   "1234556",
                   qr#^(\d+)($re6)($re6)($re6)$re6(($re6)$re6)$#,
                   "1234556 123455 12345 1234 123 12 1 2 3 4 4 5 56",
                   "1234556 123455 12345 1234 123 12 1 2 3 4 4 5 5",
                   "\$1 = 1, \$2 = 2, \$3 = 3, \$4 = 4, \$5 = 56",
              ],
              [
                  "12345562",
                   qr#^((??{$re8}))($re7)($re7)($re7)$re7($re7)($re7(\2))$#,
                   "12345562 1234556 123455 12345 1234 123 12 1 2 3 4 4 5 62",
                   "12345562 1234556 123455 12345 1234 123 12 1 2 3 4 4 5 2",
                   "\$1 = 1, \$2 = 2, \$3 = 3, \$4 = 4, \$5 = 5",
              ],
        ) {
            $c++;
            @ctl_n = ();
            @plus = ();
            undef $^R;
            my $match = $test->[0] =~ $test->[1];
            my $str = join(", ", '$1 = '.$f->($1), '$2 = '.$f->($2), '$3 = '.$f->($3), '$4 = '.$f->($4),'$5 = '.$f->($5));
            push @ctl_n, $f->($^N);
            push @plus, $f->($+);
            ok($match, "match $c; Bug 56194");
            if (not $match) {
                # unset $str, @ctl_n and @plus
                $str = "";
                @ctl_n = @plus = ();
            }
            is("@ctl_n", $test->[2], "ctl_n $c; Bug 56194");
            is("@plus", $test->[3], "plus $c; Bug 56194");
            is($str, $test->[4], "str $c; Bug 56194");
        }
        SKIP: {
            if ($] le '5.010') {
                skip "test segfaults on perl < 5.10", 4;
            }

            @ctl_n = ();
            @plus = ();

            our $re4;
            local $re4 = qr#(1)((??{push @ctl_n, $f->($^N); push @plus, $f->($+);$^N + 1})){2}(?{$^N})(|abc|def)(??{"$^R"})#;
            undef $^R;
            my $match = "123abc3" =~ m/^(??{$re4})$/;
            my $str = join(", ", '$1 = '.$f->($1), '$2 = '.$f->($2), '$3 = '.$f->($3), '$4 = '.$f->($4),'$5 = '.$f->($5),'$^R = '.$f->($^R));
            push @ctl_n, $f->($^N);
            push @plus, $f->($+);
            ok($match, 'Bug 56194');
            if (not $match) {
                # unset $str
                @ctl_n = ();
                @plus = ();
                $str = "";
            }
            is("@ctl_n", "1 2 undef", 'Bug 56194');
            is("@plus", "1 2 undef", 'Bug 56194');
            is($str,
               "\$1 = undef, \$2 = undef, \$3 = undef, \$4 = undef, \$5 = undef, \$^R = undef",
               'Bug 56194');
       }
    }

    {
	# re evals within \U, \Q etc shouldn't be seen by the lexer
	local our $a  = "i";
	local our $B  = "J";
	ok('(?{1})' =~ /^\Q(?{1})\E$/,   '\Q(?{1})\E');
	ok('(?{1})' =~ /^\Q(?{\E1\}\)$/, '\Q(?{\E1\}\)');
	use re 'eval';
	ok('Ia' =~ /^\U(??{"$a\Ea"})$/,  '^\U(??{"$a\Ea"})$');
	ok('ja' =~ /^\L(??{"$B\Ea"})$/,  '^\L(??{"$B\Ea"})$');
    }

    {
	# Comprehensive (hopefully) tests of closure behaviour:
	# i.e. when do (?{}) blocks get (re)compiled, and what instances
	# of lexical vars do they close over?

	# XXX remove this when TODOs are fixed
	# like ok, but 1st arg indicates TODO
	sub tok($$$) {
	    my $todo = shift;
	    local $::TODO = 're_eval lexical madness' if $todo;
	    ok($_[0], $_[1]);
	}

	# XXX remove this when TODOs are fixed
	no warnings qw(uninitialized closure);

	# if the pattern string gets utf8 upgraded while concatenating,
	# make sure a literal code block is still detected (by still
	# compiling in the absence of use re 'eval')

	{
	    my $s1 = "\x{80}";
	    my $s2 = "\x{100}";
	    ok("\x{80}\x{100}" =~ /^$s1(?{1})$s2$/, "utf8 upgrade");
	}

	my ($cr1, $cr2, $cr3, $cr4);

	use re 'eval';
	for my $x (qw(a b c)) {
	    my $bc = ($x ne 'a');
	    my $c80 = chr(0x80);

	    # the most basic: literal code should be in same scope
	    # as the parent

	    ok("A$x"       =~ /^A(??{$x})$/,       "[$x] literal code");
	    ok("\x{100}$x" =~ /^\x{100}(??{$x})$/, "[$x] literal code UTF8");

	    # the "don't recompile if pattern unchanged" mechanism
	    # shouldn't apply to code blocks - recompile every time
	    # to pick up new instances of variables

	    my $code1  = 'B(??{$x})';
	    my $code1u = $c80 . "\x{100}" . '(??{$x})';
	    tok($bc, "AB$x" =~ /^A$code1$/, "[$x] unvarying runtime code AA");
	    tok($bc, "A$c80\x{100}$x" =~ /^A$code1u$/,
					"[$x] unvarying runtime code AU");
	    tok($bc, "$c80\x{100}B$x" =~ /^$c80\x{100}$code1$/,
					"[$x] unvarying runtime code UA");
	    tok($bc, "$c80\x{101}$c80\x{100}$x" =~ /^$c80\x{101}$code1u$/,
					"[$x] unvarying runtime code UU");

	    # mixed literal and run-time code blocks

	    my $code2  = 'B(??{$x})';
	    my $code2u = $c80 . "\x{100}" . '(??{$x})';
	    tok($bc, "A$x-B$x" =~ /^A(??{$x})-$code2$/,
					"[$x] literal+runtime AA");
	    tok($bc, "A$x-$c80\x{100}$x" =~ /^A(??{$x})-$code2u$/,
					"[$x] literal+runtime AU");
	    tok($bc, "$c80\x{100}$x-B$x" =~ /^$c80\x{100}(??{$x})-$code2$/,
					"[$x] literal+runtime UA");
	    tok($bc, "$c80\x{101}$x-$c80\x{100}$x"
					=~ /^$c80\x{101}(??{$x})-$code2u$/,
					"[$x] literal+runtime UU");

	    # literal qr code only created once, naked

	    $cr1 //= qr/^A(??{$x})$/;
	    ok("Aa" =~ $cr1, "[$x] literal qr once naked");

	    # literal qr code only created once, embedded with text

	    $cr2 //= qr/B(??{$x})$/;
	    ok("ABa" =~ /^A$cr2/, "[$x] literal qr once embedded text");

	    # literal qr code only created once, embedded with text + lit code

	    $cr3 //= qr/C(??{$x})$/;
	    ok("A$x-BCa" =~ /^A(??{$x})-B$cr3/,
			    "[$x] literal qr once embedded text + lit code");

	    # literal qr code only created once, embedded with text + run code

	    $cr4 //= qr/C(??{$x})$/;
	    my $code3 = 'A(??{$x})';
	    tok(1,   "A$x-BCa" =~ /^A$code3-B$cr4/,
			    "[$x] literal qr once embedded text + run code");

	    # literal qr code, naked

	    my $r1 = qr/^A(??{$x})$/;
	    ok("A$x" =~ $r1, "[$x] literal qr naked");

	    # literal qr code, embedded with text

	    my $r2 = qr/B(??{$x})$/;
	    tok($bc, "AB$x" =~ /^A$r2/, "[$x] literal qr embedded text");

	    # literal qr code, embedded with text + lit code

	    my $r3 = qr/C(??{$x})$/;
	    tok($bc, "A$x-BC$x" =~ /^A(??{$x})-B$r3/,
				"[$x] literal qr embedded text + lit code");

	    # literal qr code, embedded with text + run code

	    my $r4 = qr/C(??{$x})$/;
	    my $code4 = '(??{$x})';
	    tok($bc, "A$x-BC$x" =~ /^A$code4-B$r4/,
				"[$x] literal qr embedded text + run code");

	    # nested qr in different scopes

	    my $code5 = '(??{$x})';
	    my $r5 = qr/C(??{$x})$/;
	    my $r6 = qr/$code5-C(??{$x})$/;

	    my @rr5;
	    my @rr6;

	    for my $y (qw(d e f)) {

		my $rr5 = qr/^A(??{"$x$y"})-$r5/;
		push @rr5, $rr5;
		tok($bc, "A$x$y-C$x" =~ $rr5,
				"[$x-$y] literal qr + r5");

		my $rr6 = qr/^A(??{"$x$y"})-$r6/;
		push @rr6, $rr6;
		tok($bc, "A$x$y-$x-C$x" =~ $rr6,
				"[$x-$y] literal qr + r6");
	    }

	    for my $i (0,1,2) {
		my $y = 'Y';
		my $yy = (qw(d e f))[$i];
		my $rr5 = $rr5[$i];
		tok($bc, "A$x$yy-C$x" =~ $rr5,
				"[$x-$yy] literal qr + r5, outside");
		tok(1,               "A$x$yy-C$x-D$x" =~ /$rr5-D(??{$x})/,
				"[$x-$yy] literal qr + r5 + lit, outside");

		my $rr6 = $rr6[$i];
		push @rr6, $rr6;
		tok($bc, "A$x$yy-$x-C$x" =~ $rr6,
				"[$x-$yy] literal qr + r6, outside");
		tok(1,               "A$x$yy-$x-C$x-D$x" =~ /$rr6-D(??{$x})/,
				"[$x-$yy] literal qr + r6 +lit, outside");
	    }
	}

	# recursive subs should get lexical from the correct pad depth

	sub recurse {
	    my ($n) = @_;
	    return if $n > 2;
	    ok("A$n" =~ /^A(??{$n})$/, "recurse($n)");
	    recurse($n+1);
	}
	recurse(0);

	# for qr// containing run-time elements but with a compile-time
	# code block, make sure the run-time bits are executed in the same
	# pad they were compiled in
	{
	    my $a = 'a'; # ensure outer and inner pads don't align
	    my $b = 'b';
	    my $c = 'c';
	    my $d = 'd';
	    my $r = qr/^$b(??{$c})$d$/;
	    ok("bcd" =~ $r, "qr with run-time elements and code block");
	}

	# check that cascaded embedded regexes all see their own lexical
	# environment

	{
	    my ($r1, $r2, $r3, $r4);
	    my ($x1, $x2, $x3, $x4) = (5,6,7,8);
	    { my $x1 = 1; $r1 = qr/A(??{$x1})/; }
	    { my $x2 = 2; $r2 = qr/$r1(??{$x2})/; }
	    { my $x3 = 3; $r3 = qr/$r2(??{$x3})/; }
	    { my $x4 = 4; $r4 = qr/$r3(??{$x4})/; }
	    ok("A1234" =~ /^$r4$/, "cascaded qr");
	}

	# and again, but in a loop, with no external references
	# being maintained to the qr's

	{
	    my $r = 'A';
	    for my $x (1..4) {
		$r = qr/$r(??{$x})/;
	    }
	    my $x = 5;
	    ok("A1234" =~ /^$r$/, "cascaded qr loop");
	}


	# and again, but compiling the qrs in an eval so there
	# aren't even refs to the qrs from any ops

	{
	    my $r = 'A';
	    for my $x (1..4) {
		$r = eval q[ qr/$r(??{$x})/; ];
	    }
	    my $x = 5;
	    ok("A1234" =~ /^$r$/, "cascaded qr loop");
	}

	# have qrs with either literal code blocks or only embedded
	# code blocks, but not both

	{
	    my ($r1, $r2, $r3, $r4);
	    my ($x1, $x3) = (7,8);
	    { my $x1 = 1; $r1 = qr/A(??{$x1})/; }
	    {             $r2 = qr/${r1}2/; }
	    { my $x3 = 3; $r3 = qr/$r2(??{$x3})/; }
	    {             $r4 = qr/${r3}4/; }
	    ok("A1234"  =~   /^$r4$/,    "cascaded qr mix 1");
	    ok("A12345" =~   /^${r4}5$/, "cascaded qr mix 2");
	    ok("A1234"  =~ qr/^$r4$/   , "cascaded qr mix 3");
	    ok("A12345" =~ qr/^${r4}5$/, "cascaded qr mix 4");
	}

	# and make sure things are freed at the right time

	{
	    package Foo99;
	    my $d = 0;
	    sub DESTROY { $d++ }

	    {
		my $r1;
		{
		    my $x = bless [1];
		    $r1 = eval 'qr/(??{$x->[0]})/';
		}
		my $r2 = eval 'qr/a$r1/';
		my $x = 2;
		::ok(eval '"a1" =~ qr/^$r2$/', "match while in scope");
		# make sure PL_reg_curpm isn't holding on to anything
		"a" =~ /a(?{1})/;
		::is($d, 0, "before scope exit");
	    }
	    ::is($d, 1, "after scope exit");
	}

	# forward declared subs should Do The Right Thing with any anon CVs
	# within them (i.e. pad_fixup_inner_anons() should work)
	
	sub forward;
	sub forward {
	    my $x = "a";
	    my $A = "A";
	    ok("Aa" =~ qr/^A(??{$x})$/,  "forward qr compiletime");
	    ok("Aa" =~ qr/^$A(??{$x})$/, "forward qr runtime");
	}
	forward;
    }

} # End of sub run_tests

1;
