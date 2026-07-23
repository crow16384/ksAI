# Annotate Capsule Store with Semantic Metadata

Enriches capsules in a ks_capsule_store in two passes: a deterministic
token/abbreviation pass, plus an optional small-LLM extraction pass.
When `model` is supplied, capsules still tagged `UNKNOWN` are also
reclassified once per `source_id` by the same small model (closed domain
codes). Use `force_domain = TRUE` to reclassify every source table.

## Usage

``` r
ks_annotate(
  store,
  model = NULL,
  provider = ks_get_option("provider"),
  base_url = NULL,
  batch_size = 64L,
  force = FALSE,
  force_domain = FALSE,
  llm_min_confidence = 0.5,
  ...
)
```

## Arguments

- store:

  A `ks_capsule_store`.

- model:

  Optional model for the small semantic LLM pass (and domain fallback).

- provider:

  Provider for LLM pass. Defaults to
  [`ks_get_option()`](https://crow16384.github.io/ksAI/reference/ks_get_option.md)`provider`.

- base_url:

  Optional provider URL override.

- batch_size:

  Integer batch size for deterministic pass.

- force:

  Recompute keyword/concept metadata even if already present.

- force_domain:

  Reclassify domains with the LLM even when not `UNKNOWN`. Ignored when
  `model` is `NULL`.

- llm_min_confidence:

  Minimum confidence (0–1) to accept an LLM domain.

- ...:

  Extra args forwarded to the chat constructor.

## Value

Updated `ks_capsule_store`.
