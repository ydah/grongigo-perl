package Grongigo::Number;
use v5.36;
use utf8;
use Exporter 'import';
use Math::BigInt;
use Grongigo::Constants qw(%DIGITS);
our @EXPORT_OK = qw(parse evaluate segmentations to_grongigo);

my $DIGIT = join '|', map { quotemeta } sort { length($b) <=> length($a) } keys %DIGITS;

sub parse ($word) {
    my @parts = $word =~ /\G($DIGIT|ド|グ)/g;
    return undef unless @parts && length(join '', @parts) == length $word;
    return evaluate(\@parts);
}

sub evaluate ($parts) {
    return undef unless @$parts;
    my $result = Math::BigInt->new(0);
    my $product;
    for (my $i = 0; $i < @$parts; $i++) {
        my $part = $parts->[$i];
        if (exists $DIGITS{$part}) {
            return undef if defined $product;
            $product = Math::BigInt->new($DIGITS{$part});
        }
        elsif ($part eq 'グ') {
            my $next = $parts->[++$i];
            return undef unless defined($next) && exists $DIGITS{$next};
            $product //= Math::BigInt->new(1);
            $product->bmul($DIGITS{$next});
        }
        elsif ($part eq 'ド') {
            $result->badd($product) if defined $product;
            $product = undef;
        }
        else { return undef }
    }
    $result->badd($product) if defined $product;
    return $result->bstr;
}

our @SEG;
sub segmentations ($word) {
    local @SEG;
    my @found;
    $word =~ /\A(?:($DIGIT|ド|グ)(?{ local @SEG = (@SEG, $^N) }))+\z(?{ push @found, [@SEG] })(*FAIL)/;
    return @found;
}

sub to_grongigo ($number) {
    die "Expected an integer\n" unless "$number" =~ /\A-?[0-9]+\z/;
    my $n = Math::BigInt->new($number);
    return 'ゼゼソ' if $n->is_zero;
    my @digits = qw(ゼゼソ パパン ドググ グシギ ズゴゴ ズガギ ギブグ ゲズン ゲギド);
    my (@parts, $power);
    $power = 0;
    while ($n->is_pos) {
        my $digit = $n->copy->bmod(9)->numify;
        if ($digit) {
            my $term = $power ? 'バギン' . ('グバギン' x ($power - 1)) : $digits[$digit];
            $term .= 'グ' . $digits[$digit] if $power && $digit != 1;
            unshift @parts, $term;
        }
        $n->bdiv(9);
        $power++;
    }
    return join 'ド', @parts;
}

1;
