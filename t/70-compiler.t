use v5.36;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use Grongigo::Compiler;

my $source = 'パザ ゲギグウ ゴロ バサ ザジレ ロゾス ゼゼソ ゴパシ';
my $compiler = Grongigo::Compiler->new;
like $compiler->compile($source), qr/\Ause v5\.36;.*sub main.*return 0;.*exit\(main\(\)\);/s, 'default Perl backend';
is_deeply $compiler->errors, [], 'no compilation errors';
is $compiler->compile('パザ ゲギグウ'), undef, 'invalid program';
like $compiler->errors->[0], qr/^Parse error: Expected identifier/, 'parse exception is classified';
ok defined($compiler->compile($source)), 'compiler is reusable';
is_deeply $compiler->errors, [], 'errors reset between compilations';
my $c_compiler = Grongigo::Compiler->new(target=>'c');
like $c_compiler->compile($source), qr/int main\(void\).*return 0;/s, 'explicit C backend';
is $c_compiler->compile('ジョウベン パパン'), undef, 'incomplete statement fails in C backend';
is $c_compiler->errors->[0], 'Error: Unknown statement type: NilClass', 'Ruby exception class name for missing body';
like Grongigo::Compiler->new(target=>'perl')->compile($source), qr/exit\(main\(\)\);/, 'explicit Perl backend';
my $invalid = Grongigo::Compiler->new(target=>'javascript');
is $invalid->compile($source), undef, 'unknown backend rejected';
like $invalid->errors->[0], qr/^Error: Unknown target/, 'clear backend error';

my $tmp = tempdir(CLEANUP=>1);
my $input = "$tmp/program.grg";
open my $fh, '>:encoding(UTF-8)', $input or die $!;
print $fh $source;
close $fh or die $!;
ok $compiler->compile_file($input), 'compile_file default path';
ok -f "$tmp/program.pl", 'default Perl extension';
ok !-e "$tmp/program.c", 'default compilation does not produce C';
ok $c_compiler->compile_file($input), 'compile_file explicit C target';
ok -f "$tmp/program.c", 'explicit C extension';
ok !$compiler->compile_file($input, $input), 'refuse to overwrite source';
like $compiler->errors->[0], qr/overwrite.*source/, 'source overwrite error';
ok !$compiler->compile_file("$tmp/missing.grg"), 'missing source';
like $compiler->errors->[0], qr/^Error:/, 'IO error collected';
my $bare = "$tmp/noextension";
open $fh, '>:encoding(UTF-8)', $bare or die $!;
print $fh $source;
close $fh;
ok $compiler->compile_file($bare), 'extensionless source';
ok -f "$bare.pl", 'extensionless output defaults to Perl and preserves source';

my @invalid_sources = (
    ['ASCII function name', 'パザ ゲギグウ main バサ ザジレ ロゾス ゼゼソ ゴパシ'],
    ['ASCII variable name', 'パザ ゲギグウ ゴロ バサ ザジレ ゲギグウ count ギセス パパン ロゾス ゼゼソ ゴパシ'],
    ['mixed Katakana and ASCII name', 'パザ ゲギグウ ゴロ バサ ザジレ ゲギグウ バx ギセス パパン ロゾス ゼゼソ ゴパシ'],
    ['decimal integer', 'パザ ゲギグウ ゴロ バサ ザジレ ロゾス 1 ゴパシ'],
    ['decimal fraction', 'パザ ゲギグウ ゴロ バサ ザジレ ロゾス 1.5 ゴパシ'],
    ['ASCII comma', 'パザ ゲギグウ ゴロ バサ ザジレ ジョウジ ジサビバッボジサビロジセヅ%dドジロジセヅ, パパン ドジバッボ ロゾス ゼゼソ ゴパシ'],
    ['dollar sigil', 'パザ ゲギグウ ゴロ バサ ザジレ ゲギグウ $バ ギセス パパン ロゾス ゼゼソ ゴパシ'],
);
for my $target (qw(perl c)) {
    my $strict = Grongigo::Compiler->new(target=>$target);
    for my $case (@invalid_sources) {
        is $strict->compile($case->[1]), undef, "$target rejects $case->[0]";
        like $strict->errors->[0] // '', qr/^Parse error:/, "$case->[0] fails as source syntax";
    }
    my $payload_source = <<'GRONGIGO';
ゴゴ ASCII comment 123, : $
ゴビ ASCII block comment 456, : $ ビゴ
パザ ゲギグウ ゴロ バサ ザジレ
  ゲギグウ バ ギセス パパン
  ロジ ダ ギセス ジサビジドロジaドジジドロジ
  ジョウジ ジサビバッボジサビロジセヅ%d ASCII 123, : $ドジロジセヅ、 バ ドジバッボ
  ロゾス ゼゼソ
ゴパシ
GRONGIGO
    my $code = $strict->compile($payload_source);
    ok defined($code), "$target accepts ASCII inside literal and comment payloads";
    like $code // '', qr/%d ASCII 123, :/, 'format text stays in generated code';
}
is $c_compiler->compile('パザ ゲギグウ ゴロ バサ ザジレ ゲンダブ パパン ザジレ ダガギ パパン: ブゲス ゴパシ ロゾス ゼゼソ ゴパシ'),
    undef, 'C target rejects ASCII colon';
like $c_compiler->errors->[0] // '', qr/^Parse error:/, 'ASCII colon fails before C generation';
done_testing;
