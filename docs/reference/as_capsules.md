# Build Clinical Capsules from Contexts (LLM)

Groups **tables** and **figures** into a named semantic capsule tree
using an LLM only (small or large). There is no rule-based / CDISC
formation path. `model` is required. Figure image pixels are attached
for vision-capable models; R does not interpret plots.

## Usage

``` r
as_capsules(
  x,
  model,
  provider = ks_get_option("provider"),
  base_url = NULL,
  max_excerpt_rows = 12L,
  detail = c("compact", "full"),
  min_confidence = 0.5,
  batch_size = 24L,
  attach_images = TRUE,
  ...
)

# S3 method for class 'ks_context'
as_capsules(
  x,
  model,
  provider = ks_get_option("provider"),
  base_url = NULL,
  max_excerpt_rows = 12L,
  detail = c("compact", "full"),
  min_confidence = 0.5,
  batch_size = 24L,
  attach_images = TRUE,
  ...
)

# S3 method for class 'ks_study'
as_capsules(
  x,
  model,
  provider = ks_get_option("provider"),
  base_url = NULL,
  max_excerpt_rows = 12L,
  detail = c("compact", "full"),
  min_confidence = 0.5,
  batch_size = 24L,
  attach_images = TRUE,
  ...
)
```

## Arguments

- x:

  A `ks_context` or `ks_study`.

- model:

  LLM model name (required).

- provider:

  LLM provider. Defaults to
  [`ks_get_option()`](https://crow16384.github.io/ksAI/reference/ks_get_option.md)`"provider"`.

- base_url:

  Optional provider URL override.

- max_excerpt_rows:

  Maximum table rows included in each catalog excerpt.

- detail:

  `"compact"` (default) or `"full"` table excerpts.

- min_confidence:

  Minimum confidence (0–1) to keep an LLM capsule.

- batch_size:

  Maximum catalog items per classify call before an LLM merge pass.

- attach_images:

  Logical. Attach figure assets via ellmer when readable.

- ...:

  Extra args forwarded to the ellmer chat constructor (e.g.
  `params = ellmer::params(temperature = 0)`,
  `api_args = list(enable_thinking = FALSE)`). Context length (`n_ctx`)
  is **not** set here — configure it when loading the model in LM Studio
  or Ollama.

## Value

A `ks_capsule_store`.

## Context size

Two practical patterns when the prompt exceeds the model window:

**Option A (small `n_ctx`, e.g. 8192):** shrink each classify call with
`batch_size = 1`, low `max_excerpt_rows`, and `attach_images = FALSE`.
Partial trees are merged by a second LLM pass. Preferable when you
cannot raise context; slightly weaker for subtle cross-output
multi-membership.

**Option B (large `n_ctx`):** raise Context Length in LM Studio first,
then use larger `batch_size` / `max_excerpt_rows`. Better whole-catalog
interpretation. Set `attach_images = TRUE` only with a vision-capable
model.

## Examples

``` r
if (FALSE) { # \dontrun{
# Option A — fit an 8k-class local model
store <- as_capsules(
  study,
  model = "qwen3.5-4b",
  provider = "lm_studio",
  base_url = "http://127.0.0.1:1234",
  detail = "compact",
  max_excerpt_rows = 4L,
  batch_size = 1L,
  attach_images = FALSE,
  params = ellmer::params(temperature = 0),
  api_args = list(enable_thinking = FALSE)
)

# Option B — after raising Context Length in LM Studio (e.g. 32k+)
store <- as_capsules(
  study,
  model = "qwen3.5-4b",
  provider = "lm_studio",
  base_url = "http://127.0.0.1:1234",
  detail = "compact",
  max_excerpt_rows = 12L,
  batch_size = 12L,
  attach_images = FALSE,
  params = ellmer::params(temperature = 0),
  api_args = list(enable_thinking = FALSE)
)
} # }
```
