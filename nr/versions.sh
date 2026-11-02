# Versions for this arrow-dataset build. Sourced by the nr/ scripts.
# Stock arrow-java release this fork is based on (git tag v$STOCK_VERSION).
STOCK_VERSION=18.3.0
# Version of the jar this fork produces; bump the suffix whenever the jar's content changes.
NR_VERSION=18.3.0-nr2
# Arrow C++ release the JNI library is built against. Stock 18.3.0 Linux and macOS libraries were built against an
# untagged 21.0.0-SNAPSHOT of Arrow C++ main; its Windows library against 20.0.0, the last release before Arrow C++
# moved compute kernels out of libarrow (21.0.0 needs arrow::compute::Initialize, which 18.3.0's JNI doesn't call).
ARROW_CPP_VERSION=20.0.0
