package Grongigo::Lexer;
use v5.36;
use utf8;
use Grongigo::Constants qw(%SYNTAX %KEYWORD @RESERVED_GROUPS $STRING_OPEN $STRING_CLOSE $CHAR_OPEN $CHAR_CLOSE);
use Grongigo::Number qw(parse);

sub alt (@words) { join '|', map { quotemeta } sort { length($b) <=> length($a) } @words }
my $KANA = qr/[\p{Script=Katakana}ー]/;
my $SYN = alt(keys %SYNTAX);
my $DELIM = qr/(?:$SYN|\Q$STRING_OPEN\E|\Q$CHAR_OPEN\E)/;
my $RESERVED = join '|', map { alt(keys %{$_->[1]}) } @RESERVED_GROUPS;
my $EXACT = alt(keys %KEYWORD);

sub new ($class, $source) { bless {source => $source}, $class }

sub advance_position ($text, $line, $column) {
    for my $char (split //, $text) {
        if ($char eq "\n") { $$line++; $$column = 1 }
        else { $$column++ }
    }
}

sub tokenize ($self) {
    my $src = $self->{source};
    pos($src) = 0;
    my ($line, $column) = (1, 1);
    my @tokens;
    while (1) {
        while ($src =~ /\G(?:[ \t\r\n]+|ゴゴ[^\n]*|ゴビ.*?(?:ビゴ|\z))/gcs) {
            advance_position(substr($src, $-[0], $+[0] - $-[0]), \$line, \$column);
        }
        last if pos($src) >= length $src;
        my $start = pos($src);
        my ($start_line, $start_column) = ($line, $column);
        my ($type, $value);
        if ($src =~ /\G\Q$STRING_OPEN\E(.*?)(?:\Q$STRING_CLOSE\E|\z)/gcs) {
            ($type, $value) = (string_literal => $1);
        }
        elsif ($src =~ /\G\Q$CHAR_OPEN\E(.*?)(?:\Q$CHAR_CLOSE\E|\z)/gcs) {
            ($type, $value) = (char_literal => $1);
        }
        elsif ($src =~ /\G、/gc) { ($type, $value) = (comma => ',') }
        elsif ($src =~ /\G。/gc) { ($type, $value) = (semicolon => ';') }
        elsif ($src =~ /\G：/gc) { ($type, $value) = (colon => ':') }
        elsif ($src =~ /\G($SYN)/gc) { ($type, $value) = @{$SYNTAX{$1}} }
        elsif ($src =~ /\G($RESERVED)(?=$DELIM)/gc) { ($type, $value) = @{$KEYWORD{$1}} }
        elsif ($src =~ /\G($EXACT)(?!$KANA)/gc) { ($type, $value) = @{$KEYWORD{$1}} }
        elsif ($src =~ /\G(\p{Script=Katakana}$KANA*)/gc) {
            my $word = $1;
            $value = parse($word);
            ($type, $value) = defined($value) ? (number => $value) : (identifier => $word);
        }
        else { $src =~ /\G(.)/gcs; ($type, $value) = (unknown => $1) }
        advance_position(substr($src, $start, pos($src) - $start), \$line, \$column);
        push @tokens, {type=>$type, value=>$value, line=>$start_line, column=>$start_column};
    }
    push @tokens, {type=>'eof', value=>undef, line=>$line, column=>$column};
    return \@tokens;
}

1;
