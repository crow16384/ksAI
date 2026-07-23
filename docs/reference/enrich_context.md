# Enrich a Table Context with User Knowledge

Returns a new `ks_context` with user-supplied metadata overlaid. The
original object is not modified. `annotations` are merged with any
existing annotations rather than replaced.

## Usage

``` r
enrich_context(ctx, population = NULL, source = NULL, annotations = list())
```

## Arguments

- ctx:

  A `ks_context` object.

- population:

  Optional character scalar. Overrides the analysis population.

- source:

  Optional character scalar. Overrides the source program.

- annotations:

  Named list of free-form metadata to merge in. Use `domain` to force
  the capsule domain code.

## Value

A new `ks_context` object.

## Details

Set `annotations = list(domain = "AE")` (or any study-specific code) to
override automatic domain inference used by
[`as_capsules()`](https://crow16384.github.io/ksAI/reference/as_capsules.md).
Domain tags are language-agnostic: multilingual titles, MedDRA
structure, ICH-style ids, and
[`ks_set_option()`](https://crow16384.github.io/ksAI/reference/ks_get_option.md)
`domain_map` are also consulted.

## Examples

``` r
if (FALSE) { # \dontrun{
ctx <- study$tables[["14-3.01"]]
ctx <- enrich_context(ctx, population = "ITT",
                      annotations = list(sap_ref = "Section 9.2",
                                         domain = "EFFC"))
} # }
```
