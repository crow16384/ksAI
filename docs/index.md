# ksAI

`ksAI` is an offline, AI-native reasoning layer on top of the
[ksTFL](https://crow16384.github.io/ksTFL/) clinical tables framework.
It reads the metadata and data JSON produced by
[`ksTFL::save_report()`](https://crow16384.github.io/ksTFL/reference/save_report.html),
compiles every study output into a self-contained, LLM-ready registry,
and lets a medical writer reason across the whole set of statistical
results and draft Clinical Study Report (CSR) narratives — using a local
model via Ollama or LM Studio, or a hosted OpenAI-compatible provider.

No live ksTFL session is required at runtime: `ksAI` works entirely from
the saved JSON.

## Installation

``` r

# install.packages("pak")
pak::local_install("path/to/ksAI")
```

`ksAI` imports `ksTFL`, `ellmer`, `jsonlite`, `cli`, `checkmate`, and
`rlang`.

## Quick start

``` r

library(ksAI)

# 1. Discover available output IDs and load only the targets you need
ks_list_ids("path/to/outputs/meta")
study <- ks_load("path/to/outputs/meta", ids = c("14-3.01", "14-3.02"))

# 2. Open a chat over the loaded subset
chat <- ks_chat(study, model = "qwen3:14b", provider = "ollama")

# 3. Run a skill (supports one or multiple IDs)
out <- ks_llm(chat, ids = c("14-3.01", "14-3.02"), skill = "review")

# 4. Add free-form user instructions (model follows prompt language)
out2 <- ks_llm(chat, ids = "14-3.01", skill = "describe", prompt = "Describe in Spanish")

# 5. Persist generated output
save_result(out2, "analysis/table-14-3-01")
loaded_out <- load_result("analysis/table-14-3-01")
```

## Key ideas

- **`ks_context`** — the render-join of a ksTFL specification and its
  data: title, population, columns, span headers, rendered rows (with
  section/kind metadata), and footnotes, all self-contained.
- **`ks_study`** — the registry of all outputs, split into tables,
  figures, and texts. Save/reload with
  [`save_study()`](https://crow16384.github.io/ksAI/reference/save_study.md)
  /
  [`ks_load()`](https://crow16384.github.io/ksAI/reference/ks_load.md).
- **[`ks_chat()`](https://crow16384.github.io/ksAI/reference/ks_chat.md)**
  — an [ellmer](https://ellmer.tidyverse.org/) chat wired to a targeted
  loaded subset.
- **`ks_result`** — persisted output from
  [`ks_llm()`](https://crow16384.github.io/ksAI/reference/ks_llm.md).
  Save/load with
  [`save_result()`](https://crow16384.github.io/ksAI/reference/save_result.md)
  /
  [`load_result()`](https://crow16384.github.io/ksAI/reference/load_result.md).
- **Clinical capsules** — `as_capsules(study, model = ...)` asks an LLM
  to group tables and figures into a named semantic tree (`member_ids`,
  multi-membership). Vision-capable models receive figure images. Review
  with
  [`review_capsules()`](https://crow16384.github.io/ksAI/reference/review_capsules.md)
  /
  [`capsule_content()`](https://crow16384.github.io/ksAI/reference/capsule_content.md)
  /
  [`ks_review_capsules()`](https://crow16384.github.io/ksAI/reference/ks_review_capsules.md),
  then enrich with
  [`ks_annotate()`](https://crow16384.github.io/ksAI/reference/ks_annotate.md),
  embed, retrieve, and reason.
- **Skills** — customizable Markdown prompt templates. Built-ins:
  `describe`, `summarize`, `csr_section`, `review`. Add your own with
  `ks_set_option(skills_dir = ...)`; see
  [`ks_list_skills()`](https://crow16384.github.io/ksAI/reference/ks_list_skills.md).

## Guardrails

The model is instructed never to compute or invent statistics — the
numbers in the contexts are final and authoritative, and every
referenced value is cited by output id, population, arm, and row.

## License

GPL-3
