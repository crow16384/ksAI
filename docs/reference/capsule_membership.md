# Capsule Membership Table

Capsule Membership Table

## Usage

``` r
capsule_membership(store, study = NULL)
```

## Arguments

- store:

  A `ks_capsule_store`.

- study:

  Optional `ks_study` to include catalog ids with zero membership.

## Value

A data.frame with columns `output_id`, `capsule_id`, `label`,
`n_capsules`.
