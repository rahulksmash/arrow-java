/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.apache.arrow.dataset.scanner;

import java.nio.ByteBuffer;
import java.util.Optional;
import org.apache.arrow.util.Preconditions;

/** Options used during scanning. */
public class ScanOptions {
  private final long batchSize;
  private final Optional<String[]> columns;
  private final Optional<ByteBuffer> substraitProjection;
  private final Optional<ByteBuffer> substraitFilter;

  private final Optional<FragmentScanOptions> fragmentScanOptions;
  private final int batchReadahead;
  private final int fragmentReadahead;

  /**
   * Constructor.
   *
   * @param columns Projected columns. Empty for scanning all columns.
   * @param batchSize Maximum row number of each returned {@link
   *     org.apache.arrow.vector.ipc.message.ArrowRecordBatch}
   * @deprecated Deprecated. Use {@link #ScanOptions(long, Optional)} instead.
   */
  @Deprecated
  public ScanOptions(String[] columns, long batchSize) {
    this(
        batchSize,
        Optional.of(columns)
            .map(
                present -> {
                  if (present.length == 0) {
                    // Backwards compatibility: See ARROW-13257, in the new constructor, we now use
                    // null to scan for all columns.
                    return null;
                  }
                  return present;
                }));
  }

  /**
   * Constructor.
   *
   * @param batchSize Maximum row number of each returned {@link
   *     org.apache.arrow.vector.ipc.message.ArrowRecordBatch}
   * @param columns (Optional) Projected columns. {@link Optional#empty()} for scanning all columns.
   *     Otherwise, Only columns present in the Array will be scanned.
   */
  public ScanOptions(long batchSize, Optional<String[]> columns) {
    Preconditions.checkNotNull(columns);
    this.batchSize = batchSize;
    this.columns = columns;
    this.substraitProjection = Optional.empty();
    this.substraitFilter = Optional.empty();
    this.fragmentScanOptions = Optional.empty();
    this.batchReadahead = -1;
    this.fragmentReadahead = -1;
  }

  public ScanOptions(long batchSize) {
    this(batchSize, Optional.empty());
  }

  public Optional<String[]> getColumns() {
    return columns;
  }

  public long getBatchSize() {
    return batchSize;
  }

  public Optional<ByteBuffer> getSubstraitProjection() {
    return substraitProjection;
  }

  public Optional<ByteBuffer> getSubstraitFilter() {
    return substraitFilter;
  }

  public Optional<FragmentScanOptions> getFragmentScanOptions() {
    return fragmentScanOptions;
  }

  /** Batches to read ahead within a fragment; -1 for the native default. */
  public int getBatchReadahead() {
    return batchReadahead;
  }

  /** Fragments to read ahead; -1 for the native default. */
  public int getFragmentReadahead() {
    return fragmentReadahead;
  }

  /** Whether either read-ahead was set. */
  public boolean hasReadahead() {
    return batchReadahead >= 0 || fragmentReadahead >= 0;
  }

  /** Builder for Options used during scanning. */
  public static class Builder {
    private final long batchSize;
    private Optional<String[]> columns;
    private ByteBuffer substraitProjection;
    private ByteBuffer substraitFilter;
    private FragmentScanOptions fragmentScanOptions;
    private int batchReadahead = -1;
    private int fragmentReadahead = -1;

    /**
     * Constructor.
     *
     * @param batchSize Maximum row number of each returned {@link
     *     org.apache.arrow.vector.ipc.message.ArrowRecordBatch}
     */
    public Builder(long batchSize) {
      this.batchSize = batchSize;
    }

    /**
     * Set the Projected columns. Empty for scanning all columns.
     *
     * @param columns Projected columns. Empty for scanning all columns.
     * @return the ScanOptions configured.
     */
    public Builder columns(Optional<String[]> columns) {
      Preconditions.checkNotNull(columns);
      this.columns = columns;
      return this;
    }

    /**
     * Set the Substrait extended expression for Projection new columns.
     *
     * @param substraitProjection Expressions to evaluate for project new columns.
     * @return the ScanOptions configured.
     */
    public Builder substraitProjection(ByteBuffer substraitProjection) {
      Preconditions.checkNotNull(substraitProjection);
      this.substraitProjection = substraitProjection;
      return this;
    }

    /**
     * Set the Substrait extended expression for Filter.
     *
     * @param substraitFilter Expressions to evaluate for apply Filter.
     * @return the ScanOptions configured.
     */
    public Builder substraitFilter(ByteBuffer substraitFilter) {
      Preconditions.checkNotNull(substraitFilter);
      this.substraitFilter = substraitFilter;
      return this;
    }

    /**
     * Set the FragmentScanOptions.
     *
     * @param fragmentScanOptions fragment scan options
     * @return the ScanOptions configured.
     */
    public Builder fragmentScanOptions(FragmentScanOptions fragmentScanOptions) {
      Preconditions.checkNotNull(fragmentScanOptions);
      this.fragmentScanOptions = fragmentScanOptions;
      return this;
    }

    /** Batches to read ahead within a fragment (native default 16); 0 for none. */
    public Builder batchReadahead(int batchReadahead) {
      Preconditions.checkArgument(batchReadahead >= 0, "batchReadahead must be >= 0");
      this.batchReadahead = batchReadahead;
      return this;
    }

    /** Fragments (files) to read ahead (native default 4); 0 for none. */
    public Builder fragmentReadahead(int fragmentReadahead) {
      Preconditions.checkArgument(fragmentReadahead >= 0, "fragmentReadahead must be >= 0");
      this.fragmentReadahead = fragmentReadahead;
      return this;
    }

    public ScanOptions build() {
      return new ScanOptions(this);
    }
  }

  private ScanOptions(Builder builder) {
    batchSize = builder.batchSize;
    columns = builder.columns;
    substraitProjection = Optional.ofNullable(builder.substraitProjection);
    substraitFilter = Optional.ofNullable(builder.substraitFilter);
    fragmentScanOptions = Optional.ofNullable(builder.fragmentScanOptions);
    batchReadahead = builder.batchReadahead;
    fragmentReadahead = builder.fragmentReadahead;
  }
}
