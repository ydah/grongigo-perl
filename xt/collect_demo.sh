#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
reference=${GRONGIGO_RUBY_ROOT:-.reference/grongigo}
perl_command=${PERL:-perl}
output=demo/output
mkdir -p "$output"
{
    printf 'Ruby reference: '
    cat "$reference/REVISION"
    ruby -v
    "$perl_command" -e 'use v5.36; say "Perl $^V"'
    gcc --version | head -1
} > "$output/environment.txt"
{
    printf 'Ruby Lexer: '
    awk '!/^[[:space:]]*#/ && /[^[:space:]]/ { n++ } END { print n }' "$reference/lib/grongigo/lexer.rb"
    printf 'Perl Lexer: '
    awk '!/^[[:space:]]*#/ && /[^[:space:]]/ { n++ } END { print n }' lib/Grongigo/Lexer.pm
} > "$output/lexer-lines.txt"
"$perl_command" -Mutf8 -E 'binmode STDOUT, ":encoding(UTF-8)"; say join " / ", "ガ、 ダ、" =~ /(\p{Katakana}+)/g; say join " / ", "ガ、 ダ、" =~ /(\p{Script=Katakana}+)/g' > "$output/katakana.txt"
if ruby -e 'p(/(?{ 1 })/)' > "$output/ruby-regex.txt" 2>&1; then
    echo 'Expected Ruby to reject (?{...})' >&2
    exit 1
fi
{
    "$perl_command" bin/grongigo --segmentations バギンドドググ
    "$perl_command" bin/grongigo --segmentations ドググシギ
} > "$output/segmentations.txt"
bash xt/compare.sh all > "$output/golden-compare.txt"
sh xt/run_compare.sh > "$output/run-compare.txt" 2> "$output/gcc-warnings.txt"
"$perl_command" bin/grongigo --target perl -o "$output/factorial.pl" examples/factorial.grg > /dev/null
"$perl_command" demo/hello.pl > "$output/filter-hello.txt"
"$perl_command" demo/factorial.pl > "$output/filter-factorial.txt"
echo "Demo output saved in $output"
