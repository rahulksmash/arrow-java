#!/usr/bin/env bash
# Checks a packaged build on Linux in Docker: the rebuilt library exports createScannerWithReadahead and has ORC, and the
# dataset module's scan tests pass against the staged libraries (TestFileSystemDataset: Parquet, ORC,
# CSV, read-ahead 0). Run after nr/package.sh.
#   nr/verify.sh aarch_64|x86_64
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
case "${1:?aarch_64 or x86_64}" in
  aarch_64) PLATFORM=linux/arm64 ;;
  x86_64) PLATFORM=linux/amd64 ;;
  *) echo "unknown architecture $1" >&2; exit 2 ;;
esac
LIB=nr/.work/stage/arrow_dataset_jni/$1/libarrow_dataset_jni.so
docker run --rm --platform "$PLATFORM" -v "$ROOT":/src -v "$HOME/.m2":/root/.m2 -w /src \
  maven:3.9-eclipse-temurin-17-noble bash -c "
  set -euo pipefail
  apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq binutils >/dev/null
  [ \"\$(nm -D $LIB | grep -c JniWrapper_createScannerWithReadahead)\" -gt 0 ] || { echo 'no createScannerWithReadahead in $LIB'; exit 1; }
  [ \"\$(strings -a $LIB | grep -c OrcFileFormat)\" -gt 0 ] || { echo 'no ORC support in $LIB'; exit 1; }
  echo '$LIB: createScannerWithReadahead and ORC present'
  mvn -B -ntp -q -Parrow-jni -pl dataset test -Darrow.cpp.build.dir=/src/nr/.work/stage/ \
    -Dtest=TestFileSystemDataset
  echo 'dataset tests passed'"
