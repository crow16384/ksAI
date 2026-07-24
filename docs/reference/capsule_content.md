# Detailed Member Content for One Capsule

Expands full member contexts from a live
[ks_study](https://crow16384.github.io/ksAI/reference/is_ks_study.md)
(not truncated build excerpts).

## Usage

``` r
capsule_content(store, capsule_id, study, format = c("compact", "markdown"))
```

## Arguments

- store:

  A `ks_capsule_store`.

- capsule_id:

  Capsule id.

- study:

  A `ks_study` containing the member contexts.

- format:

  `"compact"` or `"markdown"`.

## Value

Character scalar with concatenated member renders.
