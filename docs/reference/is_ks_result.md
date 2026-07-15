# The ks_result Class

A `ks_result` stores one generated answer from
[`ks_llm()`](https://crow16384.github.io/ksAI/reference/ks_llm.md),
including the selected output ids, prompt metadata, model/provider, and
response text. `is_ks_result()` tests for the class.

## Usage

``` r
is_ks_result(x)
```

## Arguments

- x:

  An object.

## Value

`TRUE` if `x` is a `ks_result`, otherwise `FALSE`.
