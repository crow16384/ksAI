# Retrieve Relevant Clinical Capsules

Scores capsules against a query using embedding similarity, keyword
overlap, and metadata matching, then returns the top-ranked subset.

## Usage

``` r
ks_retrieve(
  store,
  query,
  n = 5L,
  filter = list(),
  weights = list(semantic = 0.6, keyword = 0.3, metadata = 0.1),
  model = ks_get_option("embed_model"),
  base_url = ks_get_option("embed_url")
)
```

## Arguments

- store:

  A `ks_capsule_store`.

- query:

  User question or retrieval query.

- n:

  Maximum number of capsules to return.

- filter:

  Optional named list with any of: `label`, `population`, `member_id`
  (output id that must be among capsule members).

- weights:

  Named numeric list with `semantic`, `keyword`, `metadata`.

- model:

  Embedding model for query embedding.

- base_url:

  Embedding endpoint base URL.

## Value

A `ks_capsule_subset`.
