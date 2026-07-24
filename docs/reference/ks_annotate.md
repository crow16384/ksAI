# Annotate Capsule Store with Semantic Metadata

Enriches capsules in a `ks_capsule_store` in two passes: a deterministic
token/abbreviation pass, plus an optional small-LLM extraction pass.

## Usage

``` r
ks_annotate(
  store,
  model = NULL,
  provider = ks_get_option("provider"),
  base_url = NULL,
  batch_size = 64L,
  force = FALSE,
  ...
)
```

## Arguments

- store:

  A `ks_capsule_store`.

- model:

  Optional model for the small semantic LLM pass.

- provider:

  Provider for LLM pass. Defaults to
  [`ks_get_option()`](https://crow16384.github.io/ksAI/reference/ks_get_option.md)`provider`.

- base_url:

  Optional provider URL override.

- batch_size:

  Integer batch size for deterministic pass.

- force:

  Recompute keyword/concept metadata even if already present.

- ...:

  Extra args forwarded to the chat constructor.

## Value

Updated `ks_capsule_store`.
