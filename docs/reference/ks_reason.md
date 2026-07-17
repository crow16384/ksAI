# Reason Over Retrieved Capsules

Retrieves top capsules for a query and asks a reasoning model using only
those capsule summaries. Optionally expands context with child capsules.

## Usage

``` r
ks_reason(
  store,
  query,
  n = 5L,
  expand = FALSE,
  model,
  provider = ks_get_option("provider"),
  base_url = NULL,
  echo = "none",
  ...
)
```

## Arguments

- store:

  A `ks_capsule_store`.

- query:

  User question.

- n:

  Number of top capsules to retrieve.

- expand:

  Logical. If `TRUE`, include child capsules of top results.

- model:

  Reasoning model name.

- provider:

  Provider (ollama/lm_studio/openai/anthropic).

- base_url:

  Optional provider URL override.

- echo:

  Echo mode forwarded to ellmer.

- ...:

  Extra args forwarded to chat constructor.

## Value

A
[ks_result](https://crow16384.github.io/ksAI/reference/is_ks_result.md).
