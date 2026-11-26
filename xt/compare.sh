#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")/.."
section=${1:-all}
case "$section" in Tokens|AST|C|Errors|all) ;; *) echo "Usage: $0 [Tokens|AST|C|Errors|all]" >&2; exit 1 ;; esac
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
pick() {
    if [ "$section" = all ]; then cat; else
        awk -v s="=== $section ===" '$0 == s { f = 1 } f && /^=== / && $0 != s { f = 0 } f'
    fi
}
status=0
for golden in t/golden/*.txt; do
    name=$(basename "$golden" .txt)
    source=examples/$name.grg
    [ -f "$source" ] || source=t/corpus/$name.grg
    if ! "${PERL:-perl}" xt/perl_dump.pl "$source" > "$tmp/actual"; then
        echo "FAIL $name (Perl dump failed)"
        status=1
        continue
    fi
    pick < "$golden" > "$tmp/expected-section"
    pick < "$tmp/actual" > "$tmp/actual-section"
    if diff -u "$tmp/expected-section" "$tmp/actual-section" > "$tmp/diff"; then
        echo "OK   $name"
    else
        echo "DIFF $name"
        cat "$tmp/diff"
        status=1
    fi
done
exit "$status"
