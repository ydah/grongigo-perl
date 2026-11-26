package Grongigo;
use v5.36;
use Filter::Simple;
use Grongigo::Compiler;

FILTER {
    my $source = $_;
    utf8::decode($source) or die "Grongigo: invalid UTF-8 source\n";
    my $compiler = Grongigo::Compiler->new(target => 'perl');
    my $code = $compiler->compile($source)
        // die join("\n", 'Grongigo: compilation failed', @{ $compiler->errors }) . "\n";
    $_ = $code;
} 0;

1;
