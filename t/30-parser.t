use strict;
use warnings;
use utf8;
BEGIN {
    binmode STDOUT, ':encoding(UTF-8)';
    binmode STDERR, ':encoding(UTF-8)';
}
use Test::More;

use_ok('Grongigo::Parser') or BAIL_OUT('Parser is not implemented');
require Grongigo::Lexer;
require Grongigo::AST;

sub program {
    my ($source) = @_;
    return Grongigo::Parser->new(Grongigo::Lexer->new($source)->tokenize)->parse;
}

sub declaration { program($_[0])->{declarations}[0] }
sub expression { declaration($_[0])->{expression} }
sub statement { declaration("パザ バサ デギド バサ ザジレ $_[0] ゴパシ")->{body}{statements}[0] }
sub kind { (ref($_[0]) =~ /::([^:]+)\z/)[0] }
sub parse_error {
    my ($source) = @_;
    eval { program($source) };
    my $error = $@;
    isa_ok($error, 'Grongigo::ParseError');
    return $error;
}

subtest 'declarations and all parameter syntaxes' => sub {
    my $empty = program('');
    isa_ok($empty, 'Grongigo::AST::Program');
    is_deeply($empty->{declarations}, []);
    is_deeply([@$empty{qw(line column)}], [0, 0]);

    for my $source (
        'パザ バサ デギド バサ ザジレ ゴパシ',
        'パザ バサ デギド ジサビバッボ バサ ドジバッボ ザジレ ゴパシ',
        'パザ バサ デギド ジサビバッボ ドジバッボ ザジレ ゴパシ',
        'バサ デギド ジサビバッボ ドジバッボ ザジレ ゴパシ',
    ) {
        my $function = declaration($source);
        is(kind($function), 'FunctionDecl', $source);
        is($function->{name}, 'デギド');
        is($function->{return_type}, 'void');
        is_deeply($function->{params}, []);
        is(kind($function->{body}), 'BlockStmt');
    }
    for my $params (
        'ゲギグウ バ、ゲギグウ ダ',
        'ジサビバッボ ゲギグウ バ、ゲギグウ ダ ドジバッボ',
    ) {
        my $function = declaration("パザ ゲギグウ ダギ $params ザジレ ゴパシ");
        is($function->{return_type}, 'int');
        is_deeply([map { [@$_{qw(type name line column)}] } @{$function->{params}}],
            [['int', 'バ', 0, 0], ['int', 'ダ', 0, 0]]);
    }
    my $function = declaration('ゲギグウ ガ ジサビバッボ ゲギグウ ダ ドジバッボ ザジレ ゴパシ');
    is($function->{params}[0]{name}, 'ダ');
    is_deeply(declaration('パザ バサ ガ ゲギグウ ザジレ ゴパシ')->{params}, [],
        'a lone type before the block is discarded like Ruby');
    my $main = declaration("\nパザ ゲギグウ ゴロ バサ ザジレ ロゾス ゼゼソ ゴパシ");
    is($main->{name}, 'main');
    is_deeply([@$main{qw(line column)}], [2, 4]);
    is($main->{body}{statements}[0]{value}{value}, 0);

    my $var = declaration('ゲギグウ バ');
    is(kind($var), 'VarDecl');
    is_deeply([@$var{qw(type name initializer line column)}], ['int', 'バ', undef, 1, 1]);
    $var = declaration('ゲギグウ バ ギセス パパン');
    is(kind($var->{initializer}), 'NumberLiteral');
    is($var->{initializer}{value}, 1);
    is(scalar @{program('ゲギグウ バ ダグ パパン')->{declarations}}, 2,
        'top-level declaration consumes a non-assignment operator like Ruby');
    my $array = statement('ゲギグウ バ ジサビバブバッボ バギン ドジバブバッボ');
    is($array->{type}, 'int[]');
    ok(!exists $array->{size}, 'Ruby discards the array size');
    is(statement('ゲギグウ バ ジサビバブバッボ ドジバブバッボ ギセス ゼゼソ')->{initializer}{value}, 0);
};

subtest 'statements and their source locations' => sub {
    my $if = statement('ジョウベン バ ザジレ ロゾス ゴパシ ゾバ ザジレ ブゲス ゴパシ');
    is(kind($if), 'IfStmt');
    is(kind($if->{condition}), 'Identifier');
    is(kind($if->{then_branch}), 'BlockStmt');
    is(kind($if->{else_branch}), 'BlockStmt');
    is(kind($if->{then_branch}{statements}[0]), 'ReturnStmt');
    ok(!defined $if->{then_branch}{statements}[0]{value});
    $if = statement('ジョウベン バ ブゲス ゾバ ジョウベン ダ ヅヅゲス ゾバ ロゾス');
    is(kind($if->{then_branch}), 'BreakStmt');
    is(kind($if->{else_branch}), 'IfStmt');
    is(kind($if->{else_branch}{then_branch}), 'ContinueStmt');
    is(kind($if->{else_branch}{else_branch}), 'ReturnStmt');
    ok(!defined statement('ジョウベン バ ブゲス')->{else_branch});

    my $while = statement('ガギザ バ ザジレ ブゲス ゴパシ');
    is(kind($while), 'WhileStmt');
    is($while->{condition}{name}, 'バ');
    is(kind(statement('ガギザ バ ヅヅゲス')->{body}), 'ContinueStmt');
    my $for = statement('ブシバゲギ ジサビバッボ ゲギグウ ギ ギセス ゼゼソ、ギ ギョウバシ バギン、ギ ダグダグ ドジバッボ ザジレ ロゾス ゴパシ');
    is(kind($for), 'ForStmt');
    is(kind($for->{init}), 'VarDecl');
    is($for->{condition}{operator}, '<');
    is($for->{update}{operator}, '++');
    ok(!$for->{update}{prefix});
    $for = statement('ブシバゲギ ジサビバッボ バ ギセス ゼゼソ、、 ドジバッボ ブゲス');
    is(kind($for->{init}), 'AssignExpr');
    ok(!defined $for->{condition});
    ok(!defined $for->{update});
    $for = statement('ブシバゲギ ジサビバッボ 、、 ドジバッボ ブゲス');
    ok(!defined $for->{init});
    $for = statement('ブシバゲギ バ ブゲス');
    ok(!defined $for->{init});
    is($for->{condition}{name}, 'バ');

    my $switch = statement('ゲンダブ バ ザジレ ダガギ パパン： ブゲス ダガギ ドググ： ヅヅゲス ビデギ： ロゾス ゴパシ');
    is(kind($switch), 'SwitchStmt');
    is($switch->{expression}{name}, 'バ');
    is(scalar @{$switch->{cases}}, 2);
    is(kind($switch->{cases}[0]), 'CaseClause');
    is($switch->{cases}[0]{value}{value}, 1);
    is_deeply([@{$switch->{cases}[0]}{qw(line column)}], [0, 0]);
    is(kind($switch->{default_case}[0]), 'ReturnStmt');
    $switch = statement('ゲンダブ バ ザジレ ゴパシ');
    is_deeply($switch->{cases}, []);
    ok(!defined $switch->{default_case});

    for my $source ('ロゾス', 'ロゾス ブゲス', 'ロゾス ゲギグウ バ') {
        ok(!defined statement($source)->{value}, "bare return: $source");
    }
    ok(!defined declaration('ロゾス')->{value}, 'return before EOF');
    is(statement('ロゾス ゼゼソ')->{value}{value}, 0);
};

subtest 'expressions and Ruby-compatible precedence' => sub {
    my @operators = (
        ['ラダパ', '||'], ['バヅ', '&&'], ['ゴガ', '|'], ['ガンド', '&'],
        ['ジドギギ', '=='], ['ジドギグバギ', '!='],
        ['ギョウバシ', '<'], ['ザギバシ', '>'], ['ギバ', '<='], ['ギジョウ', '>='],
        ['ダグ', '+'], ['ジブ', '-'], ['バゲス', '*'], ['パス', '/'], ['ガラシ', '%'],
    );
    for my $operator (@operators) {
        my ($word, $symbol) = @$operator;
        my $binary = expression("バ $word ダ $word ザ");
        is($binary->{operator}, $symbol);
        is($binary->{left}{operator}, $symbol, "$symbol is left-associative");
        is($binary->{right}{name}, 'ザ');
    }
    my $binary = expression('ガ ダグ ダ バゲス ザ');
    is($binary->{operator}, '+');
    is($binary->{right}{operator}, '*');
    $binary = expression('ガ ギョウバシ ダ バヅ ザ ザギバシ ゾ');
    is($binary->{operator}, '&&');
    is($binary->{left}{operator}, '<');
    is($binary->{right}{operator}, '>');
    $binary = expression('ガ ラダパ ダ バヅ ザ ゴガ ゾ ガンド バ ジドギギ ラ ギョウバシ リ ダグ ル バゲス レ');
    for my $op ('||', '&&', '|', '&', '==', '<', '+', '*') {
        is($binary->{operator}, $op, "precedence $op");
        $binary = $binary->{right};
    }
    $binary = expression('ジサビバッボ ガ ダグ ダ ドジバッボ バゲス ザ');
    is($binary->{operator}, '*');
    is($binary->{left}{operator}, '+');
    my $assignment = expression('バ ギセス ダ ギセス パパン');
    is(kind($assignment), 'AssignExpr');
    is(kind($assignment->{value}), 'AssignExpr', 'assignment is right-associative');
    is($assignment->{value}{target}{name}, 'ダ');

    for my $operator (['ジデギ', '!'], ['ジブ', '-'], ['ダグダグ', '++'], ['ジブジブ', '--']) {
        my $unary = expression("$operator->[0] バ");
        is(kind($unary), 'UnaryExpr');
        is($unary->{operator}, $operator->[1]);
        ok($unary->{prefix});
        is($unary->{column}, length($operator->[0]) + 2, 'prefix position comes from operand');
    }
    is(expression('ジデギ ジブ バ')->{operand}{operator}, '-');
    for my $operator (['ダグダグ', '++'], ['ジブジブ', '--']) {
        my $unary = expression("バ $operator->[0]");
        is($unary->{operator}, $operator->[1]);
        ok(!$unary->{prefix});
    }
    my $call = expression('ジョウジジサビバッボジサビロジセヅゼソドジロジセヅ、パパン ドジバッボ');
    is(kind($call), 'CallExpr');
    is($call->{callee}{name}, 'printf');
    is(scalar @{$call->{arguments}}, 2);
    is($call->{arguments}[0]{value}, 'ゼソ');
    is_deeply(expression('ガ ジサビバッボ ドジバッボ')->{arguments}, []);
    my $chain = expression('ガ ジサビバッボ ドジバッボ ジサビバブバッボ ゼゼソ ドジバブバッボ ダグダグ');
    is(kind($chain), 'UnaryExpr');
    is(kind($chain->{operand}), 'IndexExpr');
    is(kind($chain->{operand}{array}), 'CallExpr');
    is($chain->{operand}{index}{value}, 0);
};

subtest 'literal values and keywords used as names' => sub {
    for my $case (['パパン', 'NumberLiteral', 1], ['ギン', 'NumberLiteral', 1],
        ['ビゲ', 'NumberLiteral', 0], ['ジサビロジセヅtextドジロジセヅ', 'StringLiteral', 'text'],
        ['ジサビジドロジガドジジドロジ', 'CharLiteral', 'ガ']) {
        my $literal = expression($case->[0]);
        is(kind($literal), $case->[1]);
        is($literal->{value}, $case->[2]);
    }
    for my $case (['ルヂ', 'NULL'], ['ゴロ', 'main'], ['ジョウジ', 'printf'], ['ゾバ', 'else'], ['ボウゾウ', 'struct']) {
        my $identifier = declaration("ゲギグウ バ ギセス $case->[0]")->{initializer};
        is(kind($identifier), 'Identifier');
        is($identifier->{name}, $case->[1]);
    }
};

subtest 'parse errors contain Ruby messages and the offending token' => sub {
    is('' . parse_error('ゲギグウ ゲギグウ'), 'Expected identifier at line 1');
    my $error = parse_error("ゲギグウ バ ギセス パパン。\n");
    is("$error", 'Unexpected token: ";" (type: semicolon) at line 1');
    is($error->{token}{type}, 'semicolon');
    is($error->{token}{column}, 15);
    for my $case (
        ['パザ バ ザジレ', 'Expected return type at line 1, column 4'],
        ['パザ バサ ガ ジサビバッボ バ ドジバッボ', 'Expected parameter type at line 1, column 16'],
        ['パザ バサ ガ バサ', 'Expected { at line 1, column 11'],
        ['ザジレ', 'Expected } at line 1, column 4'],
        ['ガ ジサビバッボ', 'Unexpected token: nil (type: eof) at line 1'],
        ['バ ジサビバブバッボ ゼゼソ', 'Expected ] at line 1, column 15'],
        ['ゲギグウ バ ギセス', 'Unexpected token: nil (type: eof) at line 1'],
        ['ゲンダブ バ ザジレ ダガギ パパン ゴパシ', 'Expected : at line 1, column 20'],
    ) {
        is('' . parse_error($case->[0]), $case->[1], $case->[0]);
    }
    for my $source ('ゲンダブ バ ザジレ ダガギ パパン：', 'ゲンダブ バ ザジレ ビデギ：') {
        my $error;
        {
            local $SIG{ALRM} = sub { die "Parser did not terminate\n" };
            alarm 1;
            eval { program($source) };
            $error = $@;
            alarm 0;
        }
        isa_ok($error, 'Grongigo::ParseError');
        like("$error", qr/^Expected \} at line 1, column \d+$/, 'unterminated switch reports EOF');
    }
};

subtest 'AST rendering includes every supported node' => sub {
    my $source = 'パザ ゲギグウ ガ ゲギグウ バ ザジレ ゲギグウ ダ ギセス パパン ジョウベン バ ザジレ ジブジブ ダ ゴパシ ゾバ ダ ダグダグ ガギザ バ ブゲス ブシバゲギ バ ヅヅゲス ロゾス ガ ジサビバッボ ダ ダグ ドググ、ジサビロジセヅxドジロジセヅ、ジサビジドロジaドジジドロジ ドジバッボ ゴパシ';
    my $text = Grongigo::AST::print_ast(program($source));
    like($text, qr/^Program\n  FunctionDecl: int ガ\n    Parameter: int バ\n    BlockStmt\n/m);
    for my $text_part ('VarDecl: int ダ', 'NumberLiteral: 1', 'IfStmt',
        'UnaryExpr: -- (prefix=true)', 'UnaryExpr: ++ (prefix=false)', 'WhileStmt',
        'BreakStmt', 'ForStmt', 'ContinueStmt', 'ReturnStmt', 'CallExpr',
        'BinaryExpr: +', 'StringLiteral: "x"', 'CharLiteral: "a"', 'ExprStmt', 'Identifier: バ') {
        like($text, qr/\Q$text_part\E/, $text_part);
    }
    like(Grongigo::AST::print_ast(program('バ ギセス ガ ジサビバブバッボ パパン ドジバブバッボ')), qr/AssignExpr\n.*Identifier: バ\n.*IndexExpr/s);
    is(Grongigo::AST::print_ast(declaration('ゲンダブ バ ザジレ ゴパシ')),
        "Unknown: Grongigo::AST::SwitchStmt\n", 'switch retains Ruby unknown-node display');
    my $node = Grongigo::AST::node('BreakStmt');
    is_deeply([@$node{qw(line column)}], [0, 0]);
    is(Grongigo::AST::print_ast($node, 2), "    BreakStmt\n");
    is(Grongigo::AST::print_ast(declaration('ジョウベン ギン')),
        "IfStmt\n  NumberLiteral: 1\n  Unknown: NilClass\n", 'missing required branch retains Ruby nil display');
    is(Grongigo::AST::print_ast(declaration('ガギザ ギン')),
        "WhileStmt\n  NumberLiteral: 1\n  Unknown: NilClass\n");
    is(Grongigo::AST::print_ast(declaration('ブシバゲギ ギン')),
        "ForStmt\n  NumberLiteral: 1\n  Unknown: NilClass\n");
};

done_testing;
