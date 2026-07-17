# Build Clinical Capsules from Contexts

Converts one
[ks_context](https://crow16384.github.io/ksAI/reference/is_ks_context.md)
(or all contexts in a
[ks_study](https://crow16384.github.io/ksAI/reference/is_ks_study.md))
into a concept-centric capsule registry suitable for semantic
enrichment, retrieval, and progressive-disclosure reasoning.

## Usage

``` r
as_capsules(x, ...)
```

## Arguments

- x:

  A `ks_context` or `ks_study`.

- ...:

  Unused; for S3 compatibility.

## Value

A `ks_capsule_store`.
