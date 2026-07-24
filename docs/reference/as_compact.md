# Render Capsule Compact Text

Produces a token-efficient text representation of a table context for
LLM prompt injection. Column names are not repeated per cell; span
headers group measure columns, and sections appear as bracketed headers.

## Usage

``` r
# S3 method for class 'ks_capsule'
as_compact(x, ...)

as_compact(x, ...)
```

## Arguments

- x:

  A `ks_context` (or later `ks_facts`) object.

- ...:

  Unused; for S3 compatibility.

## Value

Character scalar.

A length-1 character string.

## Examples

``` r
if (FALSE) { # \dontrun{
study <- ks_load("path/to/outputs/meta", ids = c("14-3.01"))
cat(as_compact(study[["14-3.01"]]))
} # }
```
