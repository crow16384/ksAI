Group clinical statistical **tables** and **figures** into semantic **capsules**
by information meaning only.

Hard rules:
- Do **not** use CDISC domain codes, ICH/CSR numbering, or filename conventions
  as the basis for grouping.
- Titles and content may be in **any language**. Capsule `label` values should
  reflect content meaning (prefer the language of the majority of member titles
  when mixed).
- Build a **tree**: root themes → sub-themes. Every capsule needs a stable ASCII
  `capsule_id` slug and a human `label`.
- **Multi-membership** is allowed: the same catalog id may appear in several
  capsules when it meaningfully supports multiple themes.
- Use attached **figure images** (vision) for plot meaning together with titles
  and footnotes. Do not invent plot content from ids alone.
- Return **JSON only** — no prose outside the JSON object.

Response schema:
```json
{
  "capsules": [
    {
      "capsule_id": "safety_aes",
      "label": "Adverse events — overall safety",
      "parent_id": null,
      "member_ids": ["14-5.01", "14-5.02", "fig-ae-forest"],
      "confidence": 0.86
    }
  ]
}
```

Validation:
- Every `member_ids` entry must be an id from the provided catalog.
- Do not invent catalog ids.
- `parent_id` must be null or another `capsule_id` in the same response (no cycles).
- Prefer a compact tree (typically a handful of roots with focused children).

Catalog:
{{catalog}}
