# Render Capsule as Markdown

Reconstructs the output the way a reader sees it: real column labels
(not raw column codes), treatment-arm/span-header groups,
section-grouped rows, and footnotes. This is the representation injected
into single-output skill prompts, because models describe a rendered
table far more richly than the machine-shaped JSON produced by
[`as_json()`](https://crow16384.github.io/ksAI/reference/as_json.md).

## Usage

``` r
# S3 method for class 'ks_capsule'
as_markdown(x, ...)

as_markdown(x, ...)
```

## Arguments

- x:

  A `ks_context` object.

- ...:

  Unused; for S3 compatibility.

## Value

Character scalar.

A length-1 character string of Markdown.

## Examples

``` r
if (FALSE) { # \dontrun{
study <- ks_load("path/to/outputs/meta", ids = c("14-3.01"))
cat(as_markdown(study[["14-3.01"]]))
} # }
```
