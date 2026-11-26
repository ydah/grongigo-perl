#!/usr/bin/env perl
use v5.36;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Grongigo::Compiler;

binmode STDOUT, ':encoding(UTF-8)';
open my $fh, '<:encoding(UTF-8)', $ARGV[0] or die "$ARGV[0]: $!";
my $source = do { local $/; <$fh> };
my $compiler = Grongigo::Compiler->new(target=>'c', output_tokens=>1, output_ast=>1);
my $code = $compiler->compile($source);
if (defined $code) { say '=== C ==='; print $code }
else { say '=== Errors ==='; say for @{$compiler->errors} }
