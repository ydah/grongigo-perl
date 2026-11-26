use v5.36;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::Copy qw(copy);
use FindBin;
use Encode qw(encode decode);

my $cli = "$FindBin::Bin/../bin/grongigo";
sub run (@args) {
    @args = map { utf8::is_utf8($_) ? encode('UTF-8', $_) : $_ } @args;
    open my $pipe, '-|', $^X, $cli, @args or die $!;
    my $text = do { local $/; <$pipe> } // '';
    close $pipe;
    return ($? >> 8, decode('UTF-8', $text));
}
my ($status, $text) = run('-n', 100);
is $status, 0, 'number command succeeds';
is $text, "100 (decimal) = バギングバギンドバギングドググドパパン (Grongigo)\n", 'number message';
($status, $text) = run('-c', 'こんにちは');
is $status, 0, 'Japanese conversion succeeds';
is $text, "ボンビヂザ\n", 'Japanese conversion';
($status, $text) = run('--segmentations', 'バギンドドググ');
is $text, "バギン ド ドググ = 11\nバギン ド ド グ グ = 無効\n", 'segmentation values';
($status, $text) = run('--segmentations', 'ドググシギ');
is $text, "ド グ グシギ = 3\n", 'backtracking demo';
my $tmp = tempdir(CLEANUP=>1);
($status, $text) = run('-r', '-o', "$tmp/hello with spaces.pl", "$FindBin::Bin/../examples/hello.grg");
is $status, 0, 'default Perl target runs with spaces in output path';
like $text, qr/Successfully compiled:.*\n\n=== Running program ===\nリントンボドバゼ\n/s, 'successful compilation and run messages';
($status, $text) = run('--target', 'c', '-v', '-t', '-a', '-o', "$tmp/test.c", "$FindBin::Bin/../examples/hello.grg");
is $status, 0, 'verbose C compilation';
like $text, qr/\[Grongigo\] Starting lexical analysis.*=== Tokens ===.*=== AST ===.*Generating C code.*Compilation successful.*Output written to:/s, 'Ruby verbose messages and dump sections';
my $default_input = "$tmp/default.grg";
copy "$FindBin::Bin/../examples/hello.grg", $default_input or die $!;
($status, $text) = run($default_input);
is $status, 0, 'compile with target and output omitted';
is $text, "Successfully compiled: $default_input -> $tmp/default.pl\n", 'default output path is Perl';
ok -f "$tmp/default.pl", 'default CLI writes a Perl file';
ok !-e "$tmp/default.c", 'default CLI does not write a C file';
if (open my $generated, '<:encoding(UTF-8)', "$tmp/default.pl") {
    my $code = do { local $/; <$generated> };
    close $generated;
    like $code, qr/\Ause v5\.36;.*exit\(main\(\)\);/s, 'default output contains executable Perl';
}
else {
    fail 'default output contains executable Perl';
}
($status, $text) = run("$FindBin::Bin/corpus/edge-semicolon.grg");
is $status, 1, 'compilation failure exit code';
is $text, "Compilation failed:\n  Parse error: Unexpected token: \";\" (type: semicolon) at line 3\n", 'compilation error text';
ok !-e "$FindBin::Bin/corpus/edge-semicolon.c", 'failed compilation writes no output';
ok !-e "$FindBin::Bin/corpus/edge-semicolon.pl", 'failed default compilation writes no Perl output';
($status, $text) = run('--target', 'javascript', "$FindBin::Bin/../examples/hello.grg");
is $status, 1, 'invalid target exits nonzero';
like $text, qr/Unknown target/, 'invalid target message';
($status, $text) = run('-n', 'potato');
is $status, 1, 'invalid number exits nonzero';
($status, $text) = run('--help');
is $status, 0, 'help';
like $text, qr/--target.*--segmentations/s, 'help documents additional options';
like $text, qr/--target[^\n]*default: perl/, 'help documents Perl as the default target';
my $unicode_input = "$tmp/日本語.grg";
my $unicode_output = "$tmp/結果.pl";
open my $fh, '>:encoding(UTF-8)', $unicode_input or die $!;
print $fh 'パザ ゲギグウ ゴロ バサ ザジレ ロゾス ゼゼソ ゴパシ';
close $fh;
($status, $text) = run('--target', 'perl', '-r', '-o', $unicode_output, $unicode_input);
is $status, 0, 'Unicode filenames compile and run';
is $text, "Successfully compiled: $unicode_input -> $unicode_output\n\n=== Running program ===\n", 'UTF-8 filename messages match Ruby';
my $invalid_input = "$tmp/ascii.grg";
open my $invalid_fh, '>:encoding(UTF-8)', $invalid_input or die $!;
print $invalid_fh 'パザ ゲギグウ ゴロ バサ ザジレ ゲギグウ count ギセス パパン ロゾス ゼゼソ ゴパシ';
close $invalid_fh or die $!;
($status, $text) = run($invalid_input);
is $status, 1, 'CLI rejects an ASCII variable name in source';
like $text, qr/^Compilation failed:\n  Parse error:/, 'CLI reports invalid source syntax';
ok !-e "$tmp/ascii.pl", 'invalid ASCII source produces no output';
done_testing;
