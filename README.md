# ksAI <img src="man/figures/logo.png" align="right" height="139" alt="ksAI logo"/>

`ksAI` is an offline, AI-native reasoning layer on top of the
[ksTFL](https://crow16384.github.io/ksTFL/) clinical tables framework. It reads
the metadata and data JSON produced by `ksTFL::save_report()`, compiles every
study output into a self-contained, LLM-ready registry, and lets a medical
writer reason across the whole set of statistical results and draft Clinical
Study Report (CSR) narratives — using a local model via Ollama or LM Studio, or
a hosted OpenAI-compatible provider.

No live ksTFL session is required at runtime: `ksAI` works entirely from the
saved JSON.

## Installation

```r
# install.packages("pak")
pak::local_install("path/to/ksAI")
```

`ksAI` imports `ksTFL`, `ellmer`, `jsonlite`, `cli`, `checkmate`, and `rlang`.

## Quick start

```r
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

- **`ks_context`** — the render-join of a ksTFL specification and its data:
  title, population, columns, span headers, rendered rows (with section/kind
  metadata), and footnotes, all self-contained.
- **`ks_study`** — the registry of all outputs, split into tables, figures, and
  texts. Save/reload with `save_study()` / `ks_load()`.
- **`ks_chat()`** — an [ellmer](https://ellmer.tidyverse.org/) chat wired to a
  targeted loaded subset.
- **`ks_result`** — persisted output from `ks_llm()`. Save/load with
  `save_result()` / `load_result()`.
- **Clinical capsules** — `as_capsules()` decomposes large studies into
  concept-level units with language-agnostic domain tags (`domain_map`,
  multilingual lexicon, optional small-LLM via `model` /
  `llm_domain`). Enrich with `ks_annotate()`, embed, retrieve, and reason.
- **Skills** — customizable Markdown prompt templates. Built-ins: `describe`,
  `summarize`, `csr_section`, `review`. Add your own with
  `ks_set_option(skills_dir = ...)`; see `ks_list_skills()`.

## Guardrails

The model is instructed never to compute or invent statistics — the numbers in
the contexts are final and authoritative, and every referenced value is cited
by output id, population, arm, and row.

## License

GPL-3
