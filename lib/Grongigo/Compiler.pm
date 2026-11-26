package Grongigo::Compiler;
use v5.36;
use Encode qw(decode FB_CROAK);
use File::Basename qw(dirname);
use File::Spec;
use File::Temp qw(tempfile);
use Grongigo::Lexer;
use Grongigo::Parser;
use Grongigo::AST qw(print_ast);
use Grongigo::Inspect qw(token_inspect);
use Grongigo::CodeGen::C;
use Grongigo::CodeGen::Perl;

sub new ($class, %options) { bless {target=>'perl', %options, errors=>[]}, $class }
sub errors ($self) { $self->{errors} }
sub log ($self, $message) { say "[Grongigo] $message" if $self->{verbose} }

sub compile ($self, $source) {
    $self->{errors} = [];
    my $code = eval {
        $self->log('Starting lexical analysis...');
        my $tokens = Grongigo::Lexer->new($source)->tokenize;
        if ($self->{output_tokens}) {
            say '=== Tokens ===';
            say token_inspect($_) for @$tokens;
            say '';
        }
        $self->log('Starting parsing...');
        my $ast = Grongigo::Parser->new($tokens)->parse;
        if ($self->{output_ast}) {
            say '=== AST ===';
            print print_ast($ast);
            say '';
        }
        my $target = $self->{target};
        die "Unknown target: $target\n" unless $target eq 'c' || $target eq 'perl';
        $self->log($target eq 'c' ? 'Generating C code...' : 'Generating Perl code...');
        my $generator = $target eq 'c' ? Grongigo::CodeGen::C->new : Grongigo::CodeGen::Perl->new;
        my $result = $generator->generate($ast);
        $self->log('Compilation successful!');
        $result;
    };
    if (my $error = $@) {
        my $prefix = ref($error) && $error->isa('Grongigo::ParseError') ? 'Parse error: ' : 'Error: ';
        (my $message = "$error") =~ s/\n\z//;
        push @{$self->{errors}}, $prefix . $message;
        return undef;
    }
    return $code;
}

sub output_path ($self, $input) {
    my $extension = $self->{target} eq 'perl' ? 'pl' : 'c';
    return $input =~ s{(\.[^./]+)?\z}{.$extension}r;
}

sub compile_file ($self, $input, $output = undef) {
    $self->{errors} = [];
    $output //= $self->output_path($input);
    my $ok = eval {
        my @in_stat = stat $input;
        my @out_stat = stat $output;
        die "Refusing to overwrite the source file: $input\n"
            if File::Spec->rel2abs($input) eq File::Spec->rel2abs($output)
            || (@in_stat && @out_stat && $in_stat[0] == $out_stat[0] && $in_stat[1] == $out_stat[1]);
        open my $fh, '<:raw', $input or die "$input: $!\n";
        my $bytes = do { local $/; <$fh> };
        close $fh or die "$input: $!\n";
        my $source = decode('UTF-8', $bytes, FB_CROAK);
        my $code = $self->compile($source);
        if (defined $code) {
            my ($out, $temporary) = tempfile('.grongigo-XXXXXX', DIR=>dirname($output), UNLINK=>1);
            binmode $out, ':encoding(UTF-8)' or die "$output: $!\n";
            print $out $code or die "$output: $!\n";
            close $out or die "$output: $!\n";
            rename $temporary, $output or die "$output: $!\n";
            $self->log("Output written to: $output");
            1;
        }
        else { 0 }
    };
    if (my $error = $@) {
        chomp $error;
        push @{$self->{errors}}, "Error: $error";
        return 0;
    }
    return $ok;
}

1;
