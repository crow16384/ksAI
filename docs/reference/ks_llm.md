# Run a Skill or Free Prompt Against Selected Outputs

Runs one of the registered skill templates (or a free prompt) against
one or more loaded output ids. Returns a
[ks_result](https://crow16384.github.io/ksAI/reference/is_ks_result.md)
that can be saved via
[`save_result()`](https://crow16384.github.io/ksAI/reference/save_result.md)
and loaded later via
[`load_result()`](https://crow16384.github.io/ksAI/reference/load_result.md).

## Usage

``` r
ks_llm(
  x,
  ids,
  skill = "describe",
  prompt = NULL,
  prior = NULL,
  model = NULL,
  provider = ks_get_option("provider"),
  base_url = NULL,
  echo = "none",
  ...
)
```

## Arguments

- x:

  A
  [ks_study](https://crow16384.github.io/ksAI/reference/is_ks_study.md)
  or `kschat` object.

- ids:

  Character vector of output ids to include as context.

- skill:

  Optional skill name. Defaults to `"describe"`.

- prompt:

  Optional free-form user instructions. If `skill` is `NULL`, this is
  the main prompt body.

- prior:

  Optional
  [ks_result](https://crow16384.github.io/ksAI/reference/is_ks_result.md)
  from a previous run. Its response is prepended as prior analysis
  context.

- model:

  Optional model name when `x` is a
  [ks_study](https://crow16384.github.io/ksAI/reference/is_ks_study.md).
  Ignored for `kschat` input.

- provider:

  Optional provider when `x` is a
  [ks_study](https://crow16384.github.io/ksAI/reference/is_ks_study.md).
  Ignored for `kschat` input.

- base_url:

  Optional provider URL override when `x` is a
  [ks_study](https://crow16384.github.io/ksAI/reference/is_ks_study.md).

- echo:

  Echo mode forwarded to ellmer when `x` is a
  [ks_study](https://crow16384.github.io/ksAI/reference/is_ks_study.md).

- ...:

  Named placeholders for the selected skill template.

## Value

A
[ks_result](https://crow16384.github.io/ksAI/reference/is_ks_result.md)
object.

## Examples

``` r
if (FALSE) { # \dontrun{
study <- ks_load("path/to/outputs/meta", ids = c("14-3.01", "14-3.02"))
out <- ks_llm(study, ids = "14-3.01", skill = "describe", model = "qwen3:14b")
out2 <- ks_llm(study, ids = c("14-3.01", "14-3.02"), prompt = "Compare trends")
} # }
```
