
```{r}
#| include: false
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = FALSE,
  purl = FALSE
)
```

## Purpose

ksAI is an offline reasoning layer on top of [ksTFL](https://crow16384.github.io/ksTFL/)
clinical outputs. ksTFL computes tables, figures, and listings deterministically
and writes them to a **meta folder** as JSON (structural specification plus
rendered data). ksAI reads that folder, compiles outputs into self-contained
**context objects**, and routes them to a language model through two
complementary pipelines:

1. **Direct context pipeline** — when you already know which outputs matter and
   they fit in the model window.
2. **Clinical capsule pipeline** — when the study is large, exploratory, or
   token-constrained; an LLM groups tables and figures into semantic capsules,
   then enrich, retrieve, and reason over a minimal evidence set.

Both pipelines share the same import layer and the same **CKR** (Clinical
Knowledge Representation) serialization formats. They differ in how much
structure is built before the reasoning model runs.

---

## End-to-end data flow

```{mermaid}
flowchart TB
  subgraph ksTFL["ksTFL (upstream)"]
    SPEC["Spec JSON<br/>(layout, columns, titles)"]
    DATA["Data JSON<br/>(cell values)"]
    INDEX["_index.json"]
  end

  subgraph import["ksAI import"]
    LIST["ks_list_ids()"]
    LOAD["ks_load()"]
    CTX["ks_context"]
    STUDY["ks_study"]
  end

  subgraph ckr["CKR layers"]
    MD["as_markdown()"]
    CMP["as_compact()"]
    FACTS["as_facts() + retrieve()"]
    CAPS["as_capsules()"]
  end

  subgraph direct["Direct pipeline"]
    CHAT["ks_chat() / ks_llm()"]
    SKILL["Skill templates"]
    RES["ks_result"]
  end

  subgraph capsule["Capsule pipeline"]
    ANN["ks_annotate()"]
    EMB["ks_embed()"]
    RET["ks_retrieve()"]
    REA["ks_reason()"]
  end

  SPEC --> LOAD
  DATA --> LOAD
  INDEX --> LIST
  LIST --> LOAD
  LOAD --> CTX
  CTX --> STUDY

  CTX --> MD
  CTX --> CMP
  CTX --> FACTS
  CTX --> CAPS

  STUDY --> CHAT
  MD --> SKILL
  CMP --> SKILL
  SKILL --> CHAT
  CHAT --> RES

  CAPS --> ANN --> EMB --> RET --> REA
  REA --> RES

  RES --> SAVE["save_result()"]
```

At runtime **no live ksTFL session** is required. Everything ksAI needs is in
the saved JSON artefacts (or in a persisted `.ks` / `.ksc` file).

---

## Layer 0: ksTFL artefacts

ksTFL's `save_report()` writes to a meta folder:

| Artefact | Role |
|----------|------|
| `_index.json` | Report catalogue: spec file names, versions, `is_latest` flags |
| `{hash}.json` | Specification: titles, columns, span headers, footnotes, `dataRef` |
| `{hash}.json` (data) | Rendered cell values filtered to `report_cols` |

Each spec JSON may contain one or more outputs. ksAI resolves stable **output
ids** (for example `14-3.01`, `14-5.01`) from document filenames and spec keys.

`ks_list_ids(meta_path)` scans the index and returns id, type, and title without
loading data. `ks_load(meta_path, ids = ...)` parses only the requested outputs
and assembles a `ks_study`.

---

## Layer 1: `ks_context` — the render-join

A `ks_context` is the central value object. It is **not** a thin metadata
extract; it is the full render-join of specification and data:

```
ks_context
├── id, type, title, subtitles
├── population, source
├── columns[]          # visible cols: name, label, type, is_grouping
├── span_headers[]     # treatment-arm groups
├── rows[]             # cells + section + kind (ROW_KIND, SECTION, …)
├── n_rows_total       # before max_rows truncation
├── footnotes[]
└── annotations{}      # user overlays via enrich_context()
```

**Row metadata** lifted from invisible control columns during import:

- `section` — for example `Baseline`, `Week 24`, `Change from Baseline`
- `kind` — for AE tables: `SOC`, `PT`, `OVERALL`; for continuous endpoints: `PARAM`

This metadata drives CSR writing ("describe Week 24 vs Baseline") and
fact-store filtering (`section` / `kind` in `as_facts()`). Capsule trees are
built separately by an LLM over whole outputs, not from row hierarchy.

### Import options

| Option | Default | Effect |
|--------|---------|--------|
| `max_rows` | `200` | Cap rows embedded per table at load time |
| `latest_only` | `TRUE` | Skip obsolete spec versions in the index |

Truncation is intentional: it protects model context windows. Use
`as_facts()` / capsules for structured access to specific rows without sending
the full table.

---

## Layer 2: `ks_study` — targeted registry

`ks_study` partitions contexts by output type:

```
ks_study
├── tables{}    # named ks_context
├── figures{}
├── texts{}
└── meta_dir    # source path
```

Indexing `study[["14-3.01"]]` returns a single context across all types.
`save_study()` / `ks_load("file.ks")` persist a compiled subset for reuse
without the original ksTFL folder.

**Design intent:** medical writers work on **targeted subsets** — efficacy
tables for one CSR section, safety tables for another — not necessarily the
entire study at once.

---

## Layer 3: CKR — Clinical Knowledge Representation

CKR is the token-efficient, retrieval-capable representation stack over
`ks_context`. Three formats, increasing structure:

### 3a. `as_markdown()` — human-readable

Default for reading and for models that benefit from familiar table layout.
Repeats column headers and arm labels per row group. Highest token cost.

### 3b. `as_compact()` — compact DSL

Pure R. Target: **~50–70% fewer tokens** than markdown for span-heavy tables.

**Span tables** emit a one-time legend plus short keys per row:

```
TABLE: 14-5.01 | Population: Safety
TITLE: ...
SPANS: A=Placebo (N=86); B=Xanomeline Low (N=84); C=Xanomeline High (N=84)
COLS: n(%), [AEs]
[CARDIAC DISORDERS]
SINUS BRADYCARDIA:  A: 2 (2.3%), [2]  |  B: 7 (8.3%), [10]  |  C: 8 (9.5%), [12]
```

**Non-span tables** use a column header line plus pipe-delimited rows.

Controlled by `ks_set_option(context_format = "compact")` before `ks_llm()` or
`ks_chat()`.

### 3c. `as_facts()` + `retrieve()` — columnar fact store

C++23 `FactTable` + `InvertedIndex` (Rcpp `XPtr`). One table becomes a
columnar store:

| Column class | Examples |
|--------------|----------|
| `row_label` | `Age (y)`, `CARDIAC DISORDERS`, `Bsln` |
| `section` | `Baseline Characteristics` |
| `kind` | `SOC`, `PT`, `OVERALL` |
| `dim` (grouping) | visit, parameter |
| `measure` | pre-formatted cell strings per arm |

`retrieve(facts, rows = ..., sections = ..., spans = ...)` subsets rows and
optionally filters to treatment-arm span columns, then `as_compact.ks_facts()`
renders only the matched slice.

**When to use:** you know the structural filter (one SOC, one visit, one
parameter row) and want zero LLM tokens spent on irrelevant rows.

```{r}
#| eval: false
facts_ae <- as_facts(study[["14-5.01"]])
retrieve(facts_ae, rows = "CARDIAC DISORDERS") |> as_compact()
```

---

## Direct context pipeline

The direct pipeline is the fastest path from loaded outputs to CSR text.

```{mermaid}
sequenceDiagram
  participant W as Writer
  participant K as ksAI
  participant E as ellmer / LLM

  W->>K: ks_load(ids = c("14-3.01"))
  W->>K: ks_set_option(context_format = "compact")
  W->>K: ks_llm(study, ids, skill = "csr_section", title = ...)
  K->>K: .resolve_contexts_by_ids()
  K->>K: .render_contexts() → as_compact()
  K->>K: .fill_prompt(skill template)
  K->>E: chat(system + filled prompt)
  E-->>K: response text
  K-->>W: ks_result
  W->>K: save_result(out, path)
```

### Skills

Skills are Markdown templates in `inst/prompts/` with `{{placeholders}}`:

| Skill | Placeholders | Use |
|-------|--------------|-----|
| `describe` | `{{context}}`, `{{id}}` | Neutral table description |
| `summarize` | `{{audience}}`, `{{context}}` | Audience-tailored summary |
| `csr_section` | `{{title}}`, `{{context}}` | CSR results narrative |
| `review` | `{{context1}}`, `{{context2}}` | Cross-table consistency (2 ids) |

User skills in `ks_set_option(skills_dir = ...)` shadow built-ins by name.

`ks_llm()` accepts either a `ks_study` (creates a per-call chat with
`system_single` prompt) or a `kschat` (reuses session). Placeholders like
`title` and `audience` fill the skill template — they are **not** passed to
the ellmer constructor.

### `ks_chat()` vs `ks_llm(study, ...)`

| Mode | System prompt | Context injection |
|------|---------------|-------------------|
| `ks_llm(study, ...)` | `system_single` (one output focus) | Per call, selected ids only |
| `ks_chat(study, ...)` | `system` + **all loaded outputs** | Embedded once in system prompt |
| `ks_llm(chat, ...)` | Reuses chat system prompt | Adds selected id context again |

**Rule:** `ks_chat()` embeds every loaded output. Keep the loaded subset
small (one or two tables). For multi-table studies, prefer `ks_llm(study,
...)` or the capsule pipeline.

### Result chaining

`ks_result` stores ids, skill, prompt, model, provider, timestamp, and
response. `save_result()` writes `.md` + `.json`. Pass a prior result to
`prior =` in `ks_llm()` to refine iteratively:

```
Prior analysis:  <previous response>
---
<skill prompt with fresh table context>
Additional user request: <refinement instructions>
```

Chaining doubles prompt size (table + prior). Use compact tables or lower
`max_rows` when refining locally with 8k-context models.

### Guardrails

Built-in system prompts instruct the model to:

1. Never compute or invent statistics
2. Cite population, arm, and row for every value
3. State plainly when evidence is missing

---

## Clinical capsule pipeline

For large studies or exploratory questions, ksAI asks an LLM to group tables
and figures into **clinical capsules** — concept-centric semantic units — then
runs a four-stage agent pipeline over that store.

Membership is by **whole output id** (`member_ids`). Capsules form a tree via
`parent_id` / `child_ids`. Formation is LLM-only: meaning over titles, excerpts,
and figure images — not domain codes, filename conventions, or row hierarchy.

```{mermaid}
flowchart LR
  subgraph structure["Structure agent"]
    AC["as_capsules()"]
  end
  subgraph semantic["Semantic agent"]
    AN["ks_annotate()"]
  end
  subgraph retrieval["Retrieval agent"]
    EM["ks_embed()"]
    RT["ks_retrieve()"]
  end
  subgraph reasoning["Reasoning agent"]
    RS["ks_reason()"]
  end

  CTX["ks_context"] --> AC --> STORE["ks_capsule_store"]
  STORE --> AN --> STORE
  STORE --> EM --> STORE
  STORE --> RT --> SUB["ks_capsule_subset"]
  SUB --> RS --> OUT["ks_result"]
```

### Structure agent: `as_capsules()`

`as_capsules(x, model, ...)` **requires** `model`. It builds a catalog of
Table and Figure contexts (Text is excluded), sends compact excerpts to the
LLM using `inst/prompts/capsule_classify.md`, and validates the returned
JSON into a `ks_capsule_store`.

**What the LLM sees:**

- Titles, subtitles, population, source, and a compact content excerpt
  (`max_excerpt_rows`, `detail = "compact"` or `"full"`)
- For figures: `asset_path` resolved at import; when `attach_images = TRUE`,
  R attaches image bytes via ellmer so a **vision** model can read the plot.
  R does not interpret pixels itself.

**Formation rules** (enforced in the prompt and in R validation):

- Group by information meaning only — not domain codes, ICH/CSR numbering,
  or filenames
- Build a tree of themes → sub-themes with stable ASCII `capsule_id` slugs
- **Multi-membership** is allowed: one output may support several capsules
- Large catalogs are batched (`batch_size`); multiple chunks are merged with a
  second LLM pass
- Capsules below `min_confidence` are dropped; unknown member ids are ignored

```{r}
#| eval: false
store <- as_capsules(
  study,
  model = "qwen3.5-4b",
  provider = "lm_studio",
  base_url = "http://127.0.0.1:1234",
  max_excerpt_rows = 12L,
  min_confidence = 0.5
)
```

**Capsule anatomy:**

```
ks_capsule
├── capsule_id          # stable slug from the LLM
├── label               # human name (any language)
├── member_ids          # table/figure output ids (multi-membership OK)
├── parent_id, child_ids
├── population          # set when all members share one population
├── compact_text        # concatenated member compact excerpts
├── concepts, keywords, synonyms
├── embedding           # numeric vector (after ks_embed)
└── confidence          # LLM confidence kept at formation
```

Traceability is through `member_ids` back to loaded `ks_context` objects.
Use `capsule_content()` when you need full member renders rather than the
formation excerpts stored in `compact_text`.

Persist with `save_capsules(store, "study.ksc")` / `load_capsules()`.

### Review APIs

Formation and inspection are separate. After `as_capsules()`:

| Function | Role |
|----------|------|
| `capsule_tree(store)` | Print / return the parent→child tree |
| `capsule_membership(store, study)` | Output id ↔ capsule membership table |
| `review_capsules(store, study)` | Offline structural audit (empty capsules, unknown members, cycles, orphans, multi-membership) |
| `capsule_content(store, id, study)` | Expand full member renders from a live study |
| `ks_review_capsules(store, study, model, ...)` | LLM deep review (`capsule_review.md`); attaches figure images when requested |

```{r}
#| eval: false
capsule_tree(store)
capsule_membership(store, study)
review_capsules(store, study)

ks_review_capsules(
  store, study,
  model = "qwen3.5-4b",
  provider = "lm_studio",
  base_url = "http://127.0.0.1:1234"
)
```

### Semantic agent: `ks_annotate()`

Two-pass enrichment of capsule labels and compact text — keywords and optional
concepts only:

1. **Pure R pass** (always): tokenize `label`, `member_ids`, and
   `compact_text`; strip stop words; detect clinical abbreviations
   (`TEAE`, `SOC`, `PT`, …).
2. **Optional small-LLM pass** (when `model` is set): structured JSON
   extraction of `concepts`, `synonyms`, `keywords`. A 4B local model is
   sufficient. Use `force = TRUE` to recompute even when keywords already
   exist.

```{r}
#| eval: false
store <- ks_annotate(store)   # keywords only

store <- ks_annotate(
  store,
  model = "qwen3.5-4b",
  provider = "lm_studio",
  base_url = "http://127.0.0.1:1234",
  force = TRUE
)
```

Run once per study; reuse the `.ksc` file across writing sessions.

### Retrieval agent: `ks_embed()` + `ks_retrieve()`

`ks_embed()` calls an OpenAI-compatible `/v1/embeddings` endpoint and stores
vectors in `capsule$embedding`.

`ks_retrieve(store, query, n, filter, weights)` scores every capsule:

| Signal | Default weight | Mechanism |
|--------|---------------|-----------|
| Semantic | 0.6 | Cosine similarity: query embedding vs capsule embedding |
| Keyword | 0.3 | Token overlap with `capsule$keywords` |
| Metadata | 0.1 | Match on `label`, `member_id`, and/or `population` |

Returns a `ks_capsule_subset` with ranked capsules and score breakdown.

Optional `filter` fields contribute to the metadata score:

```{r}
#| eval: false
ks_retrieve(store,
  query = "cardiac bradycardia high dose",
  n = 5,
  filter = list(population = "Safety", member_id = "14-5.01"))
```

If embeddings are absent, semantic score falls back to 0 and keyword/metadata
signals still rank results.

### Reasoning agent: `ks_reason()`

Combines retrieval and generation:

1. `ks_retrieve()` → top *n* capsules
2. Optionally `expand = TRUE` → include child capsules from the LLM tree
   (progressive disclosure)
3. Format capsule `compact_text` + metadata into a context block
4. Send to a larger reasoning model with a focused system prompt

The reasoning model **never sees the full study** — only retrieved capsule
summaries. This is the capsule pipeline's primary token advantage.

```{r}
#| eval: false
ks_reason(store,
  query = "Summarize cardiac findings with n(%) per arm",
  n = 5,
  expand = TRUE,
  model = "gemma-4-26b-a4b-it-mlx",
  provider = "lm_studio")
```

### Progressive disclosure

```
Query → retrieve theme capsules (compact summaries)
      → reason at parent level
      → expand = TRUE pulls child capsules on demand
```

High-level reasoning happens over parent capsule summaries; child themes are
fetched only when the query or `expand` flag requires them. For full member
table/figure text outside reasoning, use `capsule_content()`.

---

## LLM integration

ksAI uses [ellmer](https://ellmer.tidyverse.org/) for provider abstraction.

| Provider | `base_url` | Notes |
|----------|------------|-------|
| `lm_studio` | `http://127.0.0.1:1234` (no `/v1`) | `chat_lmstudio()` adds `/v1` internally |
| `ollama` | default or custom | Local models |
| `openai` | API default | Hosted |
| `anthropic` | API default | Hosted |

Embeddings (`ks_embed`, query vectors in `ks_retrieve`) use the
**OpenAI-compatible** path: `http://127.0.0.1:1234/v1` in LM Studio.

### Recommended model split (local)

| Task | Model size | Function |
|------|------------|----------|
| Capsule formation / annotation / review | 4B+ (vision if figures) | `as_capsules()`, `ks_annotate(..., model = ...)`, `ks_review_capsules()` |
| CSR drafting / reasoning | 26B+ | `ks_llm()`, `ks_reason()` |
| Embeddings | dedicated | `text-embedding-nomic-embed-text-v1.5` |

Unload large models before loading small ones in LM Studio when memory is
constrained.

---

## Package options

| Option | Default | Purpose |
|--------|---------|---------|
| `max_rows` | `200` | Row cap per table at import |
| `context_format` | `"markdown"` | `"markdown"`, `"compact"`, or `"json"` for LLM injection |
| `provider` | `"ollama"` | Default ellmer provider |
| `skills_dir` | `NULL` | User skill template directory |
| `embed_model` | `text-embedding-nomic-embed-text-v1.5` | Embedding model name |
| `embed_url` | `http://127.0.0.1:1234/v1` | Embeddings endpoint |

Set `context_format` and `max_rows` **before** `ks_chat()` — the chat system
prompt is built at construction time.

---

## Choosing a pipeline

| Situation | Pipeline | Entry points |
|-----------|----------|--------------|
| One known table, CSR section | Direct | `ks_llm(study, ids, skill = "csr_section")` |
| Two tables, consistency check | Direct | `ks_llm(..., skill = "review")` |
| Filter to one SOC / visit / row | CKR facts | `retrieve(as_facts(ctx), rows = ...)` |
| Many outputs, exploratory Q&A | Capsule | `as_capsules(..., model)` → `ks_reason()` |
| Large AE / lab table, token limit | Capsule or facts | `ks_retrieve()` or `retrieve()` |
| Iterative refinement | Direct + chain | `save_result()` → `prior = load_result()` |
| Conversational follow-ups | Direct chat | `ks_chat(small_study)` → `chat$chat$chat()` |

---

## Persistence map

| File | Contents | Functions |
|------|----------|-----------|
| `.ks` | Compiled `ks_study` (embedded rows) | `save_study()`, `ks_load()` |
| `.ksc` | Capsule store (keywords, embeddings) | `save_capsules()`, `load_capsules()` |
| `.json` / `.md` | `ks_result` from LLM runs | `save_result()`, `load_result()` |
| ksTFL `meta/` | Source spec + data JSON | `ks_list_ids()`, `ks_load()` |

Typical project layout:

```
study-meta/          # ksTFL save_report output (source of truth)
my_study.ks          # compiled targeted subset
my_study.ksc         # capsule store (build once, reuse)
analysis/
  table-14-3-01.md   # generated CSR fragments
  table-14-3-01.json
```

---

## Runnable example

A full walkthrough of all four workflows (direct, facts, capsule, chaining)
ships with the package:

```{r}
#| eval: false
# Development checkout
# Rscript inst/examples/pilot-study-workflows.R

# Installed package
# Rscript system.file("examples", "pilot-study-workflows.R", package = "ksAI")
```

Bundled pilot-study meta data lives in `inst/examples/pilot-study/meta`.
Set `RUN_LLM <- FALSE` in the script to exercise import and CKR without live
chat/embed calls. Capsule formation (`as_capsules`) always requires a model.

---

## Design principles

1. **Deterministic upstream** — ksTFL numbers are final; ksAI never recomputes statistics.
2. **Targeted loading** — load only the ids you need; scale to full studies via capsules.
3. **Traceability** — every capsule links to member output ids; facts retain row structure from `ks_context`.
4. **Token economy** — compact DSL, fact filtering, and capsule retrieval minimize model input.
5. **Offline-first** — JSON-only import; local models via Ollama or LM Studio.
6. **Separation of concerns** — capsule formation (LLM over catalog + vision), enrichment (R + optional small LLM), retrieval (embeddings + keywords), reasoning (large LLM).

These layers compose: you can use `as_compact()` without capsules, capsules
without embeddings (keyword-only retrieval), or the full stack for large-study
Q&A.
