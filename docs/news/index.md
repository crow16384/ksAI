# Changelog

## ksAI 0.3.0

### LLM-only content capsules

- [`as_capsules()`](https://crow16384.github.io/ksAI/reference/as_capsules.md)
  now forms capsules **only via an LLM** (small or large). Deterministic
  CDISC/domain/row-group formation has been removed. `model` is
  required.
- Capsules group whole **tables and figures** (`member_ids`) into a
  named semantic tree with multi-membership. Figure image assets are
  resolved on import and attached for vision-capable models (R does not
  interpret plots).
- New review helpers:
  [`capsule_tree()`](https://crow16384.github.io/ksAI/reference/capsule_tree.md),
  [`capsule_membership()`](https://crow16384.github.io/ksAI/reference/capsule_membership.md),
  [`review_capsules()`](https://crow16384.github.io/ksAI/reference/review_capsules.md),
  [`capsule_content()`](https://crow16384.github.io/ksAI/reference/capsule_content.md),
  [`ks_review_capsules()`](https://crow16384.github.io/ksAI/reference/ks_review_capsules.md),
  plus
  [`as_compact()`](https://crow16384.github.io/ksAI/reference/as_compact.md)
  /
  [`as_markdown()`](https://crow16384.github.io/ksAI/reference/as_markdown.md)
  methods for capsules.
- Prompts: `inst/prompts/capsule_classify.md`, `capsule_review.md`.
- [`ks_annotate()`](https://crow16384.github.io/ksAI/reference/ks_annotate.md)
  no longer reclassifies CDISC-like domains.
- Removed option `domain_map` and `llm_domain` / rule-based domain
  inference.

### Documentation

- Architecture and capsule pipeline docs describe content-based LLM
  capsules and figure vision attachment.
