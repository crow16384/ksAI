# ksAI

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

# 1. Compile a study from a ksTFL meta folder
study <- load_study("path/to/outputs/meta")

# 2. Open a chat over the study (small studies embed all contexts; large
#    studies register tools for on-demand retrieval)
chat <- ks_chat(study, model = "qwen3:14b", provider = "ollama")

# 3. Ask cross-table questions
ask(chat, "How do vital sign changes relate to the adverse event profile?")

# 4. Draft CSR text with skills
ks_llm(chat, skill = "csr_section", id = "14-3.01", title = "ADAS-Cog")
compare_tables(chat, "14-3.01", "14-3.02")
```

## Key ideas

- **`ks_context`** — the render-join of a ksTFL specification and its data:
  title, population, columns, span headers, rendered rows (with section/kind
  metadata), and footnotes, all self-contained.
- **`ks_study`** — the registry of all outputs, split into tables, figures, and
  texts. Save/reload with `save_study()` / `load_study()`.
- **`ks_chat()`** — an [ellmer](https://ellmer.tidyverse.org/) chat wired to a
  study, with an automatic small/large context strategy.
- **Skills** — customizable Markdown prompt templates. Built-ins: `describe`,
  `summarize`, `csr_section`, `review`. Add your own with
  `ks_set_option(skills_dir = ...)`; see `ks_list_skills()`.

## Guardrails

The model is instructed never to compute or invent statistics — the numbers in
the contexts are final and authoritative, and every referenced value is cited
by output id, population, arm, and row.

## License

GPL-3
