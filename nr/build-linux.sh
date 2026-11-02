#!/usr/bin/env bash
# Builds the dataset JNI library for Linux in Docker (Ubuntu 24.04, so it needs glibc 2.38 or newer at run time).
#   nr/build-linux.sh aarch_64     # native speed on an arm64 host
#   nr/build-linux.sh x86_64       # under emulation on an arm64 host this takes hours; prefer an x86_64 host
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
case "${1:?aarch_64 or x86_64}" in
  aarch_64) PLATFORM=linux/arm64 ;;
  x86_64) PLATFORM=linux/amd64 ;;
  *) echo "unknown architecture $1" >&2; exit 2 ;;
esac
"$ROOT/nr/scripts/fetch-arrow-cpp.sh"
docker run --rm --platform "$PLATFORM" -v "$ROOT":/src -w /src ubuntu:24.04 bash -c '
  set -euo pipefail
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq build-essential cmake ninja-build curl ca-certificates \
    openjdk-17-jdk binutils >/dev/null
  export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")
  nr/scripts/build-jni.sh'
