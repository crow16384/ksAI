# The `ks_study` Class

A `ks_study` is the registry of all compiled outputs of a study, split
into `$tables`, `$figures`, and `$texts` (each a named list of
[ks_context](https://crow16384.github.io/ksAI/reference/is_ks_context.md)
objects). Build one with
[`ks_load()`](https://crow16384.github.io/ksAI/reference/ks_load.md);
persist with
[`save_study()`](https://crow16384.github.io/ksAI/reference/save_study.md).
`is_ks_study()` tests for the class.

## Usage

``` r
is_ks_study(x)
```

## Arguments

- x:

  An object.

## Value

`TRUE` if `x` is a `ks_study`, otherwise `FALSE`.
