use v5.36;
use utf8;
use Test::More;
use Grongigo::CodeGen::C;

sub n ($kind, %fields) { bless \%fields, "Grongigo::AST::$kind" }
sub number ($value) { n(NumberLiteral => value => $value) }
sub ident ($name) { n(Identifier => name => $name) }
sub block (@statements) { n(BlockStmt => statements => \@statements) }
sub main_program (@statements) {
    n(Program => declarations => [n(FunctionDecl => return_type => 'int', name => 'main',
        params => [], body => block(@statements))]);
}
my $headers = "#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n\n";
my $generator = Grongigo::CodeGen::C->new;
is $generator->generate(main_program(n(ReturnStmt => value => number(0)))),
    $headers . "int main(void)\n{\n    return 0;\n}\n", 'complete program and final newline match Ruby';
is $generator->generate(n(Program => declarations => [])), $headers =~ s/\n\z//r,
    'empty program matches Ruby and generator can be reused';

sub expression_is ($expression, $expected, $label) {
    is $generator->generate(main_program(n(ExprStmt => expression => $expression))),
        $headers . "int main(void)\n{\n    $expected;\n}\n", $label;
}
expression_is number('1.0'), '1.0', 'preserve float spelling';
expression_is n(BinaryExpr => left => number(1), operator => '+', right => number(2)),
    '(1 + 2)', 'binary expression';
expression_is n(UnaryExpr => operator => '-', operand => ident('x'), prefix => 1), '-x', 'prefix unary';
expression_is n(UnaryExpr => operator => '++', operand => ident('x'), prefix => 0), 'x++', 'postfix unary';
expression_is n(AssignExpr => target => ident('x'), value => number(1)), 'x = 1', 'assignment';
expression_is n(IndexExpr => array => ident('arr'), index => number(0)), 'arr[0]', 'array index';
expression_is n(StringLiteral => value => "a\\n\"\n\t\r"), '"a\n\"\n\t\r"', 'C string escaping preserves backslashes';
my $slash = chr 92;
for my $case ([0, 1], [1, 1], [2, 3], [3, 3], [4, 5]) {
    expression_is n(StringLiteral => value => 'text' . ($slash x $case->[0]) . '"data'),
        '"text' . ($slash x $case->[1]) . '"data"',
        "quote after $case->[0] backslashes stays inside the string";
}
for my $case ([0, 0], [1, 2], [2, 2], [3, 4], [4, 4]) {
    expression_is n(StringLiteral => value => 'text' . ($slash x $case->[0])),
        '"text' . ($slash x $case->[1]) . '"',
        "closing quote follows $case->[0] trailing backslashes";
}
expression_is n(StringLiteral => value => 'text\n\t\r'), '"text\n\t\r"',
    'native C newline, tab and carriage-return escapes are preserved';
for my $case (['', '\\0'], ['\\', '\\\\'], ["'", "\\'"], ["\n", '\\n'], ["\t", '\\t'], ["\r", '\\r'], ['abc', 'a']) {
    expression_is n(CharLiteral => value => $case->[0]), "'$case->[1]'", 'character escape';
}
for my $name (['ASCII_1', 'ASCII_1'], ['ジャジュジョー', 'jajujo_'], ['カウンタ', 'kaunta'], ['漢字', '__'], ['', 'var']) {
    expression_is ident($name->[0]), $name->[1], 'identifier conversion';
}
for my $value ('hello', 'hello\\n', "hello\n") {
    expression_is n(CallExpr => callee => ident('printf'), arguments => [n(StringLiteral => value => $value), number(1)]),
        'printf("hello\n", 1)', 'printf adds exactly one newline';
}
expression_is n(CallExpr => callee => ident('f'), arguments => [number(1)]), 'f(1)', 'ordinary call';
expression_is n(CallExpr => callee => ident('printf'), arguments => []), 'printf()', 'printf without arguments';

my $vars = n(Program => declarations => [
    n(VarDecl => type => 'int', name => 'a', initializer => undef),
    n(VarDecl => type => 'int', name => 'b', initializer => number(2)),
    n(VarDecl => type => 'char[]', name => 'c', initializer => n(StringLiteral => value => 'abc')),
    n(VarDecl => type => 'int[]', name => 'd', initializer => undef),
]);
is $generator->generate($vars), $headers . "int a;\n\nint b = 2;\n\nchar c[] = \"abc\";\n\nint d[];\n", 'variables and array declarations';
my $fn = n(Program => declarations => [n(FunctionDecl => return_type => 'void', name => 'f',
    params => [n(Parameter => type => 'int', name => 'バ')], body => block(n(ReturnStmt => value => undef)))]);
is $generator->generate($fn), $headers . "void f(int ba)\n{\n    return;\n}\n", 'parameters and empty return';

my $branch = n(IfStmt => condition => ident('a'), then_branch => block(n(BreakStmt => ())),
    else_branch => n(IfStmt => condition => ident('b'), then_branch => n(ContinueStmt => ()),
        else_branch => block(n(ReturnStmt => value => number(0)))));
is $generator->generate(main_program($branch)), $headers . <<'C', 'else if and both body forms';
int main(void)
{
    if (a)
    {
        break;
    }
    else if (b)
        continue;
    else
    {
        return 0;
    }
}
C

my $loops = main_program(
    n(WhileStmt => condition => ident('x'), body => n(BreakStmt => ())),
    n(ForStmt => init => n(VarDecl => type => 'int', name => 'i', initializer => number(0)),
        condition => ident('i'), update => n(UnaryExpr => operator => '++', operand => ident('i'), prefix => 0),
        body => block(n(ContinueStmt => ()))),
    n(ForStmt => init => undef, condition => undef, update => undef, body => n(BreakStmt => ())),
);
is $generator->generate($loops), $headers . <<'C', 'while, for and omitted for clauses';
int main(void)
{
    while (x)
        break;
    for (int i = 0; i; i++)
    {
        continue;
    }
    for (; ; )
        break;
}
C

my $switch = n(SwitchStmt => expression => ident('x'), cases => [n(CaseClause => value => number(1), statements => [n(BreakStmt => ())])], default_case => [n(ReturnStmt => value => number(0))]);
is $generator->generate(main_program($switch)), $headers . <<'C', 'switch labels align with braces';
int main(void)
{
    switch (x)
    {
    case 1:
        break;
    default:
        return 0;
    }
}
C

eval { $generator->generate(main_program(n(Bogus => ()))) };
like $@, qr/Unknown statement type: Grongigo::AST::Bogus/, 'unknown statement fails';
eval { $generator->generate(main_program(n(ExprStmt => expression => n(Bogus => ())))) };
like $@, qr/Unknown expression type: Grongigo::AST::Bogus/, 'unknown expression fails';
eval { $generator->generate(main_program(undef)) };
is $@, "Unknown statement type: NilClass\n", 'missing statement uses Ruby nil class name';
eval { $generator->generate(main_program(n(ExprStmt => expression => undef))) };
is $@, "Unknown expression type: NilClass\n", 'missing expression uses Ruby nil class name';
done_testing;
