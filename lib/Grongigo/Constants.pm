package Grongigo::Constants;
use v5.36;
use utf8;
use Exporter 'import';

our @EXPORT_OK = qw(
    %DIGITS
    %NUMBER_OPS
    %TYPE_KEYWORDS
    %CONTROL_KEYWORDS
    %BUILTIN_KEYWORDS
    %LITERAL_KEYWORDS
    %OTHER_KEYWORDS
    %OPERATORS
    %JAPANESE_TO_GRONGIGO
    %SYNTAX
    %KEYWORD
    @RESERVED_GROUPS
    @PROPER_NOUNS
    $STRING_OPEN
    $STRING_CLOSE
    $CHAR_OPEN
    $CHAR_CLOSE
);

our %DIGITS = (
    'ゼゼソ' => 0,
    'パパン' => 1,
    'ドググ' => 2,
    'グシギ' => 3,
    'ズゴゴ' => 4,
    'ズガギ' => 5,
    'ギブグ' => 6,
    'ゲズン' => 7,
    'ゲギド' => 8,
    'バギン' => 9,
);

our %NUMBER_OPS = (
    'ド' => 'add',
    'グ' => 'multiply',
);

our %TYPE_KEYWORDS = (
    'ゲギグウ' => 'int',
    'ロジ' => 'char',
    'ズゾウ' => 'float',
    'ザダダス' => 'double',
    'バサ' => 'void',
    'バゴ' => 'long',
    'ジジバギ' => 'short',
    'ブゾウ' => 'unsigned',
);

our %CONTROL_KEYWORDS = (
    'ジョウベン' => 'if',
    'ゾバ' => 'else',
    'ガギザ' => 'while',
    'ブシバゲギ' => 'for',
    'ロゾス' => 'return',
    'ブゲス' => 'break',
    'ヅヅゲス' => 'continue',
    'ゲンダブ' => 'switch',
    'ダガギ' => 'case',
    'ビデギ' => 'default',
);

our %BUILTIN_KEYWORDS = (
    'ジョウジ' => 'printf',
    'ジョリドシ' => 'scanf',
    'グンモウ' => 'sizeof',
);

our %LITERAL_KEYWORDS = (
    'ギン' => '1',
    'ビゲ' => '0',
    'ルヂ' => 'NULL',
);

our %OTHER_KEYWORDS = (
    'ボウゾウ' => 'struct',
    'バダデギギ' => 'typedef',
    'ゴロ' => 'main',
    'パザ' => 'パザ',
    'ザジレ' => '{',
    'ゴパシ' => '}',
);

our %OPERATORS = (
    'ダグ' => '+',
    'ジブ' => '-',
    'バゲス' => '*',
    'パス' => '/',
    'ガラシ' => '%',
    'ギセス' => '=',
    'ジドギギ' => '==',
    'ジドギグバギ' => '!=',
    'ギョウバシ' => '<',
    'ザギバシ' => '>',
    'ギバ' => '<=',
    'ギジョウ' => '>=',
    'バヅ' => '&&',
    'ラダパ' => '||',
    'ジデギ' => '!',
    'ガンド' => '&',
    'ゴガ' => '|',
    'ダグダグ' => '++',
    'ジブジブ' => '--',
);

our %JAPANESE_TO_GRONGIGO = (
    'あ' => 'ガ',
    'い' => 'ギ',
    'う' => 'グ',
    'え' => 'ゲ',
    'お' => 'ゴ',
    'か' => 'バ',
    'き' => 'ビ',
    'く' => 'ブ',
    'け' => 'ベ',
    'こ' => 'ボ',
    'さ' => 'ガ',
    'し' => 'ギ',
    'す' => 'グ',
    'せ' => 'ゲ',
    'そ' => 'ゴ',
    'た' => 'ダ',
    'ち' => 'ヂ',
    'つ' => 'ヅ',
    'て' => 'デ',
    'と' => 'ド',
    'な' => 'バ',
    'に' => 'ビ',
    'ぬ' => 'ブ',
    'ね' => 'ベ',
    'の' => 'ボ',
    'は' => 'ザ',
    'ひ' => 'ジ',
    'ふ' => 'ズ',
    'へ' => 'ゼ',
    'ほ' => 'ゾ',
    'ま' => 'ラ',
    'み' => 'リ',
    'む' => 'ル',
    'め' => 'レ',
    'も' => 'ロ',
    'や' => 'ジャ',
    'ゆ' => 'ジュ',
    'よ' => 'ジョ',
    'ら' => 'サ',
    'り' => 'シ',
    'る' => 'ス',
    'れ' => 'セ',
    'ろ' => 'ソ',
    'わ' => 'パ',
    'が' => 'ガ',
    'ぎ' => 'ギ',
    'ぐ' => 'グ',
    'げ' => 'ゲ',
    'ご' => 'ゴ',
    'ざ' => 'ザ',
    'じ' => 'ジ',
    'ず' => 'ズ',
    'ぜ' => 'ゼ',
    'ぞ' => 'ゾ',
    'だ' => 'ザ',
    'ぢ' => 'ジ',
    'づ' => 'ズ',
    'で' => 'ゼ',
    'ど' => 'ゾ',
    'ば' => 'ダ',
    'び' => 'ヂ',
    'ぶ' => 'ヅ',
    'べ' => 'デ',
    'ぼ' => 'ド',
    'ぱ' => 'マ',
    'ぴ' => 'ミ',
    'ぷ' => 'ム',
    'ぺ' => 'メ',
    'ぽ' => 'モ',
    'が' => 'グ',
    'の' => 'ン',
    'は' => 'パ',
    'を' => 'ゾ',
);

our @PROPER_NOUNS = qw(クウガ リント ゲゲル グロンギ グセパ バグンダダ ゲリザギバスゲゲル ザギバスゲゲル);
our $STRING_OPEN = 'ジサビロジセヅ';
our $STRING_CLOSE = 'ドジロジセヅ';
our $CHAR_OPEN = 'ジサビジドロジ';
our $CHAR_CLOSE = 'ドジジドロジ';
our %SYNTAX = (
    'ジサビバッボ' => [open_paren => '('],
    'ドジバッボ' => [close_paren => ')'],
    'ジサビバブバッボ' => [open_bracket => '['],
    'ドジバブバッボ' => [close_bracket => ']'],
    'ザジレ' => [open_brace => '{'],
    'ゴパシ' => [close_brace => '}'],
);
our @RESERVED_GROUPS = (
    [type_keyword => \%TYPE_KEYWORDS],
    [control_keyword => \%CONTROL_KEYWORDS],
    [builtin_keyword => \%BUILTIN_KEYWORDS],
    [literal_keyword => \%LITERAL_KEYWORDS],
    [other_keyword => \%OTHER_KEYWORDS],
    [operator => \%OPERATORS],
);
our %KEYWORD;
for my $group (reverse @RESERVED_GROUPS) {
    $KEYWORD{$_} = [$group->[0], $group->[1]{$_}] for keys %{$group->[1]};
}

1;
