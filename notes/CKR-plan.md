# CKR — Clinical Knowledge Representation for ksTFL Outputs

## TL;DR

Build a token-efficient, retrieval-capable AI representation layer on top of
existing `ks_context` objects.

**The core problem**: ksTFL already separates metadata (spec JSON) from data
(data JSON). ksAI currently re-merges them into verbose rendered rows. When
sent to an LLM via `as_markdown()` or `as_json()`, column names repeat for
every row and the full table is sent even when only a subset is relevant.

**The solution**: A three-layer CKR stack — compact text → fact store →
retriever — wired into `ks_llm()` via a `context_format` option.

**C++23 enforced** for the retrieval engine (not targeting CRAN).

---

## Architecture

```
ks_context  (existing, unchanged)
     │
     ├─── as_compact()          Phase 1  Pure R, ~70% fewer tokens
     │
     ├─── as_facts()            Phase 2  C++23 FactTable via Rcpp::XPtr
     │         │
     │         └─── retrieve()  Phase 3  Structured dimension filter
     │                   │
     │                   └─── as_compact.ks_facts()
     │
     └─── ks_llm(context_format=)  Phase 4  Wires all formats in
```

---

## Phases

### Phase 1 — `as_compact()`: Compact DSL Text Format
**No dependencies. Pure R. Implement first.**

**Target output format:**
```
TABLE: 14-3.01 | Population: ITT
TITLE: Table 14.2.1 — Demographic Characteristics

[Baseline Characteristics]
Age (years):  Drug A: N=121, Mean=63.2, SD=11.5  |  Placebo: N=118, Mean=61.7, SD=10.8
Weight (kg):  Drug A: N=121, Mean=72.1, SD=14.2  |  Placebo: N=118, Mean=70.9, SD=13.8

Footnotes:
- Values are mean (SD) unless otherwise noted.
```

**Changes to `R/context.R`:**
- Add `as_compact()` S3 generic (exported)
- Add `as_compact.ks_context(x, ...)`:
  - `.compact_header_block(x)` — type/id/population/title lines
  - `.compact_rows_block(x)` — with or without `span_headers`:
    - **With** `span_headers`: iterate sections → row_labels → one line per row_label with all spans grouped: `row_label:  Span1: col=val, col=val  |  Span2: col=val, col=val`
    - **Without** `span_headers`: one-time column-label header line + pipe-delimited rows
  - Footnote block at end
- Export `as_compact` in `NAMESPACE`

**Also**: `as_compact.ks_context()` should include `subtitles` if they were
parsed (currently `import.R` does not extract `subtitles` from spec — noted
as a gap in Phase 1).

---

### Phase 2 — C++23 `FactTable` + `ks_facts` S3 Class
**Parallel with Phase 1.**

**New files and DESCRIPTION changes:**
```
src/Makevars         CXX_STD = CXX23
src/Makevars.win     CXX_STD = CXX23
src/ks_facts.h       C++23 class definitions
src/ks_facts.cpp     C++23 implementation + Rcpp exports
DESCRIPTION          LinkingTo: Rcpp
                     SystemRequirements: C++23
```

**C++23 classes in `src/ks_facts.h` / `src/ks_facts.cpp`:**

```cpp
// Dictionary: bidirectional string <-> uint32_t encoding
class Dictionary {
    std::flat_map<std::string, uint32_t> value_to_idx;  // C++23
    std::vector<std::string>             idx_to_value;
public:
    uint32_t     lookup(std::string_view v);   // insert-if-new
    std::string_view decode(uint32_t idx) const;
    uint32_t     size() const;
    Rcpp::CharacterVector to_r() const;
};

// FactTable: columnar storage for one ks_context's rows
class FactTable {
    // dict-encoded columns
    std::vector<uint32_t>  row_label_col;     // first visible col by colOrder
    std::vector<int32_t>   section_col;       // -1 = no section
    std::vector<int32_t>   kind_col;          // -1 = no kind
    std::unordered_map<std::string, std::vector<uint32_t>>    dim_cols;     // isGrouping=TRUE
    // raw string columns (pre-formatted measure values)
    std::unordered_map<std::string, std::vector<std::string>> measure_cols;
    // dictionaries for encoded cols
    Dictionary row_label_dict;
    Dictionary section_dict;
    Dictionary kind_dict;
    std::unordered_map<std::string, Dictionary> dim_dicts;
public:
    Rcpp::List to_r_list() const;
    std::size_t n_rows() const;
};

// InvertedIndex: efficient row-subset lookup
class InvertedIndex {
    std::unordered_map<uint32_t, std::vector<uint32_t>> row_label_idx;
    std::unordered_map<uint32_t, std::vector<uint32_t>> section_idx;
public:
    void build(const FactTable& ft);
    // returns sorted row indices matching all filters
    std::vector<uint32_t> query(
        const std::vector<uint32_t>& row_label_ids,
        const std::vector<int32_t>&  section_ids
    ) const;  // uses std::ranges::set_intersection (C++23)
};

// QueryResult: safe error-carrying return type (C++23)
using QueryResult = std::expected<std::vector<uint32_t>, std::string>;
```

**Rcpp exports** (`// [[Rcpp::export]]`):
```cpp
SEXP ks_build_fact_table(SEXP rows_list, SEXP schema_list);
// -> Rcpp::XPtr<std::pair<FactTable, InvertedIndex>>

SEXP ks_query_facts(SEXP ptr, SEXP row_label_values, SEXP section_values);
// -> Rcpp::List (columnar subset, same shape as input)

Rcpp::List ks_decode_facts(SEXP ptr);
// -> data.frame with human-readable strings (for as_compact / print)

Rcpp::List ks_get_dictionaries(SEXP ptr);
// -> named list of character vectors (for R-side span filtering)
```

**`R/facts.R`:**
```r
# S3 class wrapping XPtr
new_ks_facts <- function(ptr, id, meta, schema, span_map, col_labels) { ... }

# Column classification (uses ks_context$columns)
# isVisible=FALSE     -> control (SECTION, ROW_KIND)
# first visible colOrder -> row_label_col (dict-encode)
# isGrouping=TRUE + isVisible=TRUE -> dim_col (dict-encode)
# all other visible -> measure_cols (store as string, no dict)
.classify_columns <- function(columns) { ... }

# Build R-side dict seed lists from ks_context$rows, pass to C++
.build_dict_r <- function(rows, schema) { ... }

as_facts <- function(x, ...) UseMethod("as_facts")
as_facts.ks_context <- function(x, ...) {
  schema   <- .classify_columns(x$columns)
  dict_r   <- .build_dict_r(x$rows, schema)
  ptr      <- ks_build_fact_table(.rows_to_list(x$rows, schema), schema)
  span_map <- .extract_span_map(x)
  col_lbls <- .extract_col_labels(x$columns, schema)
  new_ks_facts(ptr, x$id,
               meta     = list(title=x$title, population=x$population, footnotes=x$footnotes),
               schema   = schema,
               span_map = span_map,
               col_labels = col_lbls)
}

is_ks_facts <- function(x) inherits(x, "ks_facts")
print.ks_facts <- function(x, ...) { ... }
```

---

### Phase 3 — `retrieve()`: Structured Dimension Filter
**Depends on Phase 2.**

```r
retrieve <- function(x, ...) UseMethod("retrieve")

retrieve.ks_facts <- function(x,
                               rows     = NULL,   # character: row_label values
                               sections = NULL,   # character: section values
                               spans    = NULL,   # character: span_header labels
                               ...) {
  # 1. Decode string filters -> integer IDs via dictionaries
  # 2. Call ks_query_facts(x$ptr, row_ids, section_ids) -> columnar subset XPtr
  # 3. If spans given: filter measure_cols to only those in span_map[spans]
  # 4. Return filtered ks_facts (new XPtr)
}

as_compact.ks_facts <- function(x, ...) {
  # ks_decode_facts(x$ptr) -> readable data frame
  # Group by section / row_label / span_header
  # Render same compact DSL format as as_compact.ks_context()
}
```

---

### Phase 4 — Integration into `ks_llm()`
**Depends on Phase 1. Phases 2–3 optional (compact only is sufficient).**

**`R/ksAI.R`** — add to `.KS_DEFAULT_OPTIONS`:
```r
"context_format" = "markdown"
```

**`R/skills.R`** — changes:
1. Add `context_format = ks_get_option("context_format")` arg to `ks_llm()`
2. Rename `.concat_markdown_contexts()` → `.render_contexts(contexts, format)`:
   ```r
   .render_contexts <- function(contexts, format = "markdown") {
     renderer <- switch(format,
       markdown = as_markdown,
       compact  = as_compact,
       json     = as_json,
       as_markdown  # default fallback
     )
     blocks <- vapply(names(contexts), function(id) {
       sep <- if (identical(format, "compact")) "---" else paste0("### Output ", id)
       paste0(sep, "\n\n", renderer(contexts[[id]]))
     }, character(1))
     paste(blocks, collapse = "\n\n")
   }
   ```
3. Replace all `as_markdown(contexts[[...]])` call sites with `.render_contexts()`

---

## Files to Create / Modify

| File | Action | Phase |
|------|--------|-------|
| `R/context.R` | Add `as_compact()` generic + `as_compact.ks_context()` | 1 |
| `R/facts.R` | New: `ks_facts`, `as_facts()`, `retrieve()`, `as_compact.ks_facts()` | 2–3 |
| `src/ks_facts.h` | New: C++23 class declarations | 2 |
| `src/ks_facts.cpp` | New: C++23 implementation + Rcpp exports | 2 |
| `src/Makevars` | New: `CXX_STD = CXX23` | 2 |
| `src/Makevars.win` | New: `CXX_STD = CXX23` | 2 |
| `R/skills.R` | Update `ks_llm()` + `.concat_markdown_contexts()` | 4 |
| `R/ksAI.R` | Add `"context_format"` to `.KS_DEFAULT_OPTIONS` | 4 |
| `DESCRIPTION` | Add `LinkingTo: Rcpp`, `SystemRequirements: C++23` | 2 |
| `NAMESPACE` | Export `as_compact`, `as_facts`, `retrieve`, `is_ks_facts` | 1–3 |

---

## Verification Checklist

- [ ] `nchar(as_compact(ctx)) < nchar(as_markdown(ctx))` — expect ≥30% reduction
- [ ] `as_facts(ctx) |> retrieve() |> as_compact()` round-trip — all values present
- [ ] `retrieve(x, rows = "Age")` returns only Age rows (no Weight/BMI)
- [ ] `retrieve(x, spans = "Drug A")` drops all Placebo measure columns
- [ ] `ks_llm(study, ids = "14-3.01", context_format = "compact")` completes without error; response references correct values
- [ ] `ks_llm(study, ids = "14-3.01")` (no `context_format`) still uses `as_markdown()` — backwards compat

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| `ks_facts` built from `ks_context`, not raw ksTFL JSON | No re-parsing; offline-safe |
| Column classifier uses `isGrouping` flag, not `type` | `type="string"` visible cols are pre-formatted measure values, NOT dims |
| Dictionary uses `std::flat_map` (C++23) | Cache-friendly sorted structure for small-to-medium cardinality |
| `retrieve()` returns filtered `ks_facts` (not `data.frame`) | Enables `as_compact()` to chain naturally |
| `context_format` default `"markdown"` | Full backwards compatibility |
| C++23 enforced; `CXX_STD = CXX23` in `src/Makevars` | Not targeting CRAN |
| `subtitles` gap: `import.R` does not yet extract spec `subtitles` | `as_compact()` should handle if/when added to `ks_context` |

---

## Out of Scope

- Embedding / vector store indexing (ChatGPT Step 11)
- Graph-based retrieval (ChatGPT Step 6)
- Natural language query parsing (structured-only retrieval chosen)
- ksTFL source changes
- Bitset indexes (add if large-study benchmarks show need)
