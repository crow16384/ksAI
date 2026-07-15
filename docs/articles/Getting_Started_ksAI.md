# Getting Started with ksAI

## What ksAI does

`ksAI` adds an offline, AI-native reasoning layer on top of the
[ksTFL](https://crow16384.github.io/ksTFL/) clinical tables framework.
ksTFL computes the tables, figures, and listings of a study
deterministically and writes them to a *meta folder* as JSON (structural
metadata plus the rendered data). `ksAI` reads that folder, compiles
every output into a self-contained, LLM-ready **study registry**, and
lets a medical writer ask questions across the whole set of statistical
results and draft Clinical Study Report (CSR) narratives — using a local
model via Ollama or LM Studio, or a hosted provider.

No live ksTFL session is required: `ksAI` works entirely from the saved
JSON.

## 1. Discover IDs and load targeted outputs

List output IDs from a ksTFL meta folder (the `metaPath` you passed to
[`ksTFL::save_report()`](https://crow16384.github.io/ksTFL/reference/save_report.html)),
then load only the tables you want in context:

``` r

library(ksAI)

ks_list_ids("path/to/outputs/meta")
study <- ks_load("path/to/outputs/meta", ids = c("14-3.01", "14-3.02"))
study
```

Each output becomes a `ks_context`: the render-join of specification and
data, with the title, analysis population, columns, span headers,
rendered rows, and footnotes all in one object.

``` r

study$tables[["14-3.01"]]
```

Rows keep their displayed values *and* the structural metadata a writer
needs — the section a row belongs to (`Baseline`, `Week 24`,
`Change from Baseline`) and whether it is a detail or a label row.

## 2. Open a chat session

[`ks_chat()`](https://crow16384.github.io/ksAI/reference/ks_chat.md)
wires the loaded subset to a model.

``` r

chat <- ks_chat(study, model = "qwen3:14b", provider = "ollama")
```

## 3. Draft CSR text with skills

Skills are reusable prompt templates.
[`ks_llm()`](https://crow16384.github.io/ksAI/reference/ks_llm.md) fills
a skill’s placeholders from the selected IDs and returns a `ks_result`
object.

``` r

# Describe one table
ks_llm(chat, ids = "14-3.01", skill = "describe")

# Audience-tailored summary
ks_llm(chat, ids = "14-3.01", skill = "summarize", audience = "clinician")

# Draft a CSR results section
ks_llm(chat, ids = "14-3.01", skill = "csr_section", title = "ADAS-Cog (11)")

# Review consistency across two tables
ks_llm(chat, ids = c("14-3.01", "14-3.02"), skill = "review")

# Free-form user prompt on multiple IDs
ks_llm(chat, ids = c("14-3.01", "14-3.02"), skill = NULL,
  prompt = "Compare these outputs and answer in Spanish")
```

## 4. Customize skills

The built-in skills are `describe`, `summarize`, `csr_section`, and
`review`. Add your own — or override a built-in — by pointing
`skills_dir` at a folder of Markdown templates. Placeholders use
`{{name}}` syntax; `{{context}}` is filled automatically.

``` r

ks_set_option(skills_dir = "~/my-study-prompts")
ks_list_skills()

# A file ~/my-study-prompts/exec_summary.md becomes a skill:
ks_llm(chat, ids = "14-3.01", skill = "exec_summary")
```

## 5. Persist studies and generated results

Compile once, reuse across sessions.
[`save_study()`](https://crow16384.github.io/ksAI/reference/save_study.md)
writes a self-contained `.ks` file (rendered rows embedded), and
[`ks_load()`](https://crow16384.github.io/ksAI/reference/ks_load.md)
reloads it without the original ksTFL folder. Model outputs can be
persisted with
[`save_result()`](https://crow16384.github.io/ksAI/reference/save_result.md).

``` r

save_study(study, "my_study.ks")

# Next session
study <- ks_load("my_study.ks")
study$tables[["14-3.01"]] <- enrich_context(
  study$tables[["14-3.01"]],
  population = "ITT",
  annotations = list(sap_ref = "Section 9.2")
)

out <- ks_llm(study, ids = "14-3.01", skill = "describe", model = "qwen3:14b")
save_result(out, "analysis/table-14-3-01")
load_result("analysis/table-14-3-01")
```

## Guardrails

The system prompt instructs the model to never compute or invent
statistics: the numbers in the contexts are final and authoritative, and
every referenced value is cited by output id, population, arm, and row
so the writer can verify it.
