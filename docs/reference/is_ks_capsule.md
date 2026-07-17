# The `ks_capsule` Class

A `ks_capsule` is a concept-centric, traceable semantic unit derived
from a
[ks_context](https://crow16384.github.io/ksAI/reference/is_ks_context.md)
row group (for example OVERALL, SOC, PT). Each capsule stores compact
text, parsed statistics, hierarchy links, and optional embeddings.

## Usage

``` r
is_ks_capsule(x)
```

## Arguments

- x:

  An object.

## Value

`TRUE` if `x` is a `ks_capsule`, otherwise `FALSE`.
