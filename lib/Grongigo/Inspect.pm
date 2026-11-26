package Grongigo::Inspect;
use v5.36;
use utf8;
use Exporter 'import';
our @EXPORT_OK = qw(inspect token_inspect);

sub inspect ($value, $type = 'string') {
    return 'nil' unless defined $value;
    return "$value" if $type eq 'number';
    my %escape = ("\\" => "\\\\", '"' => '\\"', "\n" => '\\n', "\t" => '\\t',
        "\r" => '\\r', "\a" => '\\a', "\x08" => '\\b', "\f" => '\\f', "\e" => '\\e', "\x0b" => '\\v');
    $value =~ s/([\\"\x00-\x1f\x7f-\x9f\x{2028}\x{2029}\p{Cn}])/$escape{$1} \/\/ sprintf(ord($1) <= 0xffff ? '\\u%04X' : '\\u{%X}', ord $1)/ge;
    $value =~ s/#(?=[{\$\@])/\\#/g;
    return '"' . $value . '"';
}

sub token_inspect ($token) {
    return 'Token(' . $token->{type} . ', ' . inspect($token->{value}, $token->{type})
        . ", L$token->{line}:$token->{column})";
}

1;
