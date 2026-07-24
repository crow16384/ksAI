# LLM Deep Review of Capsules

Asks an LLM (typically vision-capable for figures) to critique capsule
grouping and member content.

## Usage

``` r
ks_review_capsules(
  store,
  study,
  model,
  capsule_ids = NULL,
  provider = ks_get_option("provider"),
  base_url = NULL,
  attach_images = TRUE,
  echo = "none",
  ...
)
```

## Arguments

- store:

  A `ks_capsule_store`.

- study:

  A `ks_study` for member expansion and figure assets.

- model:

  LLM model name.

- capsule_ids:

  Optional subset of capsule ids (default: all).

- provider:

  LLM provider.

- base_url:

  Optional provider URL.

- attach_images:

  Logical. Attach figure images for vision models.

- echo:

  Echo mode for ellmer.

- ...:

  Extra args to the chat constructor.

## Value

A
[ks_result](https://crow16384.github.io/ksAI/reference/is_ks_result.md).
