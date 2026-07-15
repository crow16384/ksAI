# Open an AI Chat Session Over Loaded Outputs

Creates an
[ellmer](https://ellmer.tidyverse.org/reference/ellmer-package.html)
chat wired to the currently loaded
[ks_study](https://crow16384.github.io/ksAI/reference/is_ks_study.md)
subset.

## Usage

``` r
ks_chat(
  study,
  model,
  provider = ks_get_option("provider"),
  base_url = NULL,
  echo = "none",
  ...
)
```

## Arguments

- study:

  A
  [ks_study](https://crow16384.github.io/ksAI/reference/is_ks_study.md)
  object.

- model:

  Character scalar. The model name for the chosen provider.

- provider:

  Character scalar. One of `"ollama"` (default), `"lm_studio"`,
  `"openai"`, `"anthropic"`. Defaults to `ks_get_option("provider")`.

- base_url:

  Optional character scalar. Override the provider base URL (e.g. a
  remote Ollama host).

- echo:

  Character scalar passed to the ellmer constructor controlling
  streaming output. Default `"none"`.

- ...:

  Additional arguments forwarded to the ellmer chat constructor.

## Value

A `kschat` object wrapping the ellmer chat and the loaded study.

## Examples

``` r
if (FALSE) { # \dontrun{
study <- ks_load("path/to/outputs/meta", ids = c("14-3.01"))
chat <- ks_chat(study, model = "qwen3:14b")
} # }
```
