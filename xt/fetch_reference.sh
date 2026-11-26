#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
revision=dba84313e7be4ff79d2ad31bc7182fe4c9ed4da1
destination=.reference/grongigo
if [ -f "$destination/REVISION" ] && [ "$(cat "$destination/REVISION")" = "$revision" ]; then
    echo "Ruby reference ready: $revision"
    exit 0
fi
if [ -e "$destination" ]; then
    echo "Refusing to replace $destination; move it aside first." >&2
    exit 1
fi
mkdir -p .reference
tmp=$(mktemp -d .reference/download.XXXXXX)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
curl -fL "https://codeload.github.com/ydah/grongigo/tar.gz/$revision" -o "$tmp/source.tar.gz"
mkdir "$tmp/source"
tar -xzf "$tmp/source.tar.gz" --strip-components=1 -C "$tmp/source"
printf '%s\n' "$revision" > "$tmp/source/REVISION"
mv "$tmp/source" "$destination"
echo "Ruby reference ready: $revision"
