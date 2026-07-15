# Render a `ks_context` as a JSON String

Produces the compact JSON representation of a table context used for
prompt injection and by the registered LLM tools.

## Usage

``` r
as_json(x, pretty = FALSE)
```

## Arguments

- x:

  A `ks_context` object.

- pretty:

  Logical. Pretty-print the JSON. Default `FALSE`.

## Value

A length-1 character string of JSON.
