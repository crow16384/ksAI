# Filter a `ks_facts` Store by Row Labels, Sections, or Spans

Returns a new `ks_facts` containing only matching rows. Span filters
keep measure columns belonging to the named span headers; row and
section filters use the C++ inverted index.

## Usage

``` r
retrieve(x, ...)
```

## Arguments

- x:

  A `ks_facts` object.

- ...:

  Unused; for S3 compatibility.

- rows:

  Optional character vector of row-label values to keep.

- sections:

  Optional character vector of section values to keep.

- spans:

  Optional character vector of span-header labels; measure columns
  outside those spans are dropped from rendering.

## Value

A filtered `ks_facts` object.
