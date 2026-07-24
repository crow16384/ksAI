# Targeted Workflow, Clinical Capsules, and Result Chaining

## Overview

ksAI provides two complementary workflows for reasoning over ksTFL
outputs.

**Direct context workflow** (Sections 1–4): load a targeted subset of
outputs, render them as markdown or compact text, and run skill-based
prompts. This is the fastest path for single-output tasks and for
drafting CSR narratives where you already know which tables you need.

**Capsule workflow** (Sections 5–8): decompose all outputs into a
concept-level capsule store, enrich capsules with keywords and
embeddings, retrieve the smallest relevant subset for a query, and send
only those capsules to a larger reasoning model. This is the preferred
path for exploratory questions across many outputs and for large studies
where injecting full tables would exceed model context limits.

    ks_load() → ks_study → ks_context → ks_llm()        # direct
                        ↓
                  as_capsules() → ks_capsule_store
                  ks_annotate()   (semantic enrichment)
                  ks_embed()      (vector embeddings)
                  ks_retrieve()   (hybrid retrieval)
                  ks_reason()     → ks_result            # capsule

------------------------------------------------------------------------

## 1. Discover and load only needed IDs

``` r

library(ksAI)

# Inspect available outputs without loading data.
ids <- ks_list_ids("path/to/outputs/meta")
ids

# Load only the outputs required for the current task.
study <- ks_load(
  "path/to/outputs/meta",
  ids = c("14-3.01", "14-3.02", "14-5.01", "14-7.02")
)
study
```

Reload a previously persisted study or filter IDs from an existing `.ks`
file:

``` r

study_all <- ks_load("my_study.ks")
study_subset <- ks_load("my_study.ks", ids = c("14-3.01", "14-7.02"))
```

## 2. Inspect context objects

Each loaded output becomes a `ks_context` — the render-join of
specification and data:

``` r

ctx <- study[["14-3.01"]]
ctx                       # print: title, columns, span headers, row count
as_markdown(ctx)          # markdown table for reading
as_compact(ctx)           # token-efficient DSL: smaller than markdown
as_json(ctx)              # full JSON (columns + rows)
```

Compact format is ideal for model injection when the table is large. For
a table with span-header groups it emits a one-time legend (`SPANS:`,
`COLS:`) and short keys per row rather than repeating arm labels:

    TABLE: 14-5.01 | Population: Safety
    TITLE: ...
    SPANS: A=Placebo (N=86); B=Xanomeline Low Dose (N=84); C=Xanomeline High Dose (N=84)
    COLS: n(%), [AEs]
    [CARDIAC DISORDERS]
    SINUS BRADYCARDIA:  A: 2 (2.3%), [2]  |  B: 7 (8.3%), [10]  |  C: 8 (9.5%), [12]

Set the format globally before any LLM call:

``` r

ks_set_option(context_format = "compact")   # "markdown" | "compact" | "json"
```

## 3. Run skills or free prompts

``` r

# Preferred: pass study and provider directly (context injected once).
out_describe <- ks_llm(
  study,
  ids = "14-3.01",
  skill = "describe",
  model = "qwen3:14b",
  provider = "ollama"
)

# Multi-ID review (requires exactly two IDs).
out_review <- ks_llm(
  study,
  ids = c("14-3.01", "14-3.02"),
  skill = "review",
  model = "qwen3:14b",
  provider = "ollama"
)

# Extra user instruction on top of a skill template.
out_section <- ks_llm(
  study,
  ids = "14-7.02",
  skill = "csr_section",
  prompt = "Keep only statements supported by explicit values.",
  model = "qwen3:14b",
  provider = "ollama"
)

# Free-form mode (no skill template).
out_free <- ks_llm(
  study,
  ids = c("14-3.01", "14-7.02"),
  skill = NULL,
  prompt = "Compare efficacy and safety signals.",
  model = "qwen3:14b",
  provider = "ollama"
)
```

Alternatively create a persistent chat session — useful when you want to
ask follow-up questions in a conversational thread. Note that
[`ks_chat()`](https://crow16384.github.io/ksAI/reference/ks_chat.md)
embeds all loaded contexts in the system prompt, so set `context_format`
before building the chat and keep `max_rows` within the model’s context
window:

``` r

ks_set_option(context_format = "compact", max_rows = 50L)
chat <- ks_chat(study, model = "qwen3:14b", provider = "ollama")
ks_llm(chat, ids = "14-3.01", skill = "describe")
```

## 4. Save, reload, and chain results

[`ks_llm()`](https://crow16384.github.io/ksAI/reference/ks_llm.md) and
[`ks_reason()`](https://crow16384.github.io/ksAI/reference/ks_reason.md)
both return a `ks_result`. Persist with
[`save_result()`](https://crow16384.github.io/ksAI/reference/save_result.md)
(writes both `.md` and `.json`) and reload with
[`load_result()`](https://crow16384.github.io/ksAI/reference/load_result.md):

``` r

save_result(out_section, "analysis/out-14-7-02")
out_loaded <- load_result("analysis/out-14-7-02")
```

Pass a previous result to `prior` so the next run can build on it:

``` r

out_refined <- ks_llm(
  study,
  ids = "14-7.02",
  skill = "csr_section",
  prompt = "Tighten the narrative; remove any unsupported claims.",
  prior = out_loaded,
  model = "qwen3:14b",
  provider = "ollama"
)
```

------------------------------------------------------------------------

## 5. Build a Clinical Capsule store

When a study has many outputs or individual tables are too large to fit
in one prompt, ask an LLM to group **tables and figures** into
**clinical capsules** — named semantic units with a meaning-based tree
and multi-membership (`member_ids`). There is no rule-based / CDISC
formation path: `model` is required. Vision-capable models receive
figure images; R only attaches assets. `n_ctx` is set when the model is
loaded in LM Studio — not in this call.

**Option A — small context** (fit ~8k): small batches, no images, merge
pass.

``` r

# LLM-only capsule formation — Option A (8k-class context).
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
store

# Structural review (no LLM) and tree printout.
print(review_capsules(store, study))
capsule_tree(store)

# Inspect individual capsules.
names(store$capsules)[1:6]
cap <- store$capsules[[names(store$capsules)[[1]]]]
cap                    # print: label, members, parent, children
cap$member_ids         # table/figure output ids in this capsule
cap$compact_text       # text a model will see for this capsule
cap$child_ids          # child capsule ids in the semantic tree

# Expand full member content from the live study.
cat(capsule_content(store, cap$capsule_id, study, format = "compact"))
```

**Option B — large context** (raise Context Length in LM Studio first,
e.g. 32k+):

``` r

# store <- as_capsules(
#   study,
#   model = "qwen3.5-4b",
#   provider = "lm_studio",
#   base_url = "http://127.0.0.1:1234",
#   detail = "compact",
#   max_excerpt_rows = 12L,
#   batch_size = 12L,
#   attach_images = FALSE,  # TRUE only with a vision model
#   params = ellmer::params(temperature = 0),
#   api_args = list(enable_thinking = FALSE)
# )
```

The hierarchy is an LLM-assigned tree (`parent_id` / `child_ids`) by
information meaning — not MedDRA `ROW_KIND` levels. One output may
appear in several capsules.

Persist the store alongside your `.ks` file:

``` r

save_capsules(store, "my_study.ksc")
store <- load_capsules("my_study.ksc")
```

------------------------------------------------------------------------

## 6. Enrich with keywords and embeddings

### 6a. Pure-R keyword pass (always fast, no model needed)

``` r

store <- ks_annotate(store)
store$capsules[[names(store$capsules)[[1]]]]$keywords
```

This tokenizes `label`, `member_ids`, and `compact_text`, strips stop
words, and detects known clinical abbreviations (`TEAE`, `SOC`, `PT`,
etc.).

### 6b. Optional small-LLM enrichment pass

A small local model can identify medical concepts, synonyms, and richer
keywords (JSON keys `concepts`, `synonyms`, `keywords`). Domain
reclassification is not part of annotation.

``` r

store <- ks_annotate(
  store,
  model    = "qwen3.5-4b",
  provider = "lm_studio",
  base_url = "http://127.0.0.1:1234",
  force    = FALSE  # skip capsules already annotated
)
```

### 6c. Embedding vectors

[`ks_embed()`](https://crow16384.github.io/ksAI/reference/ks_embed.md)
calls the OpenAI-compatible `/v1/embeddings` endpoint —
`text-embedding-nomic-embed-text-v1.5` runs out of the box in LM Studio:

``` r

ks_set_option(
  embed_model = "text-embedding-nomic-embed-text-v1.5",
  embed_url   = "http://127.0.0.1:1234/v1"
)

store <- ks_embed(store)
cid <- names(store$capsules)[[1]]
length(store$capsules[[cid]]$embedding)
```

Embeddings are stored in `capsule$embedding` as a numeric vector and
persisted in the `.ksc` file.
[`ks_retrieve()`](https://crow16384.github.io/ksAI/reference/ks_retrieve.md)
falls back to keyword-only scoring when embeddings are absent.

------------------------------------------------------------------------

## 7. Retrieve the smallest relevant subset

[`ks_retrieve()`](https://crow16384.github.io/ksAI/reference/ks_retrieve.md)
scores every capsule against a query using three signals blended by
configurable weights:

| Signal   | Default weight | Source                                             |
|----------|----------------|----------------------------------------------------|
| Semantic | 0.6            | cosine similarity with query embedding             |
| Keyword  | 0.3            | token overlap between query and `capsule$keywords` |
| Metadata | 0.1            | match on `label`, `member_id`, and/or `population` |

``` r

subset <- ks_retrieve(
  store,
  query  = "cardiac events in the Xanomeline High Dose arm",
  n      = 5L,
  filter = list(label = "cardiac")
)

subset                   # print: query + top-5 ranked capsules with scores
names(subset$capsules)   # selected capsule IDs
subset$scores            # data.frame: capsule_id, semantic, keyword, metadata, score
```

------------------------------------------------------------------------

## 8. Reason over retrieved capsules

[`ks_reason()`](https://crow16384.github.io/ksAI/reference/ks_reason.md)
combines retrieval and the reasoning step in one call. The model **never
sees the full study** — only the capsule compact texts for the matched
subset, plus label / members / tree metadata:

``` r

out <- ks_reason(
  store,
  query    = "Summarize cardiac findings and statistical significance",
  n        = 5L,
  expand   = FALSE,   # TRUE → also include child capsules
  model    = "gemma-4-26b-a4b-it-mlx",
  provider = "lm_studio"
)

out                  # ks_result with skill = "reason"
cat(out$response)
```

Set `expand = TRUE` for progressive disclosure: children of matched
capsules are included via `child_ids`:

``` r

out_expanded <- ks_reason(
  store,
  query    = "Which related outputs drove the cardiac safety theme?",
  n        = 3L,
  expand   = TRUE,
  model    = "gemma-4-26b-a4b-it-mlx",
  provider = "lm_studio"
)
```

Optional LLM critique of the capsule tree (vision models can review
figures):

``` r

# rev <- ks_review_capsules(
#   store, study,
#   model = "qwen3:14b",
#   provider = "ollama",
#   attach_images = TRUE
# )
```

------------------------------------------------------------------------

## 9. Suggested project flow

### For focused tasks (1–3 outputs, model context not a constraint)

1.  [`ks_list_ids()`](https://crow16384.github.io/ksAI/reference/ks_list_ids.md)
    → identify outputs
2.  `ks_load(ids = ...)` → targeted study
3.  `ks_set_option(context_format = "compact")` → token-efficient
    injection
4.  [`ks_llm()`](https://crow16384.github.io/ksAI/reference/ks_llm.md) →
    generate draft
5.  [`save_result()`](https://crow16384.github.io/ksAI/reference/save_result.md)
    /
    [`load_result()`](https://crow16384.github.io/ksAI/reference/load_result.md) +
    `prior =` → iterate

### For broad tasks (many outputs or large tables)

1.  `ks_load(ids = NULL)` → full study (tables + figures)
2.  `as_capsules(study, model = ...)` → LLM semantic tree (vision for
    figures)
3.  `review_capsules(store, study)` / `capsule_tree(store)` → inspect
4.  `ks_annotate(store)` → keywords (+ optional small-LLM concepts)
5.  `ks_embed(store)` → semantic vectors via local embedding model
6.  `save_capsules(store, ...)` → persist for reuse
7.  `ks_reason(store, query, n)` → retrieve + reason in one call
8.  [`save_result()`](https://crow16384.github.io/ksAI/reference/save_result.md)
    → traceable deliverable

Capsule stores can be built once from the full study and reused across
many writing sessions without reloading or reprocessing the ksTFL source
JSON.
