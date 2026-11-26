use v5.36;
use utf8;
use Test::More;
binmode Test::More->builder->output, ':encoding(UTF-8)';
binmode Test::More->builder->failure_output, ':encoding(UTF-8)';
use Grongigo::Lexer;
use Grongigo::Inspect qw(inspect token_inspect);

sub pairs ($source) {
    return [map { [$_->{type}, $_->{value}] }
        grep { $_->{type} ne 'eof' } @{ Grongigo::Lexer->new($source)->tokenize }];
}

for my $case (
    ['ゲギグウ バサ', 'type_keyword', [qw(int void)]],
    ['ジョウベン ゾバ ガギザ', 'control_keyword', [qw(if else while)]],
    ['ジョウジ ジョリドシ グンモウ', 'builtin_keyword', [qw(printf scanf sizeof)]],
    ['ギン ビゲ ルヂ', 'literal_keyword', [qw(1 0 NULL)]],
    ['ゴロ パザ', 'other_keyword', ['main', 'パザ']],
    ['ダグ ジブ バゲス パス ガラシ', 'operator', [qw(+ - * / %)]],
    ['ジドギギ ジドギグバギ ギョウバシ ザギバシ ギバ ギジョウ', 'operator', [qw(== != < > <= >=)]],
    ['ギセス バヅ ラダパ ジデギ ガンド ゴガ ダグダグ ジブジブ', 'operator', [qw(= && || ! & | ++ --)]],
    ['ゼゼソ パパン ドググ バギンドパパン', 'number', [0, 1, 2, 10]],
    ['ヘンスウ', 'identifier', ['ヘンスウ']],
) {
    is_deeply pairs($case->[0]), [map { [$case->[1], $_] } @{$case->[2]}], $case->[0];
}

is_deeply pairs('ガ、ダ。ゲギグウ：'), [
    [identifier => 'ガ'], [comma => ','], [identifier => 'ダ'],
    [semicolon => ';'], [type_keyword => 'int'], [colon => ':'],
], 'Japanese punctuation does not belong to Katakana words';
is_deeply pairs('ザジレ ゴパシ ジサビバッボ ドジバッボ ジサビバブバッボ ドジバブバッボ'), [
    [open_brace => '{'], [close_brace => '}'], [open_paren => '('],
    [close_paren => ')'], [open_bracket => '['], [close_bracket => ']'],
], 'all syntax delimiters';
is_deeply pairs('ジョウジジサビバッボジサビロジセヅゼソドジロジセヅドジバッボ'), [
    [builtin_keyword => 'printf'], [open_paren => '('],
    [string_literal => 'ゼソ'], [close_paren => ')'],
], 'reserved words split before delimiters';
is_deeply pairs('ギジサビバッボ ザジレイ ゲギグウザジレ'), [
    [identifier => 'ギジサビバッボ'], [open_brace => '{'], [identifier => 'イ'],
    [type_keyword => 'int'], [open_brace => '{'],
], 'preserve Ruby glued identifier behavior';
is_deeply pairs('ジサビジドロジガドジジドロジ ジサビロジセヅabc'), [
    [char_literal => 'ガ'], [string_literal => 'abc'],
], 'characters and unterminated strings';
is_deeply pairs("ゲギグウ ゴゴ comment\nゴビ comment\nビゴ バサ"),
    [[type_keyword => 'int'], [type_keyword => 'void']], 'skip both comment forms';
is_deeply pairs('ゲギグウ ゴビン ギセス パパン'), [[type_keyword => 'int']], 'comment prefixes consume until EOF';
for my $source ('foo', 'main', 'printf', '123', '1.5', '0.00001', '$', ',', ':') {
    is Grongigo::Lexer->new($source)->tokenize->[0]{type}, 'unknown', "non-Grongigo code is not recognized: $source";
}
is_deeply pairs('ジサビロジセヅfoo $bar 123 , :ドジロジセヅ ジサビジドロジAドジジドロジ'),
    [[string_literal=>'foo $bar 123 , :'], [char_literal=>'A']], 'literal payloads may contain non-Katakana characters';
is_deeply pairs('ーガ ・ @'), [[unknown => 'ー'], [identifier => 'ガ'], [unknown => '・'], [unknown => '@']], 'only Script Katakana starts a word';
{
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    my $unknown = Grongigo::Lexer->new('ーガ @')->tokenize;
    is_deeply [map { $_->{column} } @$unknown], [1,2,4,5], 'unknown token positions advance once';
    is_deeply \@warnings, [], 'no warnings while consuming unknown tokens';
}
my $tokens = Grongigo::Lexer->new("ガ、\n\tバサ")->tokenize;
is_deeply [map { [$_->{line}, $_->{column}] } @$tokens], [[1,1],[1,2],[2,2],[2,4]], 'character positions including EOF';
is_deeply Grongigo::Lexer->new('')->tokenize, [{type=>'eof',value=>undef,line=>1,column=>1}], 'empty source';
is_deeply pairs("  \t\r\n"), [], 'whitespace source';
is token_inspect(Grongigo::Lexer->new('ギン')->tokenize->[0]), 'Token(literal_keyword, "1", L1:1)', 'literal keyword stays quoted';
is inspect(undef), 'nil', 'Ruby nil';
is inspect(1, 'number'), '1', 'numeric token';
is inspect('1'), '"1"', 'numeric-looking string';
is inspect("\\\"\n\t\r"), '"\\\\\\"\\n\\t\\r"', 'Ruby string escaping';
is inspect('#{x} #$x #@x #x'), '"\\#{x} \\#$x \\#@x #x"', 'Ruby interpolation prefixes';
is inspect("\x{2028}\x{2029}"), '"\\u2028\\u2029"', 'Ruby escapes Unicode line and paragraph separators';
is inspect("\x{0378}\x{ffff}\x{10ffff}"), '"\\u0378\\uFFFF\\u{10FFFF}"', 'Ruby escapes unassigned and noncharacter codepoints';
done_testing;
