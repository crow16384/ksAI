# ksAI 0.2.0

## Domain inference (language-agnostic)

* `as_capsules()` now infers clinical domain codes with a priority chain that
  works for non-English titles: `enrich_context(annotations$domain)`, session
  `domain_map`, MedDRA `ROW_KIND` structure, multilingual lexicon, ICH/CSR-style
  output ids, then `"UNKNOWN"`.
* New option `domain_map` (`ks_get_option()` / `ks_set_option()`): named
  character vector of exact output ids or regex → domain.
* Bare English `"baseline"` is no longer mapped to `DM`.

## Optional small-LLM domain classification

* `as_capsules(x, model = ..., provider = ..., base_url = ...,
  llm_domain = c("unknown","always","never"), llm_min_confidence = 0.5)`
  can call a small local model once per table (chat reused across a study).
* `ks_annotate(..., force_domain = FALSE, llm_min_confidence = 0.5)` with
  `model` set also reclassifies remaining `UNKNOWN` domains (once per
  `source_id`). Use `force_domain = TRUE` to reclassify every table.
* Closed codes: `AE`, `DM`, `VS`, `LB`, `EFFC`, `EX`, `DS`, `UNKNOWN`
  (plus common aliases).

## Documentation

* Architecture, Capsule Pipeline Pilot, and Targeted Workflow articles updated
  for the new parameters and domain flow.
