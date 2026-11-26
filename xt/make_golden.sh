#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
for source in examples/*.grg t/corpus/*.grg; do
    ruby xt/ruby_dump.rb "$source" > "$tmp/$(basename "$source" .grg).txt"
done
cp "$tmp/"*.txt t/golden/
