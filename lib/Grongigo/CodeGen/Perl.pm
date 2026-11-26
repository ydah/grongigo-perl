package Grongigo::CodeGen::Perl;
use v5.36;
use utf8;
use B qw(perlstring);

my %PERL_KEYWORD = map { $_ => 1 } qw(
    __FILE__ __LINE__ __PACKAGE__ __DATA__ __END__ __SUB__
    ADJUST AUTOLOAD BEGIN UNITCHECK DESTROY END INIT CHECK
    abs accept alarm and atan2 bind binmode bless break caller catch chdir chmod
    chomp chop chown chr chroot class close closedir cmp connect continue cos crypt
    dbmclose dbmopen default defer defined delete die do dump each else elsif
    endgrent endhostent endnetent endprotoent endpwent endservent eof eq eval
    evalbytes exec exists exit exp fc fcntl field fileno finally flock for foreach
    fork format formline ge getc getgrent getgrgid getgrnam gethostbyaddr
    gethostbyname gethostent getlogin getnetbyaddr getnetbyname getnetent getpeername
    getpgrp getppid getpriority getprotobyname getprotobynumber getprotoent getpwent
    getpwnam getpwuid getservbyname getservbyport getservent getsockname getsockopt
    given glob gmtime goto grep gt hex if index int ioctl isa join keys kill last
    lc lcfirst le length link listen local localtime lock log lstat lt m map method
    mkdir msgctl msgget msgrcv msgsnd my ne next no not oct open opendir or ord our
    pack package pipe pop pos print printf prototype push q qq qr quotemeta qw qx
    rand read readdir readline readlink readpipe recv redo ref rename require reset
    return reverse rewinddir rindex rmdir s say scalar seek seekdir select semctl
    semget semop send setgrent sethostent setnetent setpgrp setpriority setprotoent
    setpwent setservent setsockopt shift shmctl shmget shmread shmwrite shutdown sin
    sleep socket socketpair sort splice split sprintf sqrt srand stat state study
    sub substr symlink syscall sysopen sysread sysseek system syswrite tell telldir
    tie tied time times tr try truncate uc ucfirst umask undef unless unlink unpack
    unshift untie until use utime values vec wait waitpid wantarray warn when while
    write x xor y
);

sub new ($class) { bless {}, $class }
sub kind ($node) { (ref($node) =~ /::([^:]+)\z/)[0] // '' }
sub unsupported ($feature) { die "Perl backend does not support $feature\n" }

sub generate ($self, $ast) {
    $self->{output} = [
        'use v5.36;', 'use utf8;', 'use integer;',
        "binmode STDOUT, ':encoding(UTF-8)';", '',
    ];
    $self->{indent} = 0;
    for my $decl (@{ $ast->{declarations} }) {
        $self->statement($decl);
        $self->emit('');
    }
    $self->emit('exit(main());');
    return join("\n", @{ $self->{output} }) . "\n";
}

sub emit ($self, $code) { push @{ $self->{output} }, ('    ' x $self->{indent}) . $code }

sub check_type ($type) {
    unsupported('arrays') if $type =~ /\[/;
    unsupported("type $type") if $type eq 'float' || $type eq 'double';
}

sub check_function_name ($name, $builtin_call = 0) {
    return if $builtin_call && $name eq 'printf';
    unsupported("function $name") if $PERL_KEYWORD{$name} || $name eq 'scanf' || $name eq 'sizeof';
}

sub variable ($node) {
    check_type($node->{type});
    return 'my $' . $node->{name} . ' = ';
}

sub body ($self, $node) {
    $self->emit('{');
    $self->{indent}++;
    if (kind($node) eq 'BlockStmt') {
        $self->statement($_) for @{ $node->{statements} };
    }
    else {
        $self->statement($node);
    }
    $self->{indent}--;
    $self->emit('}');
}

my %STATEMENT = (
    FunctionDecl => sub ($self, $node) {
        check_type($node->{return_type});
        check_function_name($node->{name});
        my @params;
        for my $param (@{ $node->{params} }) {
            check_type($param->{type});
            push @params, '$' . $param->{name};
        }
        $self->emit("sub $node->{name} (" . join(', ', @params) . ')');
        $self->body($node->{body});
    },
    BlockStmt => sub ($self, $node) { $self->body($node) },
    VarDecl => sub ($self, $node) { $self->emit($self->var_decl($node) . ';') },
    IfStmt => sub ($self, $node) { $self->if_stmt($node) },
    WhileStmt => sub ($self, $node) {
        $self->emit('while (' . $self->expression($node->{condition}) . ')');
        $self->body($node->{body});
    },
    ForStmt => sub ($self, $node) {
        my $init = !defined($node->{init}) ? '' : kind($node->{init}) eq 'VarDecl'
            ? $self->var_decl($node->{init}) : $self->expression($node->{init});
        my $condition = defined($node->{condition}) ? $self->expression($node->{condition}) : '';
        my $update = defined($node->{update}) ? $self->expression($node->{update}) : '';
        $self->emit("for ($init; $condition; $update)");
        $self->body($node->{body});
    },
    ReturnStmt => sub ($self, $node) {
        $self->emit(defined($node->{value}) ? 'return ' . $self->expression($node->{value}) . ';' : 'return;');
    },
    BreakStmt => sub ($self, $node) { $self->emit('last;') },
    ContinueStmt => sub ($self, $node) { $self->emit('next;') },
    ExprStmt => sub ($self, $node) { $self->emit($self->expression($node->{expression}) . ';') },
);

sub statement ($self, $node) {
    my $handler = $STATEMENT{kind($node)} // unsupported(ref($node));
    $handler->($self, $node);
}

sub var_decl ($self, $node) {
    return variable($node) . (defined($node->{initializer}) ? $self->expression($node->{initializer}) : '0');
}

sub if_stmt ($self, $node, $keyword = 'if') {
    $self->emit("$keyword (" . $self->expression($node->{condition}) . ')');
    $self->body($node->{then_branch});
    return unless defined $node->{else_branch};
    if (kind($node->{else_branch}) eq 'IfStmt') {
        $self->if_stmt($node->{else_branch}, 'elsif');
        return;
    }
    $self->emit('else');
    $self->body($node->{else_branch});
}

my %STRING_ESCAPE = (
    a=>"\a", b=>"\x08", e=>"\e", f=>"\f", n=>"\n", r=>"\r", t=>"\t", v=>"\x0b",
    '\\'=>'\\', '"'=>'"', "'"=>"'", '?'=>'?',
);

sub string_literal ($value) {
    $value =~ s/\\([abefnrtv\\'"?]|[0-3][0-7]{2}|[0-7]{1,2}(?![0-7])|x0*[0-9a-fA-F]{1,2}(?![0-9a-fA-F]))/
        exists($STRING_ESCAPE{$1}) ? $STRING_ESCAPE{$1} : chr(oct("0$1"))/ge;
    return perlstring($value);
}

my %EXPRESSION = (
    Identifier => sub ($self, $node) { $node->{name} eq 'NULL' ? 'undef' : '$' . $node->{name} },
    NumberLiteral => sub ($self, $node) { "$node->{value}" },
    StringLiteral => sub ($self, $node) { string_literal($node->{value}) },
    CharLiteral => sub ($self, $node) {
        return '0' unless length $node->{value};
        my $char = substr($node->{value}, 0, 1);
        $char =~ s/([\\'])/\\$1/g;
        return "ord('$char')";
    },
    BinaryExpr => sub ($self, $node) {
        my $expression = '(' . $self->expression($node->{left}) . " $node->{operator} "
            . $self->expression($node->{right}) . ')';
        return $node->{operator} =~ /\A(?:&&|\|\||==|!=|<|>|<=|>=)\z/
            ? "($expression ? 1 : 0)" : $expression;
    },
    UnaryExpr => sub ($self, $node) {
        my $operand = $self->expression($node->{operand});
        return "($operand ? 0 : 1)" if $node->{operator} eq '!';
        return $node->{prefix} ? "($node->{operator}$operand)" : "($operand$node->{operator})";
    },
    AssignExpr => sub ($self, $node) {
        return '(' . $self->expression($node->{target}) . ' = ' . $self->expression($node->{value}) . ')';
    },
    CallExpr => sub ($self, $node) { $self->call($node) },
);

sub expression ($self, $node) {
    my $handler = $EXPRESSION{kind($node)} // unsupported(ref($node));
    return $handler->($self, $node);
}

sub call ($self, $node) {
    unsupported('calls through expressions') unless kind($node->{callee}) eq 'Identifier';
    my $name = $node->{callee}{name};
    $name = 'printf' if $name eq 'ジョウジ';
    unsupported("function $name") if $name eq 'ジョリドシ' || $name eq 'グンモウ';
    check_function_name($name, 1);
    my @args = @{ $node->{arguments} };
    my @code;
    if ($name eq 'printf' && @args && kind($args[0]) eq 'StringLiteral') {
        my $value = shift(@args)->{value};
        $value .= '\\n' unless $value =~ /(?:\\n|\n)\z/;
        push @code, string_literal($value);
    }
    push @code, $self->expression($_) for @args;
    return "$name(" . join(', ', @code) . ')';
}

1;
