# Get or Set ksAI Options

`ks_get_option()` retrieves a package option; `ks_set_option()` updates
one or more options for the current session.

## Usage

``` r
ks_get_option(key)

ks_set_option(...)
```

## Arguments

- key:

  Character scalar. Option name. One of `"max_rows"`, `"skills_dir"`,
  `"provider"`.

- ...:

  Named `key = value` pairs to set (for `ks_set_option()`).

## Value

`ks_get_option()` returns the option value. `ks_set_option()` invisibly
returns the previous values of the changed options.

## Examples

``` r
ks_get_option("max_rows")
#> [1] 200
old <- ks_set_option(max_rows = 300L)
ks_set_option(!!!old)
```
