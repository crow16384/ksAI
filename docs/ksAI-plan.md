# Plan: ksAI Package — AI-Native Layer for ksTFL

## TL;DR

Create a new R package `ksAI` that builds an AI reasoning layer on top
of ksTFL using `ellmer`. ksTFL stays unchanged (computes
deterministically); `ksAI` imports ksTFL and adds semantic extraction,
LLM wrapping, tool-use, skills, and an interactive table assistant. All
11 phases from the architecture document, sequenced by dependency.

------------------------------------------------------------------------

## Key Architectural Decisions

- **Package name**: `ksAI` (separate CRAN-style package, not extension
  of ksTFL)
- **kstable**: S3 class with two constructors — `as_kstable(TFL_spec)`
  (in-memory) and `kstable_from_json(spec_path)` (file-backed from
  save_report() output)
- **ks_context**: first-class exported S3 class (the semantic DSL) —
  persistent, serializable, user-editable; produced by
  `compile_context()`, reused across LLM sessions without recompiling
  from TFL_spec
- **LLM provider abstraction**: `ellmer` package (already supports
  Ollama, LM Studio, OpenAI, Anthropic)
- **ksTFL changes**: minimal — no changes needed; ksAI registers
  `as_kstable.TFL_spec()` S3 method by importing ksTFL
- **Structured outputs**: use ellmer’s `chat$extract()` (structured
  schema-based extraction)
- **Input flexibility**:
  [`ks_llm()`](https://crow16384.github.io/ksAI/reference/ks_llm.md) and
  all interactive functions accept either `kstable` OR `ks_context`
  directly — the context is the stable unit of exchange

------------------------------------------------------------------------

## Package Structure

    ksAI/
    ├── DESCRIPTION
    ├── NAMESPACE
    ├── R/
    │   ├── ksAI.R            # Package docs + .onLoad()
    │   ├── kstable.R         # kstable S3 class, as_kstable(), kstable_from_json()
    │   ├── context.R         # ks_context S3 class (the DSL): compile_context(),
    │   │                     #   enrich_context(), save_context(), load_context()
    │   ├── semantic.R        # internal: .build_semantic_graph(), .extract_*() helpers
    │   ├── chat.R            # ks_chat() wrapper over ellmer
    │   ├── tools.R           # list_tables(), table_info(), show_rows() etc. as ellmer tools
    │   ├── skills.R          # ks_llm() dispatcher, .load_skill_prompt(), .fill_prompt()
    │   ├── interactive.R     # describe(), ask(), compare_tables(), summarize()
    │   └── constants.R       # Package-level constants (skill names, provider names)
    ├── inst/prompts/
    │   ├── system.md
    │   ├── describe.md
    │   ├── sap.md
    │   ├── adrg.md
    │   ├── qc.md
    │   ├── review.md
    │   ├── programmer.md
    │   └── validator.md
    ├── tests/testthat/
    │   ├── test-01-kstable.R
    │   ├── test-02-context.R
    │   ├── test-03-chat.R
    │   ├── test-04-skills.R
    │   └── test-05-interactive.R
    └── vignettes/
        └── Getting_Started_ksAI.Rmd

------------------------------------------------------------------------

## Implementation Phases

### Phase A — Package Skeleton & kstable Class

*Corresponds to doc Phases 1–2*

1.  Scaffold `ksAI` package using
    [`usethis::create_package()`](https://usethis.r-lib.org/reference/create_package.html)
    at `/Users/meguty/Develop/R/ksAI/`
    - DESCRIPTION:
      `Imports: ksTFL, ellmer, jsonlite, cli, checkmate, rlang`
    - Set `ksTFL` as a dependency (not Suggests)
2.  Implement `kstable` S3 class in `R/kstable.R`:
    - `as_kstable(x, ...)` — S3 generic
    - `as_kstable.TFL_spec(spec)` — extracts from live TFL_spec:
      - `$specification`: full TFL_spec minus `.metadata` (stripped)
      - `$data`: the data.frame from `spec$.metadata$data_env$__data__`;
        filtered to `spec$.metadata$report_cols`
      - `$context`: `ks_context` object produced by
        `compile_context.TFL_spec(spec)` (Phase B)
    - `kstable_from_json(meta_json_path, spec_key = NULL)` — loads from
      `save_report()` output:
      - Parses the report meta JSON (finds spec by `spec_key` or first
        spec)
      - Loads associated data JSON from `dataRef` path
      - Constructs kstable with same three fields
    - `print.kstable()`, `format.kstable()`, `is_kstable()` helpers
3.  Tests in `test-01-kstable.R`:
    - as_kstable from small example TFL_spec
    - kstable_from_json round-trip
    - \$context field is a ks_context object

### Phase B — `ks_context`: The Semantic DSL Class (render-join of spec + data)

*Corresponds to doc Phases 4–5*

This is the central artifact of the architecture. A `ks_context` object
is the **rendered join of specification and data** — not just metadata
extraction, but a complete, LLM-ready representation of what the table
actually shows.

ksTFL produces two artifacts separately: - **Specification**: column
labels, types, format strings, titles, footnotes, stub headers, span
headers - **Data**: raw R values (numeric/character) in
`spec$.metadata$data_env$__data__`

`compile_context()` is a **render-join operation** that: 1. Reads
structural metadata from `spec` (titles, columns, footnotes, etc.) 2.
Reads raw values from `spec$.metadata$data_env$__data__` (filtered to
`report_cols`) 3. Applies each column’s `format$type` +
`format$format` + `format$missings` via
[`sprintf()`](https://rdrr.io/r/base/sprintf.html) to render each cell
as a formatted string 4. Assembles the rendered rows together with the
structural metadata into a single `ks_context` object

**Schema of a `ks_context` object:**

    ks_context
    ├── type           "Table" | "Text" | "Figure"
    ├── title          character[]
    ├── subtitle       character[]
    ├── population     character(1)    # editable via enrich_context()
    ├── dataset        character(1)    # source data name
    ├── columns        list of {name, label, type, format_string}
    ├── span_headers   list of {label, cols[]}   ← from spec$stubColumns
    ├── rows           list of {                 ← RENDERED JOIN
    │     cells: {col_name: "formatted_value", ...}
    │     synthetic: FALSE                       ← TRUE if add_row action
    │   }
    ├── n_rows_total   integer    ← total rows before any truncation
    ├── statistics     character[]   ← heuristic from format strings
    ├── footnotes      character[]
    ├── annotations    named list    ← free-form user metadata
    └── warnings       character[]   ← truncation notices, inference failures

**Rendering logic** (internal
`.render_table_rows(data, columns_spec, report_cols)`): - For each
column `col` in `report_cols`: -
`type <- columns_spec[[col]]$format$type` (`"numeric"` \| `"string"`) -
`fmt <- columns_spec[[col]]$format$format` (e.g. `"%.1f"`, `"%d"`,
`"%s"`) - `miss <- columns_spec[[col]]$format$missings` (NA replacement
string) - Apply: `ifelse(is.na(raw), miss, sprintf(fmt, raw))`
(vectorized) - Assemble rows as named character lists:
`list(cells = list(TRT01P="Placebo", AGE="52.3", SEX="M"))` - Token
budget: if `nrow(data) > max_rows` (default 100), keep first `max_rows`
rows and add a warning to `ks_context$warnings`

4.  Implement `compile_context(x, ...)` S3 generic and methods in
    `R/context.R`:
    - `compile_context.TFL_spec(spec)` — full render-join from live
      spec:
      - Extracts structural metadata (titles, columns, footnotes,
        span_headers)
      - Calls `.render_table_rows()` on
        `spec$.metadata$data_env$__data__` filtered to
        `spec$.metadata$report_cols`
      - Returns `ks_context` with rendered `$rows`
    - `compile_context.kstable(kstable)` — delegates to
      `kstable$context` (already compiled, returns it directly)
    - `compile_context.character(path)` — loads from saved JSON via
      `load_context(path)` then returns the `ks_context`
    - Returns object with `class = c("ks_context", "list")`
5.  Implement persistence and enrichment in `R/context.R`:
    - `save_context(ctx, path)` —
      `jsonlite::toJSON(unclass(ctx), auto_unbox = TRUE)` → file;
      rendered rows are embedded, so no spec/data needed to reload
    - `load_context(path)` — reads JSON, restores `ks_context` class;
      self-contained
    - `enrich_context(ctx, population = NULL, dataset = NULL, annotations = list(), ...)`
      — non-mutating overlay; `annotations` merged (not replaced);
      returns new `ks_context`
    - `as_json(ctx)` — returns the JSON string for prompt injection
      (exported)
    - `print.ks_context()`,
      [`is_ks_context()`](https://crow16384.github.io/ksAI/reference/is_ks_context.md)
      helpers
6.  Internal helpers in `R/semantic.R` (not exported):
    - `.render_table_rows(data, columns_spec, report_cols, max_rows = 100L)`
      — the render-join core
    - `.extract_statistics_heuristic(columns_spec)` — infers stat names
      from format strings (e.g. `"%.1f (%.1f%%)"` → “mean (SD%)”)
    - `.build_semantic_graph(kstable)` — named concept-node list for
      tool functions
7.  Tests in `test-02-context.R`:
    - `compile_context()` produces `ks_context` with `$rows` containing
      formatted strings (not raw numerics)
    - Numeric column formatted with `%.1f` produces `"52.3"`, not `52.3`
    - NA values replaced by `missings` string from column spec
    - `save_context()` / `load_context()` round-trip: identical object,
      no spec/data file needed
    - [`enrich_context()`](https://crow16384.github.io/ksAI/reference/enrich_context.md)
      does not mutate original; annotations merged correctly
    - Truncation: \>100 rows adds warning to `$warnings`, `n_rows_total`
      preserved
    - `compile_context()` on text spec (no data) returns valid partial
      object with empty `$rows`

### Phase C — ellmer Integration & Chat Wrapper

*Corresponds to doc Phase 3*

8.  Implement `ks_chat(model, provider = "ollama", ...)` in `R/chat.R`:
    - Dispatches to
      [`ellmer::chat_ollama()`](https://ellmer.tidyverse.org/reference/chat_ollama.html),
      [`ellmer::chat_openai()`](https://ellmer.tidyverse.org/reference/chat_openai.html),
      [`ellmer::chat_anthropic()`](https://ellmer.tidyverse.org/reference/chat_anthropic.html),
      `ellmer::chat_lm_studio()` based on `provider`
    - Attaches a `kschat` subclass with `$registry` slot (named list: id
      → kstable)
    - Loads `inst/prompts/system.md` as system prompt on construction
    - `ks_chat_add_table(chat, kstable, id = NULL)` — registers a
      kstable into `chat$registry`; id defaults to
      `kstable$context$title[[1]]`
9.  Tests in `test-03-chat.R`:
    - ks_chat() creates correct ellmer backend (mock provider lookup)
    - Provider name validation fails fast with cli_abort()

### Phase D — R Tools for LLM

*Corresponds to doc Phase 6*

10. Implement tool functions in `R/tools.R`, each wrappable as
    [`ellmer::tool()`](https://ellmer.tidyverse.org/reference/tool.html):
    - `list_tables()` — names of registered kstables in `chat$registry`
    - `table_info(id)` — `as_json(chat$registry[[id]]$context)` (the DSL
      JSON)
    - `show_rows(id, n)` — head(kstable\$data, n) as markdown table
    - `show_columns(id)` — column metadata from `ks_context$columns`
    - `show_statistics(id)` — `ks_context$statistics`
    - `population_info(id)` — `ks_context$population`
    - `variable_info(id, name)` — single column entry from
      `ks_context$columns`
    - `show_json(id)` — full `$specification` as JSON string
    - `preview_data(id, n)` — markdown table from `$data`
    - `compare_tables(id1, id2)` — structural diff of two ks_context
      objects
11. `.register_tools(chat)` — attaches all tools to ellmer Chat via
    [`ellmer::tool()`](https://ellmer.tidyverse.org/reference/tool.html)
12. Tests in `test-03-chat.R` (extended):
    - table_info returns as_json output
    - compare_tables highlights structural differences

### Phase E — Prompt Library

*Corresponds to doc Phase 7*

13. Create `inst/prompts/` with 8 markdown files; placeholder syntax:
    `{{variable_name}}`
    - `system.md` — role, ksTFL context, hard constraints (never compute
      statistics)
    - `describe.md`, `sap.md`, `adrg.md`, `qc.md`, `review.md`,
      `programmer.md`, `validator.md`
14. Implement in `R/skills.R`:
    - `.load_prompt(skill_name)` — `system.file(...)` lookup, cli_abort
      on missing
    - `.fill_prompt(template, ...)` — replaces `{{key}}` with named
      values via [`gsub()`](https://rdrr.io/r/base/grep.html)

### Phase F — Skills Dispatcher

*Corresponds to doc Phase 8*

15. Implement `ks_llm(x, skill = "describe", chat = NULL, ...)` in
    `R/skills.R`:
    - `x` accepts `kstable` OR `ks_context` — if kstable, extracts
      `$context`; if ks_context, uses directly
    - Loads prompt, fills `{{context}}` with `as_json(ctx)`, `{{title}}`
      with `ctx$title[[1]]`
    - Creates a temporary
      [`ks_chat()`](https://crow16384.github.io/ksAI/reference/ks_chat.md)
      if `chat` is NULL
    - Supported skills: `"describe"`, `"sap"`, `"adrg"`, `"qc"`,
      `"review"`, `"programmer"`, `"validator"`
16. Tests in `test-04-skills.R`:
    - Accepts both kstable and ks_context as input
    - Unknown skill name errors
    - Prompt filling replaces all placeholders

### Phase G — Structured Outputs

*Corresponds to doc Phase 9*

17. Define JSON response schemas per skill in `R/skills.R`:
    - `describe_schema`:
      `{purpose, population, variables[], statistics[], comments[], warnings[]}`
    - `sap_schema`: `{section_title, wording, references[], notes[]}`
    - `qc_schema`: `{issues[], severity[], recommendations[]}`
18. `ks_llm(..., structured = TRUE)`:
    - Appends schema instruction to prompt + uses `chat$extract()` or
      JSON parsing
    - Returns named list when structured, plain character string
      otherwise

### Phase H — Interactive Table Assistant

*Corresponds to doc Phase 10*

19. Implement in `R/interactive.R` — all accept `kstable | ks_context`:
    - `describe(x, chat = NULL)` — `ks_llm(x, skill = "describe")`
    - `ask(x, question, chat = NULL)` — free-form Q&A appended to
      context
    - `summarize(x, audience = "clinician", chat = NULL)` — audience tag
      injected into prompt
    - `generate_sap(x, chat = NULL)` — `ks_llm(x, skill = "sap")`
    - `generate_adrg(x, chat = NULL)` — `ks_llm(x, skill = "adrg")`
    - `run_qc(x, chat = NULL)` —
      `ks_llm(x, skill = "qc", structured = TRUE)`
    - `compare_tables(x1, x2, chat = NULL)` — AI-narrated diff of two
      contexts
20. Tests in `test-05-interactive.R`:
    - Accepts both kstable and ks_context
    - audience parameter reaches prompt

### Phase I — Documentation & Vignette

*Corresponds to doc Phase 11*

21. Complete roxygen2 docs on all exported functions
22. Create `vignettes/Getting_Started_ksAI.Rmd`:
    - Create table with ksTFL → `as_kstable()` → `compile_context()` →
      `save_context()` (persist DSL)
    - Next session: `load_context()` →
      `enrich_context(population = "ITT")` → `describe()` / `ask()`
    - Shows DSL reuse without rebuilding from TFL_spec
23. [`devtools::document()`](https://devtools.r-lib.org/reference/document.html) +
    [`devtools::check()`](https://devtools.r-lib.org/reference/check.html)
    — 0 errors, 0 warnings

------------------------------------------------------------------------

## Relevant Files (ksTFL Reference)

- `R/spec_init.R` — TFL_spec structure; `.metadata` lives at
  `spec$.metadata`; data at `spec$.metadata$data_env$__data__`; report
  columns at `spec$.metadata$report_cols`
- `R/report_writer.R` — `save_report()` JSON format: top-level
  `_metadata` key + per-spec keys like `spec_key_hash_...`; data saved
  separately via `dataRef`
- `R/constants.R` — Schema property constants (reuse as reference for
  semantic extraction field names)
- `R/schema_serialize.R` — `.remove_nulls_recursive()` pattern reusable
  in ksAI
- `R/utility_functions.R` — `.render_table_rows()` formatting pattern:
  `sprintf(fmt, col)` with `missings` replacement

------------------------------------------------------------------------

## Verification

1.  [`devtools::test()`](https://devtools.r-lib.org/reference/test.html)
    — all tests pass (tests/testthat/)
2.  Manual: `as_kstable(create_table(iris, everything()))` produces
    valid kstable
3.  Manual: `kstable_from_json(save_report_output_path)` round-trips
    correctly
4.  Manual: `ks_chat(model = "qwen3:14b")` with Ollama running —
    `describe(table)` returns non-empty string
5.  Manual: `ks_llm(table, skill = "sap", structured = TRUE)` returns
    named list with `wording` field
6.  [`devtools::check()`](https://devtools.r-lib.org/reference/check.html)
    — 0 errors, 0 warnings (allow NOTE for new package)

------------------------------------------------------------------------

## Decisions

- `ksAI` package lives as sibling directory to ksTFL (not inside ksTFL
  repo)
- `ksTFL` gets **no changes** — ksAI registers `as_kstable.TFL_spec()`
  via importing ksTFL
- `ellmer` is `Imports` (hard dependency of ksAI, not Suggests)
- **`ks_context` is the rendered join of spec + data** — it embeds
  formatted cell values alongside structural metadata; it is
  self-contained and does not need the original TFL_spec or data file to
  be useful
- **`compile_context()` is a rendering operation** — it applies column
  `format$type`/`format$format`/`format$missings` via
  [`sprintf()`](https://rdrr.io/r/base/sprintf.html) to produce
  formatted strings, exactly as the C++ engine would; raw numeric values
  never appear in `ks_context$rows`
- **`kstable$data` holds raw data.frame** (for tool-use `show_rows()`,
  `preview_data()`); `kstable$context$rows` holds the rendered strings
- **`ks_context` is the stable unit of exchange** — compiled once, saved
  to disk, reused; avoids recompiling from TFL_spec on every session
- **[`ks_llm()`](https://crow16384.github.io/ksAI/reference/ks_llm.md)
  and all interactive functions accept `kstable | ks_context`** —
  passing a pre-compiled context bypasses recompilation entirely
- **Token budget**: default `max_rows = 100L` in compile_context;
  truncated tables add a warning; full data still accessible via
  `show_rows()` tool
- [`enrich_context()`](https://crow16384.github.io/ksAI/reference/enrich_context.md)
  is the approved mechanism for adding user knowledge (population, SAP
  ref) — no direct mutation of ks_context fields
- The `compare_tables()` in Phase D (tool) returns structured diff; in
  Phase H (interactive) uses LLM narration
- `.extract_statistics_heuristic()` infers stat names from format
  strings (e.g. `"%.1f (%.1f%%)"` → `"mean (SD%)"`)
- Prompt files use `{{variable}}` placeholder syntax; `.fill_prompt()`
  replaces via [`gsub()`](https://rdrr.io/r/base/grep.html)
- Offline-first design: default `provider = "ollama"`; cloud requires
  explicit opt-in

------------------------------------------------------------------------

## Out of Scope (for now)

- Define-XML documentation generation
- Semantic search across table registries
- Cross-study variable cross-referencing
- SAP diff (compare protocol versions)
- Any changes to ksTFL’s C++ engine
