# Persist a ks_result as Markdown and JSON

Writes both a human-readable Markdown file and a machine-readable JSON
file.

## Usage

``` r
save_result(result, path)
```

## Arguments

- result:

  A
  [ks_result](https://crow16384.github.io/ksAI/reference/is_ks_result.md)
  object.

- path:

  Character scalar. Output path base or path ending in `.md`/`.json`.

## Value

Invisibly, a list with `md` and `json` output paths.
