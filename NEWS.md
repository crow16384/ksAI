# ksAI 0.3.0

## LLM-only content capsules

* `as_capsules()` now forms capsules **only via an LLM** (small or large).
  Deterministic CDISC/domain/row-group formation has been removed. `model` is
  required.
* Capsules group whole **tables and figures** (`member_ids`) into a named
  semantic tree with multi-membership. Figure image assets are resolved on
  import and attached for vision-capable models (R does not interpret plots).
* New review helpers: `capsule_tree()`, `capsule_membership()`,
  `review_capsules()`, `capsule_content()`, `ks_review_capsules()`, plus
  `as_compact()` / `as_markdown()` methods for capsules.
* Prompts: `inst/prompts/capsule_classify.md`, `capsule_review.md`.
* `ks_annotate()` no longer reclassifies CDISC-like domains.
* Removed option `domain_map` and `llm_domain` / rule-based domain inference.

## Documentation

* Architecture and capsule pipeline docs describe content-based LLM capsules
  and figure vision attachment.
