#!/usr/bin/env bash
# Downloads and verifies the Arrow C++ source release into nr/.work/arrow-$ARROW_CPP_VERSION (once).
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/nr/versions.sh"
WORK=$ROOT/nr/.work
DIR=$WORK/arrow-$ARROW_CPP_VERSION
[ -f "$DIR/cpp/CMakeLists.txt" ] && exit 0
mkdir -p "$WORK"
NAME=apache-arrow-$ARROW_CPP_VERSION.tar.gz
URL=https://archive.apache.org/dist/arrow/arrow-$ARROW_CPP_VERSION/$NAME
curl -fsSL -o "$WORK/$NAME" "$URL"
curl -fsSL -o "$WORK/$NAME.sha512" "$URL.sha512"
(cd "$WORK" && shasum -a 512 -c "$NAME.sha512")
tar -xzf "$WORK/$NAME" -C "$WORK"
mv "$WORK/apache-arrow-$ARROW_CPP_VERSION" "$DIR"
rm "$WORK/$NAME" "$WORK/$NAME.sha512"
