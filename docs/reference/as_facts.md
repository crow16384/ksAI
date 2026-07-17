# Convert a `ks_context` into a Retrievable Fact Store

Builds a C++-backed columnar fact table from a compiled
[ks_context](https://crow16384.github.io/ksAI/reference/is_ks_context.md),
enabling structured filtering via
[`retrieve()`](https://crow16384.github.io/ksAI/reference/retrieve.md)
and compact rendering via
[`as_compact()`](https://crow16384.github.io/ksAI/reference/as_compact.md).

## Usage

``` r
as_facts(x, ...)
```

## Arguments

- x:

  A `ks_context` object.

- ...:

  Unused; for S3 compatibility.

## Value

A `ks_facts` object.
