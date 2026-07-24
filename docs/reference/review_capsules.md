# Structural Audit of a Capsule Store

Offline checks (no LLM): empty capsules, unknown members, cycles,
orphans.

## Usage

``` r
review_capsules(store, study = NULL)
```

## Arguments

- store:

  A `ks_capsule_store`.

- study:

  Optional `ks_study` for catalog membership checks.

## Value

A `ks_capsule_review` list with findings.
