use v5.36;
use utf8;
use Test::More;
use File::Temp qw(tempfile);
use IPC::Open3;
use Symbol qw(gensym);
use Grongigo::CodeGen::Perl;

binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

sub n ($kind, %fields) { bless \%fields, "Grongigo::AST::$kind" }
sub number ($value) { n(NumberLiteral => value => $value) }
sub ident ($name) { n(Identifier => name => $name) }
sub binary ($left, $op, $right) { n(BinaryExpr => left => $left, operator => $op, right => $right) }
sub block (@statements) { n(BlockStmt => statements => \@statements) }
sub expr ($expression) { n(ExprStmt => expression => $expression) }
sub ret ($value) { n(ReturnStmt => value => $value) }
sub call ($name, @arguments) { n(CallExpr => callee => ident($name), arguments => \@arguments) }
sub printf_stmt ($format, @args) { expr(call('printf', n(StringLiteral => value => $format), @args)) }
sub func ($name, $body, @params) {
    n(FunctionDecl => return_type => 'int', name => $name, params => \@params, body => $body)
}
sub program (@declarations) { n(Program => declarations => \@declarations) }
sub compile ($ast) { Grongigo::CodeGen::Perl->new->generate($ast) }

sub run_code ($code) {
    my ($fh, $path) = tempfile(SUFFIX => '.pl', UNLINK => 1);
    binmode $fh, ':encoding(UTF-8)';
    print {$fh} $code;
    close $fh or die "$path: $!";
    my $err = gensym;
    my $pid = open3(my $input, my $output, $err, $^X, $path);
    close $input;
    binmode $output, ':encoding(UTF-8)';
    binmode $err, ':encoding(UTF-8)';
    my $stdout = do { local $/; <$output> } // '';
    my $stderr = do { local $/; <$err> } // '';
    waitpid $pid, 0;
    return [$stdout, $stderr, $? >> 8];
}

subtest 'Japanese functions, recursion and signatures' => sub {
    my $arg = ident('バ');
    my $factorial = func('バギジョウシギャス', block(
        n(IfStmt => condition => binary($arg, '<=', number(1)),
          then_branch => ret(number(1)), else_branch => undef),
        ret(binary($arg, '*', call('バギジョウシギャス', binary($arg, '-', number(1)))))
    ), n(Parameter => type => 'int', name => 'バ'));
    my $main = func('main', block(printf_stmt('%d', call('バギジョウシギャス', number(5))), ret(number(0))));
    my $code = compile(program($factorial, $main));
    like $code, qr/\Ause v5\.36;\nuse utf8;\nuse integer;/, 'integer and Unicode prologue';
    like $code, qr/sub バギジョウシギャス \(\$バ\)/, 'Japanese names remain visible';
    like $code, qr/exit\(main\(\)\);\n\z/, 'entry point exits with main result';
    is_deeply run_code($code), ["120\n", '', 0], 'recursive program executes without warnings';
};

subtest 'C integer arithmetic and boolean values' => sub {
    my @values = (
        binary(number(7), '/', number(2)),
        binary(number(-7), '/', number(2)),
        binary(number(-7), '%', number(2)),
        binary(number(7), '&&', number(9)),
        binary(number(0), '||', number(9)),
        binary(number(0), '&&', number(9)),
        binary(number(7), '==', number(8)),
        n(UnaryExpr => operator => '!', operand => number(7), prefix => 1),
        n(UnaryExpr => operator => '!', operand => number(0), prefix => 1),
    );
    is_deeply run_code(compile(program(func('main', block(
        printf_stmt(join(' ', ('%d') x @values), @values), ret(number(0))
    ))))), ["3 -3 -1 1 1 0 0 0 1\n", '', 0], 'C numeric semantics are preserved';
};

subtest 'control statements and uninitialized scalar declarations' => sub {
    my $i = ident('ギ');
    my $sum = ident('ガ');
    my $ast = program(func('main', block(
        n(VarDecl => type => 'int', name => 'ガ', initializer => undef),
        n(ForStmt => init => n(VarDecl => type => 'int', name => 'ギ', initializer => number(0)),
          condition => binary($i, '<', number(7)),
          update => n(UnaryExpr => operator => '++', operand => $i, prefix => 0),
          body => block(
              n(IfStmt => condition => binary($i, '==', number(2)),
                then_branch => n(ContinueStmt => ()), else_branch => undef),
              n(IfStmt => condition => binary($i, '==', number(5)),
                then_branch => n(BreakStmt => ()), else_branch => undef),
              expr(n(AssignExpr => target => $sum, value => binary($sum, '+', $i)))
          )),
        n(WhileStmt => condition => binary($sum, '<', number(10)),
          body => expr(n(UnaryExpr => operator => '++', operand => $sum, prefix => 1))),
        n(IfStmt => condition => binary($sum, '==', number(0)),
          then_branch => printf_stmt('zero'),
          else_branch => n(IfStmt => condition => binary($sum, '==', number(10)),
            then_branch => printf_stmt('%d', $sum), else_branch => printf_stmt('other'))),
        ret(number(0))
    )));
    my $code = compile($ast);
    like $code, qr/my \$ガ = 0;/, 'uninitialized declaration defaults to zero';
    like $code, qr/elsif/, 'else-if chain uses elsif';
    is_deeply run_code($code), ["10\n", '', 0], 'for, while, break, continue and single statements execute';
};

subtest 'printf strings and character literals' => sub {
    my $format = '日本語 $amount @array "quoted"';
    my $ast = program(func('main', block(
        printf_stmt($format), printf_stmt('already\\n'),
        printf_stmt("actual\n"), printf_stmt('%d %d %d %d',
          n(CharLiteral => value => 'Arest'), n(CharLiteral => value => ''),
          n(CharLiteral => value => '\\'), n(CharLiteral => value => "'")),
        ret(number(0))
    )));
    is_deeply run_code(compile($ast)), ["$format\nalready\nactual\n65 0 92 39\n", '', 0],
        'interpolation is escaped, newline is added once and chars are numeric';
};

subtest 'string payloads remain data when serialized into Perl' => sub {
    my $slash = chr 92;
    my $quote_payload = '" ); BEGIN { print q(ASCII_LITERAL_BYPASS); } #';
    my $control_payload = $slash . 'c' . '$' . '{' . $slash
        . 'print q(PERL_C_INTERPOLATION_BYPASS)}';
    my @cases = (
        [$slash . $quote_payload, $quote_payload, 'escaped quote cannot introduce a BEGIN block'],
        [$control_payload, $control_payload, 'unknown control escape cannot introduce interpolation'],
        ['trailing' . $slash, 'trailing' . $slash, 'trailing lone backslash remains data'],
        ['$name @names', '$name @names', 'plain interpolation sigils remain data'],
        [$slash . '$name ' . $slash . '@names', $slash . '$name ' . $slash . '@names',
            'unknown escapes before interpolation sigils remain data'],
        [$slash . 'p{ASCII} ' . $slash . 'cX', $slash . 'p{ASCII} ' . $slash . 'cX',
            'Perl-specific escapes remain literal data'],
        [join('', map { $slash . $_ } qw(a b f n r t v)), "\a\b\f\n\r\t" . chr(11),
            'standard C control escapes are decoded'],
        [$slash . $slash, $slash, 'escaped backslash is decoded'],
        [$slash . '"', '"', 'escaped double quote is decoded'],
        [$slash . "'", "'", 'escaped apostrophe is decoded'],
        [$slash . '?', '?', 'escaped question mark is decoded'],
        [$slash . '101' . $slash . '12' . $slash . '7', "A\n\a",
            'one to three octal digits are decoded'],
        [$slash . 'x41' . $slash . 'x0a', "A\n", 'hexadecimal escapes are decoded'],
        [$slash . 'x0041' . $slash . 'x00000a', "A\n", 'hexadecimal escapes consume leading zeroes'],
        [$slash . '1234', 'S4', 'octal escapes consume at most three digits'],
        [$slash . 'x100 ' . $slash . '400', $slash . 'x100 ' . $slash . '400',
            'numeric escapes outside the byte range remain literal data'],
    );
    for my $case (@cases) {
        my $ast = program(func('main', block(
            printf_stmt('%s', n(StringLiteral => value => $case->[0])),
            ret(number(0))
        )));
        is_deeply run_code(compile($ast)), [$case->[1] . "\n", '', 0], $case->[2];
    }
};

subtest 'unsupported syntax fails during generation' => sub {
    my @nodes = (
        n(VarDecl => type => 'int[]', name => 'x', initializer => undef),
        n(VarDecl => type => 'float', name => 'x', initializer => undef),
        n(VarDecl => type => 'double', name => 'x', initializer => undef),
        n(SwitchStmt => expression => number(1), cases => [], default_case => undef),
        expr(n(IndexExpr => array => ident('x'), index => number(0))),
        expr(call('scanf', number(1))), expr(call('sizeof', number(1))),
        expr(call('ジョリドシ', number(1))), expr(call('グンモウ', number(1))),
        expr(call('length', number(1))), expr(call('map', number(1))),
    );
    for my $node (@nodes) {
        my $ok = eval { compile(program(func('main', block($node, ret(number(0)))))); 1 };
        ok !$ok, ref($node) . ' is rejected';
        like "$@", qr/\APerl backend does not support/, 'error explains backend limit';
    }
    for my $name (qw(length map printf if BEGIN)) {
        my $ok = eval { compile(program(func($name, block(ret(number(0)))))); 1 };
        ok !$ok, "function name $name is rejected";
        like "$@", qr/\APerl backend does not support/, 'reserved name is reported';
    }
    for my $type ('float', 'double', 'int[]') {
        my $fn = func('main', block(ret(number(0))), n(Parameter => type => $type, name => 'x'));
        my $ok = eval { compile(program($fn)); 1 };
        ok !$ok, "$type parameter is rejected";
        like "$@", qr/\APerl backend does not support/, 'parameter limit is reported';
        $fn = func('main', block(ret(number(0))));
        $fn->{return_type} = $type;
        $ok = eval { compile(program($fn)); 1 };
        ok !$ok, "$type return type is rejected";
    }
};

done_testing;
