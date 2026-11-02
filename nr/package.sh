#!/usr/bin/env bash
# Packages arrow-dataset-$NR_VERSION.jar from this checkout and the native libraries under nr/.work/dist, installs it
# into ~/.m2 as org.apache.arrow:arrow-dataset:$NR_VERSION, and copies it to nr/out/ with a manifest.
#
# Platforms kept: Linux aarch_64 and x86_64, macOS arm64; Windows and Intel macOS are left out. A platform not built with
# nr/build-linux.sh gets the stock $STOCK_VERSION library, which has no createScannerWithReadahead: scans there use Arrow's
# default read-ahead.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/nr/versions.sh"
WORK=$ROOT/nr/.work
STAGE=$WORK/stage
OUT=$ROOT/nr/out
CENTRAL=https://repo1.maven.org/maven2/org/apache/arrow/arrow-dataset/$STOCK_VERSION
STOCK_JAR=$WORK/arrow-dataset-$STOCK_VERSION.jar
LIBS="arrow_dataset_jni/aarch_64/libarrow_dataset_jni.so arrow_dataset_jni/x86_64/libarrow_dataset_jni.so
      arrow_dataset_jni/aarch_64/libarrow_dataset_jni.dylib"

if [ ! -f "$STOCK_JAR" ]; then
  curl -fsSL -o "$STOCK_JAR.part" "$CENTRAL/arrow-dataset-$STOCK_VERSION.jar"
  [ "$(shasum -a 1 "$STOCK_JAR.part" | cut -d' ' -f1)" = "$(curl -fsSL "$CENTRAL/arrow-dataset-$STOCK_VERSION.jar.sha1")" ]
  mv "$STOCK_JAR.part" "$STOCK_JAR"
fi

rm -rf "$STAGE" && mkdir -p "$STAGE" "$OUT"
MANIFEST=$OUT/arrow-dataset-$NR_VERSION.txt
{
  echo "arrow-dataset $NR_VERSION: arrow-java $STOCK_VERSION + $(git -C "$ROOT" rev-parse --short HEAD)$(git -C "$ROOT" diff --quiet HEAD -- . ':!nr' || echo ' (uncommitted changes)')"
  echo "native libraries:"
} > "$MANIFEST"
for LIB in $LIBS; do
  mkdir -p "$STAGE/$(dirname "$LIB")"
  if [ -f "$WORK/dist/$LIB" ]; then
    cp "$WORK/dist/$LIB" "$STAGE/$LIB"
    SOURCE="rebuilt against Arrow C++ $ARROW_CPP_VERSION"
  else
    unzip -q -o "$STOCK_JAR" "$LIB" -d "$STAGE"
    SOURCE="stock $STOCK_VERSION, read-ahead options ignored"
  fi
  echo "  $LIB  $(shasum -a 256 "$STAGE/$LIB" | cut -d' ' -f1)  $SOURCE" >> "$MANIFEST"
done

docker run --rm -v "$ROOT":/src -v "$HOME/.m2":/root/.m2 -w /src maven:3.9-eclipse-temurin-17-noble bash -c "
  set -euo pipefail
  mvn -B -ntp -q -Parrow-jni -pl dataset -DskipTests -Darrow.cpp.build.dir=/src/nr/.work/stage/ package
  mvn -B -ntp -q -Parrow-jni -pl dataset help:effective-pom -Doutput=/src/nr/.work/dataset-effective-pom.xml"

# a pom with the stock module's compile and runtime dependencies at their resolved versions, so Maven consumers get them
python3 - "$WORK/dataset-effective-pom.xml" "$NR_VERSION" > "$WORK/arrow-dataset-$NR_VERSION.pom" <<'PY'
import sys
import xml.etree.ElementTree as ET
ns = {"m": "http://maven.apache.org/POM/4.0.0"}
project = ET.parse(sys.argv[1]).getroot()
print('<?xml version="1.0" encoding="UTF-8"?>')
print('<project xmlns="http://maven.apache.org/POM/4.0.0"><modelVersion>4.0.0</modelVersion>')
print(f"<groupId>org.apache.arrow</groupId><artifactId>arrow-dataset</artifactId><version>{sys.argv[2]}</version>")
print("<dependencies>")
for dep in project.findall("m:dependencies/m:dependency", ns):
    field = lambda name: (dep.findtext(f"m:{name}", default="", namespaces=ns) or "").strip()
    scope = field("scope") or "compile"
    if scope not in ("compile", "runtime"):
        continue
    classifier = f"<classifier>{field('classifier')}</classifier>" if field("classifier") else ""
    print(f"<dependency><groupId>{field('groupId')}</groupId><artifactId>{field('artifactId')}</artifactId>"
          f"<version>{field('version')}</version>{classifier}<scope>{scope}</scope></dependency>")
print("</dependencies></project>")
PY

JAR=$OUT/arrow-dataset-$NR_VERSION.jar
cp "$ROOT/dataset/target/arrow-dataset-$STOCK_VERSION.jar" "$JAR"
docker run --rm -v "$ROOT":/src -v "$HOME/.m2":/root/.m2 -w /src maven:3.9-eclipse-temurin-17-noble \
  mvn -B -ntp -q install:install-file -Dfile="nr/out/arrow-dataset-$NR_VERSION.jar" \
  -DpomFile="nr/.work/arrow-dataset-$NR_VERSION.pom"
echo "jar sha256 $(shasum -a 256 "$JAR" | cut -d' ' -f1)" >> "$MANIFEST"
cat "$MANIFEST"
