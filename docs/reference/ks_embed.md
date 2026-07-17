# Embed Capsule Texts

Calls an OpenAI-compatible embeddings endpoint (e.g., LM Studio) for
each capsule's compact text and stores numeric vectors in
`capsule$embedding`.

## Usage

``` r
ks_embed(
  store,
  model = ks_get_option("embed_model"),
  base_url = ks_get_option("embed_url"),
  force = FALSE
)
```

## Arguments

- store:

  A `ks_capsule_store`.

- model:

  Embedding model name.

- base_url:

  Embedding endpoint base URL.

- force:

  Re-embed capsules even if an embedding already exists.

## Value

Updated `ks_capsule_store`.
