use v5.36;
use Test::More;
use FindBin;
use Encode qw(decode);
use Grongigo::Compiler;

my @goldens = glob "$FindBin::Bin/golden/*.txt";
is scalar(@goldens), 14, 'all pinned Ruby fixtures are present';
for my $golden (@goldens) {
    (my $name = $golden) =~ s{.*/([^/]+)\.txt\z}{$1};
    my $source_path = "$FindBin::Bin/../examples/$name.grg";
    $source_path = "$FindBin::Bin/corpus/$name.grg" unless -f $source_path;
    open my $fh, '<:encoding(UTF-8)', $source_path or die "$source_path: $!";
    my $source = do { local $/; <$fh> };
    open my $expected_fh, '<:encoding(UTF-8)', $golden or die "$golden: $!";
    my $expected = do { local $/; <$expected_fh> };
    my $actual = '';
    {
        local *STDOUT;
        open STDOUT, '>:encoding(UTF-8)', \$actual or die $!;
        my $compiler = Grongigo::Compiler->new(target=>'c', output_tokens=>1, output_ast=>1);
        my $code = $compiler->compile($source);
        if (defined $code) { print "=== C ===\n", $code }
        else { print "=== Errors ===\n", map { "$_\n" } @{$compiler->errors} }
    }
    is decode('UTF-8', $actual), $expected, "$name matches pinned Ruby output";
}
done_testing;
