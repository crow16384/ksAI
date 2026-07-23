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

# S3 method for class 'ks_context'
as_capsules(
  x,
  model = NULL,
  provider = ks_get_option("provider"),
  base_url = NULL,
  llm_domain = c("unknown", "always", "never"),
  llm_min_confidence = 0.5,
  ...
)

# S3 method for class 'ks_study'
as_capsules(
  x,
  model = NULL,
  provider = ks_get_option("provider"),
  base_url = NULL,
  llm_domain = c("unknown", "always", "never"),
  llm_min_confidence = 0.5,
  ...
)
```

## Arguments

- x:

  A `ks_context` or `ks_study`.

- ...:

  Extra args forwarded to the ellmer chat constructor.

- model:

  Optional small LLM for domain classification (e.g. a 4B local model).
  `NULL` keeps deterministic inference only.

- provider:

  LLM provider. Defaults to
  [`ks_get_option()`](https://crow16384.github.io/ksAI/reference/ks_get_option.md)`"provider"`.

- base_url:

  Optional provider URL override.

- llm_domain:

  When to call the model: `"unknown"` (default — only if rules yield
  `UNKNOWN`), `"always"` (after annotation / `domain_map` / MedDRA
  structure; lexicon and id are fallbacks), or `"never"`.

- llm_min_confidence:

  Minimum confidence (0–1) to accept an LLM domain. Below this, rules
  continue / return `UNKNOWN`.

## Value

A `ks_capsule_store`.

## Details

Domain codes are inferred once per output (language-agnostic rules
first). Pass `model` to ask a small local LLM when rules leave the
domain `UNKNOWN` (default), or always after hard signals
(`llm_domain = "always"`). The chat is created once per call and reused
across tables in a study.
