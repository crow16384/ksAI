# The `ks_capsule` Class

A `ks_capsule` is a named semantic unit grouping one or more
table/figure outputs (`member_ids`) produced by
[`as_capsules()`](https://crow16384.github.io/ksAI/reference/as_capsules.md).
Capsules form a tree via `parent_id` / `child_ids` and store compact
text plus optional embeddings.

## Usage

``` r
is_ks_capsule(x)
```

## Arguments

- x:

  An object.

## Value

`TRUE` if `x` is a `ks_capsule`, otherwise `FALSE`.
