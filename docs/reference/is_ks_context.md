# The `ks_context` Class

A `ks_context` is the render-join of one ksTFL output's specification
and its data: a self-contained, LLM-ready object holding the title,
analysis population, columns, span headers, rendered rows, and
footnotes. Obtain them via
[`ks_load()`](https://crow16384.github.io/ksAI/reference/ks_load.md).
`is_ks_context()` tests for the class.

## Usage

``` r
is_ks_context(x)
```

## Arguments

- x:

  An object.

## Value

`TRUE` if `x` is a `ks_context`, otherwise `FALSE`.
