#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
reference=${GRONGIGO_RUBY_ROOT:-.reference/grongigo}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
status=0
for source in examples/*.grg; do
    name=$(basename "$source" .grg)
    ruby "$reference/bin/grongigo" -o "$tmp/$name.ruby.c" "$source" > /dev/null
    gcc -o "$tmp/$name.ruby" "$tmp/$name.ruby.c"
    "$tmp/$name.ruby" > "$tmp/$name.ruby.out"
    "${PERL:-perl}" bin/grongigo --target c -o "$tmp/$name.perl.c" "$source" > /dev/null
    gcc -o "$tmp/$name.perl-c" "$tmp/$name.perl.c"
    "$tmp/$name.perl-c" > "$tmp/$name.perl-c.out"
    "${PERL:-perl}" bin/grongigo --target perl -o "$tmp/$name.pl" "$source" > /dev/null
    "${PERL:-perl}" "$tmp/$name.pl" > "$tmp/$name.perl.out"
    "${PERL:-perl}" "demo/$name.pl" > "$tmp/$name.filter.out"
    if cmp -s "$tmp/$name.ruby.out" "$tmp/$name.perl-c.out" \
        && cmp -s "$tmp/$name.ruby.out" "$tmp/$name.perl.out" \
        && cmp -s "$tmp/$name.ruby.out" "$tmp/$name.filter.out"; then
        echo "OK   $name"
    else
        echo "DIFF $name"
        for route in perl-c perl filter; do
            diff -u "$tmp/$name.ruby.out" "$tmp/$name.$route.out" || :
        done
        status=1
    fi
done
exit "$status"
