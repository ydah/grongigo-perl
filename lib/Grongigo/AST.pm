package Grongigo::AST;
use v5.36;
use Exporter 'import';
use Grongigo::Inspect qw(inspect);

our @EXPORT_OK = qw(node print_ast);

sub node ($kind, %fields) {
    return bless { line => 0, column => 0, %fields }, "Grongigo::AST::$kind";
}

my %FORMAT = (
    Program => sub ($n) { ('Program', @{$n->{declarations}}) },
    FunctionDecl => sub ($n) { ("FunctionDecl: $n->{return_type} $n->{name}", @{$n->{params}}, $n->{body}) },
    Parameter => sub ($n) { ("Parameter: $n->{type} $n->{name}") },
    VarDecl => sub ($n) { ("VarDecl: $n->{type} $n->{name}", grep { defined } $n->{initializer}) },
    BlockStmt => sub ($n) { ('BlockStmt', @{$n->{statements}}) },
    IfStmt => sub ($n) { ('IfStmt', @$n{qw(condition then_branch)}, grep { defined } $n->{else_branch}) },
    WhileStmt => sub ($n) { ('WhileStmt', @$n{qw(condition body)}) },
    ForStmt => sub ($n) { ('ForStmt', (grep { defined } @$n{qw(init condition update)}), $n->{body}) },
    ReturnStmt => sub ($n) { ('ReturnStmt', grep { defined } $n->{value}) },
    BreakStmt => sub ($n) { ('BreakStmt') },
    ContinueStmt => sub ($n) { ('ContinueStmt') },
    ExprStmt => sub ($n) { ('ExprStmt', $n->{expression}) },
    BinaryExpr => sub ($n) { ("BinaryExpr: $n->{operator}", @$n{qw(left right)}) },
    UnaryExpr => sub ($n) { ('UnaryExpr: ' . $n->{operator} . ' (prefix=' . ($n->{prefix} ? 'true' : 'false') . ')', $n->{operand}) },
    AssignExpr => sub ($n) { ('AssignExpr', @$n{qw(target value)}) },
    CallExpr => sub ($n) { ('CallExpr', $n->{callee}, @{$n->{arguments}}) },
    IndexExpr => sub ($n) { ('IndexExpr', @$n{qw(array index)}) },
    Identifier => sub ($n) { ("Identifier: $n->{name}") },
    NumberLiteral => sub ($n) { ("NumberLiteral: $n->{value}") },
    StringLiteral => sub ($n) { ('StringLiteral: ' . inspect($n->{value})) },
    CharLiteral => sub ($n) { ('CharLiteral: ' . inspect($n->{value})) },
);

sub print_ast ($n, $indent = 0) {
    return ('  ' x $indent) . "Unknown: NilClass\n" unless defined $n;
    my ($kind) = ref($n) =~ /::([^:]+)\z/;
    my ($label, @children) = $FORMAT{$kind}
        ? $FORMAT{$kind}->($n) : ('Unknown: ' . ref($n));
    return ('  ' x $indent) . $label . "\n"
        . join('', map { print_ast($_, $indent + 1) } @children);
}

1;
