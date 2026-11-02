# arrow-dataset with scanner read-ahead

arrow-java `v18.3.0` plus `ScanOptions.Builder.batchReadahead(int)` and `fragmentReadahead(int)`, which reach Arrow
C++'s `ScannerBuilder` through a new JNI entry point, `JniWrapper.createScannerWithReadahead`. Stock 18.3.0 always scans
with Arrow's defaults (16 batches, 4 fragments). For Parquet, the scanner decodes whole row groups and reads ahead
`batch_readahead × batch_size` rows, rounded up to whole row groups, plus `fragment_readahead` batches in the scan node.
With wide row groups that holds many decoded row groups in memory per scan; read-ahead 0 keeps it to the row group being
read and the next.

The stock `createScanner` entry point is kept, so a native library without the new one still works; scans there use
Arrow's default read-ahead.

Output: `org.apache.arrow:arrow-dataset:18.3.0-nr-1`. It replaces `arrow-dataset:18.3.0`; all other arrow-java
artifacts stay at stock 18.3.0.

## Native libraries

| Platform | Library in the jar |
|---|---|
| Linux aarch_64 | rebuilt here |
| Linux x86_64 | stock 18.3.0, or rebuilt with `nr/build-linux.sh x86_64` |
| macOS arm64 | stock 18.3.0, for unit tests only |

Native code is built per OS, so a Mac can't load the Linux library. To run locally with the same library as a Linux
arm64 server (benchmarks, memory checks), run the JVM in a `linux/arm64` container; on an Apple Silicon Mac that runs
natively.

The libraries are built against the Arrow C++ 20.0.0 source release (`nr/versions.sh`, SHA-512 checked). Stock 18.3.0
used an untagged 21.0.0-SNAPSHOT for Linux and macOS, which can't be reproduced, and 20.0.0 for Windows. Build options
follow upstream's Linux release build, without S3, GCS and Gandiva: local files only (`nr/scripts/build-jni.sh`).

## Build

Needs Docker, `curl`, `shasum`, `unzip` and `python3`. Work files go to `nr/.work/`, results to `nr/out/`.

```bash
git clone https://github.com/rahulksmash/arrow-java.git && cd arrow-java
git checkout nr/18.3.0-scan-readahead
nr/build-linux.sh aarch_64   # ~10 min on an arm64 host; Arrow C++ is cached for later runs
nr/package.sh                # jar into ~/.m2 and nr/out/, with a manifest of each library's source and SHA-256
nr/verify.sh aarch_64        # new entry point and ORC present; dataset scan tests pass against the library
```

`nr/build-linux.sh x86_64` is optional; under emulation on an arm64 host it takes hours, so run it on an x86_64 host and
copy its `nr/.work/dist/` here before `nr/package.sh`.

## Use

From a checked-in file:

```groovy
api files("${rootDir}/libs/arrow-dataset-18.3.0-nr-1.jar")
api "org.apache.arrow:arrow-c-data:18.3.0"   // a file brings no transitive dependencies
```

Or from `~/.m2` after `nr/package.sh`: `implementation "org.apache.arrow:arrow-dataset:18.3.0-nr-1"` with
`mavenLocal()`. Either way, exclude the stock `arrow-dataset`.

```java
new ScanOptions.Builder(4096)
    .columns(Optional.of(columns))
    .batchReadahead(0)      // >= 0; unset keeps Arrow's default
    .fragmentReadahead(0)
    .build();
```

## Changing it

Bump `NR_VERSION` in `nr/versions.sh` for any change to the jar's content, rebuild, and copy the jar to its consumers
with the manifest's SHA-256. To move to a newer arrow-java, rebase onto its tag and update the versions together; from
19.0.0 the JNI initializes compute itself (GH-899), so Arrow C++ 21.0.0 or newer works. Drop the fork once upstream
exposes read-ahead.
