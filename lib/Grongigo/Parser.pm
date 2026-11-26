package Grongigo::Parser;
use v5.36;
use utf8;
use Grongigo::AST qw(node);
use Grongigo::Inspect qw(inspect);
use Grongigo::ParseError;

my %PRECEDENCE = (
    '||' => 1, '&&' => 2, '|' => 3, '&' => 4,
    '==' => 5, '!=' => 5,
    '<' => 6, '>' => 6, '<=' => 6, '>=' => 6,
    '+' => 7, '-' => 7, '*' => 8, '/' => 8, '%' => 8,
);

my %STATEMENT = (
    if => \&parse_if, while => \&parse_while, for => \&parse_for,
    switch => \&parse_switch, return => \&parse_return,
    break => sub ($self) {
        my %position = $self->location;
        $self->advance;
        return node('BreakStmt', %position);
    },
    continue => sub ($self) {
        my %position = $self->location;
        $self->advance;
        return node('ContinueStmt', %position);
    },
);

sub new ($class, $tokens) { bless { tokens => $tokens, pos => 0 }, $class }
sub current ($self) { $self->{tokens}[$self->{pos}] }
sub location ($self) { (line => $self->current->{line}, column => $self->current->{column}) }
sub eof ($self) { $self->current->{type} eq 'eof' }

sub check ($self, $type) {
    return $self->eof if $type eq 'eof';
    return !$self->eof && $self->current->{type} eq $type;
}

sub check_value ($self, $value) {
    return !$self->eof && $self->current->{value} eq $value;
}

sub advance ($self) {
    $self->{pos}++ unless $self->eof;
    return $self->{tokens}[$self->{pos} - 1];
}

sub match ($self, $type) {
    return undef unless $self->check($type);
    return $self->advance;
}

sub consume ($self, $type, $message) {
    return $self->advance if $self->check($type);
    my $token = $self->current;
    die Grongigo::ParseError->new("$message at line $token->{line}, column $token->{column}", $token);
}

sub parse ($self) {
    my @declarations;
    push @declarations, $self->parse_declaration until $self->eof;
    return node('Program', declarations => \@declarations);
}

sub parse_declaration ($self) {
    return $self->parse_function if $self->check('other_keyword') && $self->check_value('パザ');
    return $self->parse_var_or_function if $self->check('type_keyword');
    return $self->parse_statement;
}

sub parse_name ($self) {
    return $self->advance->{value} if $self->check('identifier') || $self->check('other_keyword');
    my $token = $self->current;
    die Grongigo::ParseError->new("Expected identifier at line $token->{line}", $token);
}

sub parse_parenthesized_params ($self, $allow_void = 0) {
    my @params;
    if (!$self->check('close_paren')) {
        if ($allow_void && $self->check('type_keyword') && $self->check_value('void')) {
            $self->advance;
        }
        else {
            do {
                my $type = $self->consume('type_keyword', 'Expected parameter type')->{value};
                push @params, node('Parameter', type => $type, name => $self->parse_name);
            } while $self->match('comma');
        }
    }
    $self->consume('close_paren', 'Expected )');
    return \@params;
}

sub parse_function ($self) {
    $self->advance;
    my %position = $self->location;
    my $type = $self->consume('type_keyword', 'Expected return type')->{value};
    my $name = $self->parse_name;
    my $params = [];
    if ($self->match('open_paren')) {
        $params = $self->parse_parenthesized_params(1);
    }
    elsif ($self->check('type_keyword') && $self->check_value('void')) {
        $self->advance;
    }
    elsif ($self->check('type_keyword')) {
        while (1) {
            my $param_type = $self->advance->{value};
            last if $self->check('open_brace');
            push @$params, node('Parameter', type => $param_type, name => $self->parse_name);
            last unless $self->match('comma');
        }
    }
    my $body = $self->parse_block;
    return node('FunctionDecl', return_type => $type, name => $name, params => $params, body => $body, %position);
}

sub parse_var_or_function ($self) {
    my %position = $self->location;
    my $type = $self->advance->{value};
    my $name = $self->parse_name;
    if ($self->match('open_paren')) {
        my $params = $self->parse_parenthesized_params;
        my $body = $self->parse_block;
        return node('FunctionDecl', return_type => $type, name => $name, params => $params, body => $body, %position);
    }
    my $initializer;
    my $operator = $self->match('operator');
    $initializer = $self->parse_expression if $operator && $operator->{value} eq '=';
    return node('VarDecl', type => $type, name => $name, initializer => $initializer, %position);
}

sub parse_statement ($self) {
    return undef if $self->eof;
    return $self->parse_block if $self->check('open_brace');
    if ($self->check('control_keyword') && (my $parse = $STATEMENT{$self->current->{value}})) {
        return $parse->($self);
    }
    return $self->parse_var if $self->check('type_keyword');
    my %position = $self->location;
    return node('ExprStmt', expression => $self->parse_expression, %position);
}

sub parse_block ($self) {
    my %position = $self->location;
    $self->consume('open_brace', 'Expected {');
    my @statements;
    push @statements, $self->parse_statement until $self->check('close_brace') || $self->eof;
    $self->consume('close_brace', 'Expected }');
    return node('BlockStmt', statements => \@statements, %position);
}

sub parse_if ($self) {
    my %position = $self->location;
    $self->advance;
    my $condition = $self->parse_expression;
    my $then_branch = $self->parse_statement;
    my $else_branch;
    if ($self->check('control_keyword') && $self->check_value('else')) {
        $self->advance;
        $else_branch = $self->parse_statement;
    }
    return node('IfStmt', condition => $condition, then_branch => $then_branch, else_branch => $else_branch, %position);
}

sub parse_while ($self) {
    my %position = $self->location;
    $self->advance;
    my $condition = $self->parse_expression;
    my $body = $self->parse_statement;
    return node('WhileStmt', condition => $condition, body => $body, %position);
}

sub parse_for ($self) {
    my %position = $self->location;
    $self->advance;
    my ($init, $condition, $update);
    if ($self->match('open_paren')) {
        $init = $self->check('type_keyword') ? $self->parse_var : $self->parse_expression
            unless $self->check('comma');
        $self->consume('comma', 'Expected ,');
        $condition = $self->parse_expression unless $self->check('comma');
        $self->consume('comma', 'Expected ,');
        $update = $self->parse_expression unless $self->check('close_paren');
        $self->consume('close_paren', 'Expected )');
    }
    else {
        $condition = $self->parse_expression;
    }
    my $body = $self->parse_statement;
    return node('ForStmt', init => $init, condition => $condition, update => $update, body => $body, %position);
}

sub parse_switch ($self) {
    my %position = $self->location;
    $self->advance;
    my $expression = $self->parse_expression;
    $self->consume('open_brace', 'Expected {');
    my (@cases, $default_case);
    until ($self->check('close_brace') || $self->eof) {
        if ($self->check('control_keyword') && $self->check_value('case')) {
            $self->advance;
            my $value = $self->parse_expression;
            $self->consume('colon', 'Expected :');
            my @statements;
            until ($self->check('close_brace') || $self->eof
                || ($self->check('control_keyword') && ($self->check_value('case') || $self->check_value('default')))) {
                push @statements, $self->parse_statement;
            }
            push @cases, node('CaseClause', value => $value, statements => \@statements);
        }
        elsif ($self->check('control_keyword') && $self->check_value('default')) {
            $self->advance;
            $self->consume('colon', 'Expected :');
            my @statements;
            until ($self->check('close_brace') || $self->eof
                || ($self->check('control_keyword') && $self->check_value('case'))) {
                push @statements, $self->parse_statement;
            }
            $default_case = \@statements;
        }
        else { last }
    }
    $self->consume('close_brace', 'Expected }');
    return node('SwitchStmt', expression => $expression, cases => \@cases, default_case => $default_case, %position);
}

sub parse_return ($self) {
    my %position = $self->location;
    $self->advance;
    my $value;
    $value = $self->parse_expression unless $self->check('close_brace') || $self->eof
        || $self->check('control_keyword') || $self->check('type_keyword');
    return node('ReturnStmt', value => $value, %position);
}

sub parse_var ($self) {
    my %position = $self->location;
    my $type = $self->advance->{value};
    my $name = $self->parse_name;
    if ($self->match('open_bracket')) {
        $self->parse_expression unless $self->check('close_bracket');
        $self->consume('close_bracket', 'Expected ]');
        $type .= '[]';
    }
    my $initializer;
    if ($self->check('operator') && $self->check_value('=')) {
        $self->advance;
        $initializer = $self->parse_expression;
    }
    return node('VarDecl', type => $type, name => $name, initializer => $initializer, %position);
}

sub parse_expression ($self) {
    my $expression = $self->parse_binary;
    if ($self->check('operator') && $self->check_value('=')) {
        $self->advance;
        return node('AssignExpr', target => $expression, value => $self->parse_expression,
            line => $expression->{line}, column => $expression->{column});
    }
    return $expression;
}

sub parse_binary ($self, $minimum = 1) {
    my $left = $self->parse_unary;
    while ($self->check('operator')) {
        my $operator = $self->current->{value};
        my $precedence = $PRECEDENCE{$operator} // 0;
        last if $precedence < $minimum;
        $self->advance;
        my $right = $self->parse_binary($precedence + 1);
        $left = node('BinaryExpr', left => $left, operator => $operator, right => $right,
            line => $left->{line}, column => $left->{column});
    }
    return $left;
}

sub parse_unary ($self) {
    if ($self->check('operator') && $self->current->{value} =~ /\A(?:!|-|\+\+|--)\z/) {
        my $operator = $self->advance->{value};
        my $operand = $self->parse_unary;
        return node('UnaryExpr', operator => $operator, operand => $operand, prefix => 1,
            line => $operand->{line}, column => $operand->{column});
    }
    return $self->parse_postfix;
}

sub parse_postfix ($self) {
    my $expression = $self->parse_primary;
    while (1) {
        my %position = (line => $expression->{line}, column => $expression->{column});
        if ($self->match('open_paren')) {
            my @arguments;
            unless ($self->check('close_paren')) {
                do { push @arguments, $self->parse_expression } while $self->match('comma');
            }
            $self->consume('close_paren', 'Expected )');
            $expression = node('CallExpr', callee => $expression, arguments => \@arguments, %position);
        }
        elsif ($self->match('open_bracket')) {
            my $index = $self->parse_expression;
            $self->consume('close_bracket', 'Expected ]');
            $expression = node('IndexExpr', array => $expression, index => $index, %position);
        }
        elsif ($self->check('operator') && $self->current->{value} =~ /\A(?:\+\+|--)\z/) {
            my $operator = $self->advance->{value};
            $expression = node('UnaryExpr', operator => $operator, operand => $expression, prefix => 0, %position);
        }
        else { last }
    }
    return $expression;
}

sub parse_primary ($self) {
    my %position = $self->location;
    my $token = $self->current;
    my %literal = (number => 'NumberLiteral', string_literal => 'StringLiteral', char_literal => 'CharLiteral');
    if (my $kind = $literal{$token->{type}}) {
        $self->advance;
        return node($kind, value => $token->{value}, %position);
    }
    if ($token->{type} =~ /\A(?:identifier|other_keyword|builtin_keyword|control_keyword)\z/) {
        $self->advance;
        return node('Identifier', name => $token->{value}, %position);
    }
    if ($self->match('literal_keyword')) {
        return node('NumberLiteral', value => 0 + $token->{value}, %position) if $token->{value} =~ /\A[0-9]+\z/;
        return node('Identifier', name => $token->{value}, %position);
    }
    if ($self->match('open_paren')) {
        my $expression = $self->parse_expression;
        $self->consume('close_paren', 'Expected )');
        return $expression;
    }
    die Grongigo::ParseError->new('Unexpected token: ' . inspect($token->{value}, $token->{type})
        . " (type: $token->{type}) at line $token->{line}", $token);
}

1;
