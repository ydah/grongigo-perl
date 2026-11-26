package Grongigo::CodeGen::C;
use v5.36;
use utf8;

my %STATEMENT = (
    BlockStmt => \&_block, VarDecl => \&_var, IfStmt => \&_if,
    WhileStmt => \&_while, ForStmt => \&_for, SwitchStmt => \&_switch,
    ReturnStmt => sub ($self, $node) {
        $self->_emit(defined $node->{value} ? 'return ' . $self->_expr($node->{value}) . ';' : 'return;');
    },
    BreakStmt => sub ($self, $node) { $self->_emit('break;') },
    ContinueStmt => sub ($self, $node) { $self->_emit('continue;') },
    ExprStmt => sub ($self, $node) { $self->_emit($self->_expr($node->{expression}) . ';') },
);
my %EXPRESSION = (
    BinaryExpr => sub ($self, $node) {
        '(' . $self->_expr($node->{left}) . " $node->{operator} " . $self->_expr($node->{right}) . ')';
    },
    UnaryExpr => sub ($self, $node) {
        my $operand = $self->_expr($node->{operand});
        $node->{prefix} ? "$node->{operator}$operand" : "$operand$node->{operator}";
    },
    AssignExpr => sub ($self, $node) { $self->_expr($node->{target}) . ' = ' . $self->_expr($node->{value}) },
    CallExpr => \&_call,
    IndexExpr => sub ($self, $node) { $self->_expr($node->{array}) . '[' . $self->_expr($node->{index}) . ']' },
    Identifier => sub ($self, $node) { sanitize_name($node->{name}) },
    NumberLiteral => sub ($self, $node) { "$node->{value}" },
    StringLiteral => sub ($self, $node) { '"' . escape_string($node->{value}) . '"' },
    CharLiteral => sub ($self, $node) { "'" . escape_char($node->{value}) . "'" },
);

sub new ($class) { bless {indent => 0, output => []}, $class }
sub _kind ($node) { ref($node) =~ s/.*:://r }
sub _emit ($self, $line) { push @{$self->{output}}, '    ' x $self->{indent} . $line }

sub generate ($self, $ast) {
    $self->{output} = [];
    $self->{indent} = 0;
    $self->_emit($_) for '#include <stdio.h>', '#include <stdlib.h>', '#include <string.h>', '';
    for my $declaration (@{$ast->{declarations}}) {
        if (_kind($declaration) eq 'FunctionDecl') { $self->_function($declaration) }
        else { $self->_statement($declaration) }
        $self->_emit('');
    }
    return join "\n", @{$self->{output}};
}

sub _function ($self, $node) {
    my $params = join ', ', map { $_->{type} . ' ' . sanitize_name($_->{name}) } @{$node->{params}};
    $params = 'void' if $params eq '' && $node->{name} eq 'main';
    $self->_emit($node->{return_type} . ' ' . sanitize_name($node->{name}) . "($params)");
    $self->_block($node->{body});
}

sub _block ($self, $node) {
    $self->_emit('{');
    ++$self->{indent};
    $self->_statement($_) for @{$node->{statements}};
    --$self->{indent};
    $self->_emit('}');
}

sub _statement ($self, $node) {
    my $generate = $STATEMENT{_kind($node)} // die 'Unknown statement type: ' . (ref($node) || 'NilClass') . "\n";
    $generate->($self, $node);
}

sub _var ($self, $node) {
    my $type = $node->{type};
    my $name = sanitize_name($node->{name});
    $name .= '[]' if $type =~ s/\[\]\z//;
    my $initializer = defined $node->{initializer} ? ' = ' . $self->_expr($node->{initializer}) : '';
    $self->_emit("$type $name$initializer;");
}

sub _body ($self, $node) {
    return $self->_block($node) if _kind($node) eq 'BlockStmt';
    ++$self->{indent};
    $self->_statement($node);
    --$self->{indent};
}

sub _if ($self, $node, $as_else = 0) {
    my $condition = 'if (' . $self->_expr($node->{condition}) . ')';
    if ($as_else) { $self->{output}[-1] .= " $condition" }
    else { $self->_emit($condition) }
    $self->_body($node->{then_branch});
    return unless defined $node->{else_branch};
    $self->_emit('else');
    if (_kind($node->{else_branch}) eq 'IfStmt') { $self->_if($node->{else_branch}, 1) }
    else { $self->_body($node->{else_branch}) }
}

sub _while ($self, $node) {
    $self->_emit('while (' . $self->_expr($node->{condition}) . ')');
    $self->_body($node->{body});
}

sub _for ($self, $node) {
    my $init = '';
    if (defined $node->{init}) {
        my $first = $node->{init};
        if (_kind($first) eq 'VarDecl') {
            $init = $first->{type} . ' ' . sanitize_name($first->{name});
            $init .= ' = ' . $self->_expr($first->{initializer}) if defined $first->{initializer};
        }
        else { $init = $self->_expr($first) }
    }
    my $condition = defined $node->{condition} ? $self->_expr($node->{condition}) : '';
    my $update = defined $node->{update} ? $self->_expr($node->{update}) : '';
    $self->_emit("for ($init; $condition; $update)");
    $self->_body($node->{body});
}

sub _switch ($self, $node) {
    $self->_emit('switch (' . $self->_expr($node->{expression}) . ')');
    $self->_emit('{');
    for my $case (@{$node->{cases}}) {
        $self->_emit('case ' . $self->_expr($case->{value}) . ':');
        ++$self->{indent};
        $self->_statement($_) for @{$case->{statements}};
        --$self->{indent};
    }
    if (defined $node->{default_case}) {
        $self->_emit('default:');
        ++$self->{indent};
        $self->_statement($_) for @{$node->{default_case}};
        --$self->{indent};
    }
    $self->_emit('}');
}

sub _expr ($self, $node) {
    my $generate = $EXPRESSION{_kind($node)} // die 'Unknown expression type: ' . (ref($node) || 'NilClass') . "\n";
    return $generate->($self, $node);
}

sub _call ($self, $node) {
    my @arguments = map { $self->_expr($_) } @{$node->{arguments}};
    my $callee = $node->{callee};
    if (_kind($callee) eq 'Identifier' && ($callee->{name} eq 'printf' || $callee->{name} eq 'ジョウジ')
        && @arguments && _kind($node->{arguments}[0]) eq 'StringLiteral') {
        my $value = $node->{arguments}[0]{value};
        $value .= '\n' unless $value =~ /(?:\\n|\n)\z/;
        $arguments[0] = '"' . escape_string($value) . '"';
    }
    return $self->_expr($callee) . '(' . join(', ', @arguments) . ')';
}

my %ROMAN = (
    'ア' => 'a', 'イ' => 'i', 'ウ' => 'u', 'エ' => 'e', 'オ' => 'o',
    'カ' => 'ka', 'キ' => 'ki', 'ク' => 'ku', 'ケ' => 'ke', 'コ' => 'ko',
    'サ' => 'sa', 'シ' => 'si', 'ス' => 'su', 'セ' => 'se', 'ソ' => 'so',
    'タ' => 'ta', 'チ' => 'ti', 'ツ' => 'tu', 'テ' => 'te', 'ト' => 'to',
    'ナ' => 'na', 'ニ' => 'ni', 'ヌ' => 'nu', 'ネ' => 'ne', 'ノ' => 'no',
    'ハ' => 'ha', 'ヒ' => 'hi', 'フ' => 'hu', 'ヘ' => 'he', 'ホ' => 'ho',
    'マ' => 'ma', 'ミ' => 'mi', 'ム' => 'mu', 'メ' => 'me', 'モ' => 'mo',
    'ヤ' => 'ya', 'ユ' => 'yu', 'ヨ' => 'yo', 'ラ' => 'ra', 'リ' => 'ri',
    'ル' => 'ru', 'レ' => 're', 'ロ' => 'ro', 'ワ' => 'wa', 'ヲ' => 'wo', 'ン' => 'n',
    'ガ' => 'ga', 'ギ' => 'gi', 'グ' => 'gu', 'ゲ' => 'ge', 'ゴ' => 'go',
    'ザ' => 'za', 'ジ' => 'zi', 'ズ' => 'zu', 'ゼ' => 'ze', 'ゾ' => 'zo',
    'ダ' => 'da', 'ヂ' => 'di', 'ヅ' => 'du', 'デ' => 'de', 'ド' => 'do',
    'バ' => 'ba', 'ビ' => 'bi', 'ブ' => 'bu', 'ベ' => 'be', 'ボ' => 'bo',
    'パ' => 'pa', 'ピ' => 'pi', 'プ' => 'pu', 'ペ' => 'pe', 'ポ' => 'po',
    'ジャ' => 'ja', 'ジュ' => 'ju', 'ジョ' => 'jo', 'ー' => '_',
);

sub sanitize_name ($name) {
    return $name if $name =~ /\A[A-Za-z_][A-Za-z0-9_]*\z/;
    my $result = '';
    while (length $name) {
        my $pair = substr($name, 0, 2);
        my $length = exists $ROMAN{$pair} ? 2 : 1;
        $result .= $ROMAN{substr($name, 0, $length, '')} // '_';
    }
    $result = "_$result" if $result =~ /\A[0-9]/;
    return length $result ? $result : 'var';
}

sub escape_string ($value) {
    $value =~ s/(\\*)"/$1 . (length($1) % 2 ? '' : '\\') . '"'/ge;
    $value =~ s/\n/\\n/g;
    $value =~ s/\t/\\t/g;
    $value =~ s/\r/\\r/g;
    $value =~ s/(\\+)\z/$1 . (length($1) % 2 ? '\\' : '')/e;
    return $value;
}

sub escape_char ($value) {
    return '\0' if $value eq '';
    my %escape = ('\\' => '\\\\', "'" => "\\'", "\n" => '\n', "\t" => '\t', "\r" => '\r');
    my $char = substr($value, 0, 1);
    return $escape{$char} // $char;
}

1;
