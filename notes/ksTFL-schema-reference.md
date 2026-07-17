# ksTFL JSON Schema Reference
# Verified against: inst/schemas/spec_schema_v2.json + tests/testthat/helper-fixtures.R
# ksTFL version: 0.11.x

## Output: Two Separate Files per Report

save_report() writes to `metaPath/`:
  {hash}.json          — spec file (metadata, column definitions, layout)
  {data_ref}.json      — data file (columnar cell values)
  _index.json          — index of all specs in the folder

---

## Spec JSON

### Top-level shape
```json
{
  "_metadata": {
    "outDir":      "string",
    "docFileName": "string",
    "datetime":    "2026-07-05T18:00:00",
    "insertTOC":   false,
    "tocTitle":    "string"
  },
  "table_spec_name_0123456789abcdef": { ... },
  "figure_spec_name_0123456789abcdef": { ... }
}
```

Per-spec key pattern: `^[A-Za-z0-9][A-Za-z0-9_.-]*_[a-f0-9]{16}$`

### Per-spec entry fields

```
document        {docType, hasData, docOrder, isContinues, contentWidth, ...}
  docType:      "Table" | "Figure" | "Text"
  hasData:      true/false  — when false, bodyText shown instead of table

attribs         page/style definitions (OPAQUE — never parsed by ksAI)

dataRef         ["data_ref_name"]  single-element array, base name of data JSON

headers         [ ["left", "center", "right"], ... ]
  Population:   found in headers[0][0] as "Population: ITT"

footers         [ ["left", "center", "right"], ... ]
  Source:       found in footers[0][0] as "Source: tfl-programs/t.R"

titles          { entry_id: { text: ["line1","line2"], order: 1, toclevel: 1|null } }

subtitles       { entry_id: { text: [...], order: 1 } }
  NOTE: ksAI import.R does NOT yet extract subtitles — gap to address

footnotes       { entry_id: { text: [...], order: 1 } }

stubColumns     { stub_id: { label: "Drug A (N=121)", cols: ["MEAN01","SD01","N01"],
                              stubOrder: 0, labelStyleRef: [...] } }
  -> becomes ks_context$span_headers

columns         { col_id: { ... } }   see below

styleRows       ["...", ...]   OPAQUE — rendering instructions, never parsed by ksAI

bodyText        { ... }  placeholder text when hasData=false

figure          { width, height, aspectRatio, figureScaleMode, device }
  device:       "png" | "jpeg" | "jpg" | "svg"
```

### Column definition schema (`columns[col_id]`)

```
colOrder        integer   position (sort ascending to get display order)
label           string    display label; may contain HTML (<br>, <sup>, etc.)
isVisible       bool|null default true  — false -> control column, excluded from display
isGrouping      bool|null default false — true -> categorical dimension (e.g. visit, group)
isPaging        bool|null default false — defines page breaks
isID            bool|null default false — repeat on multi-page
isColBreak      bool|null default false — split to next page at this column
dedupe          bool|null             — remove duplicate values in display
labelStyleRef   [...string]           OPAQUE

format:
  type          "string" | "numeric"   CRITICAL for column classification
  format        sprintf format string  e.g. "%.1f", "%d", "%s"
  missings      string                 display token for NA values, e.g. "" or "NA"
  colWidth      "5in" | "10%" | ...    OPAQUE (rendering only)
  valueStyleRef [...string]            OPAQUE
```

### Concrete column examples (from fixture)

```json
"SECTION": {
  "colOrder": 1, "label": "SECTION", "isVisible": false,
  "format": {"type": "string", "format": "%s", "missings": ""}
}
"ROW_LABEL": {
  "colOrder": 2, "label": "", "isVisible": true,
  "format": {"type": "string", "format": "%s", "missings": ""}
}
"ROW_KIND": {
  "colOrder": 3, "label": "ROW_KIND", "isVisible": false,
  "format": {"type": "string", "format": "%s", "missings": ""}
}
"PLACEBO": {
  "colOrder": 4, "label": "Placebo<br>(N=79)", "isVisible": true,
  "format": {"type": "string", "format": "%s", "missings": ""}
}
"COUNT": {
  "colOrder": 5, "label": "N", "isVisible": true,
  "format": {"type": "numeric", "format": "%.1f", "missings": "NA"}
}
```

---

## Data JSON

### Format: columnar, `auto_unbox = FALSE` (all values in arrays)

```json
{
  "SECTION":   ["Baseline", "Baseline", "Week 24"],
  "ROW_LABEL": ["n",        "Mean (SD)", "n"],
  "ROW_KIND":  ["detail",   "detail",    "detail"],
  "PLACEBO":   ["79",       "24.1 (12.19)", "79"],
  "COUNT":     [79,          24.1,           null]
}
```

Column names must match spec `columns` keys exactly (case-sensitive).

### Value types

| `format.type` | JSON type   | Notes |
|---------------|-------------|-------|
| `"string"`    | string array | Pre-formatted display values — NOT raw data |
| `"numeric"`   | number array | Raw values; ksAI applies `sprintf(format, x)` |
| (either)      | `null`      | Missing; mapped to `format.missings` token |

**Important**: `type="string"` visible columns may contain pre-formatted
display strings like `"24.1 (12.19)"`. They are **not** categorical
dimensions even though they are strings.

---

## Column Classification Rules (for CKR fact store)

```
isVisible = FALSE
  → control column
  → if name == "SECTION":  row.section in ks_context
  → if name == "ROW_KIND": row.kind in ks_context
  → all others: ignored

isVisible = TRUE, lowest colOrder
  → row_label column (parameter name, e.g. "Age", "Weight")
  → dictionary-encode in ks_facts

isVisible = TRUE, isGrouping = TRUE
  → dimension column (categorical: visit, treatment group identifier)
  → dictionary-encode in ks_facts

isVisible = TRUE, all remaining
  → measure column (display values, formatted or raw-then-formatted)
  → store as strings in ks_facts — no dictionary encoding
```

---

## stubColumns → span_headers Mapping

```
stubColumns entry         ks_context$span_headers entry
─────────────────────────────────────────────────────────
label                  →  label
cols                   →  cols   (list of column IDs in that span)
stubOrder              →  (sort order)
```

Used to group measure columns by treatment arm / visit group in
`as_compact()` and `as_compact.ks_facts()`.

---

## _index.json (meta folder index)

```json
[
  {
    "spec_file":  "spec_data_ref_01.json",
    "doc_file":   "14-3.01.docx",
    "datetime":   "2026-07-05T18:00:01",
    "n_specs":    1,
    "data_refs":  ["data_ref_01"]
  }
]
```

`data_refs` may be flattened to a matrix by `jsonlite` when all rows
have the same length — `meta_management.R` normalises this.

---

## Known ksAI Parsing Gaps

| Gap | File | Impact |
|-----|------|--------|
| `subtitles` not extracted | `R/import.R` | Missing subtitle lines in `as_compact()` output |
| `document.hasData` not checked | `R/import.R` | May try to parse data for empty tables |
| `bodyText` not handled | `R/import.R` | Text-type outputs with no data miss placeholder text |
