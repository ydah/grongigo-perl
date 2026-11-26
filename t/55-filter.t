use v5.36;
use utf8;
use Test::More;
use File::Temp qw(tempfile);
use IPC::Open3;
use Symbol qw(gensym);
use FindBin;

binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

sub run_filter ($source) {
    my ($fh, $path) = tempfile(SUFFIX => '.pl', UNLINK => 1);
    binmode $fh, ':encoding(UTF-8)';
    print {$fh} "use Grongigo;\n$source";
    close $fh or die "$path: $!";
    my $err = gensym;
    my $pid = open3(my $input, my $output, $err, $^X, "-I$FindBin::Bin/../lib", $path);
    close $input;
    binmode $output, ':encoding(UTF-8)';
    binmode $err, ':encoding(UTF-8)';
    my $stdout = do { local $/; <$output> } // '';
    my $stderr = do { local $/; <$err> } // '';
    waitpid $pid, 0;
    return [$stdout, $stderr, $? >> 8];
}

is_deeply run_filter(<<'GRG'), ["リントンボドバゼ\n", '', 0], 'UTF-8 source filter runs hello world';
パザ ゲギグウ ゴロ バサ
ザジレ
  ジョウジ ジサビバッボジサビロジセヅリントンボドバゼドジロジセヅドジバッボ
  ロゾス ゼゼソ
ゴパシ
GRG

is_deeply run_filter(<<'GRG'), ["120\n", '', 0], 'filtered code keeps Japanese subroutine and parameter names';
パザ ゲギグウ バギジョウシギャス ゲギグウ バ
ザジレ
  ジョウベン バ ギバ パパン ロゾス パパン
  ロゾス バ バゲス バギジョウシギャス ジサビバッボ バ ジブ パパン ドジバッボ
ゴパシ
パザ ゲギグウ ゴロ バサ
ザジレ
  ジョウジ ジサビバッボジサビロジセヅ%dドジロジセヅ、 バギジョウシギャス ジサビバッボ ズガギ ドジバッボ ドジバッボ
  ロゾス ゼゼソ
ゴパシ
GRG

my $bad = run_filter("パザ ゲギグウ ゴロ バサ ザジレ ロゾス パパン。 ゴパシ\n");
is $bad->[0], '', 'bad source produces no program output';
isnt $bad->[2], 0, 'syntax failure exits unsuccessfully';
like $bad->[1], qr/Grongigo: compilation failed\nParse error:/, 'syntax failure preserves compiler diagnostic';

my $unsupported = run_filter("パザ ゲギグウ ゴロ バサ ザジレ ズゾウ ガ ロゾス ゼゼソ ゴパシ\n");
isnt $unsupported->[2], 0, 'unsupported backend syntax exits unsuccessfully';
like $unsupported->[1], qr/Perl backend does not support/, 'backend diagnostic reaches source filter';

my $raw_perl = run_filter("no Grongigo;\nBEGIN { print q(FILTER_NO_BYPASS); }\n");
is $raw_perl->[0], '', 'no Grongigo cannot expose a raw Perl BEGIN block';
isnt $raw_perl->[2], 0, 'raw Perl after no Grongigo is rejected';
like $raw_perl->[1], qr/Grongigo: compilation failed\nParse error:/,
    'raw Perl is diagnosed as invalid Grongigo source';

my $main = "パザ ゲギグウ ゴロ バサ ザジレ ロゾス ゼゼソ ゴパシ\n";
for my $marker ('__END__', '__DATA__') {
    my $result = run_filter($main . "$marker\n");
    isnt $result->[2], 0, "$marker outside literal data is rejected";
    like $result->[1], qr/Grongigo: compilation failed\nParse error:/,
        "$marker reaches Grongigo parsing";
    is $result->[0], '', "$marker produces no program output";
}

for my $marker ('no Grongigo;', '__END__', '__DATA__') {
    my $literal_source = <<"GRG";
パザ ゲギグウ ゴロ バサ ザジレ
  ジョウジ ジサビバッボジサビロジセヅ%sドジロジセヅ、
    ジサビロジセヅ
$marker
ドジロジセヅ ドジバッボ
  ロゾス ゼゼソ
ゴパシ
GRG
    is_deeply run_filter($literal_source), ["\n$marker\n\n", '', 0],
        "$marker inside a multiline string remains data";
    is_deeply run_filter("ゴビ\n$marker\nビゴ\n" . $main), ['', '', 0],
        "$marker inside a block comment remains data";
}

done_testing;
