#!/usr/bin/env bash
# Builds Arrow C++ (static, cached) and this checkout's dataset JNI library for the host Linux architecture, then stages
# it at nr/.work/dist/arrow_dataset_jni/<arch>/. Run through nr/build-linux.sh, which runs it in Docker.
#
# Arrow C++ options mirror upstream's Linux release build (ci/scripts/jni_manylinux_build.sh) for the
# parts the dataset JNI library uses: Acero, CSV, dataset, JSON, ORC, Parquet, Substrait, mimalloc, no jemalloc.
# S3, GCS and Gandiva are off: the library reads local files only.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/nr/versions.sh"
case "$(uname -m)" in
  aarch64) ARCH=aarch_64 ;;
  x86_64) ARCH=x86_64 ;;
  *) echo "unsupported architecture $(uname -m)" >&2; exit 2 ;;
esac
WORK=$ROOT/nr/.work
BUILD=$WORK/build-linux-$ARCH
CPP_INSTALL=$BUILD/cpp-install

if [ ! -f "$CPP_INSTALL/lib/cmake/ArrowDataset/ArrowDatasetConfig.cmake" ]; then
  cmake -S "$WORK/arrow-$ARROW_CPP_VERSION/cpp" -B "$BUILD/cpp" -GNinja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$CPP_INSTALL" -DCMAKE_UNITY_BUILD=ON \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DARROW_BUILD_SHARED=OFF -DARROW_BUILD_STATIC=ON -DARROW_BUILD_TESTS=OFF \
    -DARROW_DEPENDENCY_SOURCE=BUNDLED -DARROW_DEPENDENCY_USE_SHARED=OFF \
    -DARROW_ACERO=ON -DARROW_CSV=ON -DARROW_DATASET=ON -DARROW_JSON=ON -DARROW_ORC=ON -DARROW_PARQUET=ON \
    -DARROW_SUBSTRAIT=ON -DARROW_FILESYSTEM=ON -DARROW_S3=OFF -DARROW_GCS=OFF -DARROW_GANDIVA=OFF \
    -DARROW_JEMALLOC=OFF -DARROW_MIMALLOC=ON -DARROW_RPATH_ORIGIN=ON \
    -DARROW_WITH_BROTLI=ON -DARROW_WITH_LZ4=ON -DARROW_WITH_SNAPPY=ON -DARROW_WITH_ZLIB=ON -DARROW_WITH_ZSTD=ON \
    -DPARQUET_BUILD_EXAMPLES=OFF -DPARQUET_BUILD_EXECUTABLES=OFF -DPARQUET_REQUIRE_ENCRYPTION=OFF
  cmake --build "$BUILD/cpp"
  cmake --install "$BUILD/cpp"
fi

rm -rf "$BUILD/jni" "$BUILD/jni-install"
cmake -S "$ROOT" -B "$BUILD/jni" -GNinja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="$CPP_INSTALL" -DCMAKE_INSTALL_PREFIX="$BUILD/jni-install" \
  -DARROW_JAVA_JNI_ENABLE_DEFAULT=OFF -DARROW_JAVA_JNI_ENABLE_DATASET=ON -DBUILD_TESTING=OFF
cmake --build "$BUILD/jni"
cmake --install "$BUILD/jni"

OUT=$WORK/dist/arrow_dataset_jni/$ARCH
mkdir -p "$OUT"
cp "$(find "$BUILD/jni-install" -name libarrow_dataset_jni.so | head -1)" "$OUT/"
strip --strip-unneeded "$OUT/libarrow_dataset_jni.so"
echo "built $OUT/libarrow_dataset_jni.so against Arrow C++ $ARROW_CPP_VERSION"
