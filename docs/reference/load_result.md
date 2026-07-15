# Load a saved ks_result

Loads a previously saved result. If both `.md` and `.json` exist, JSON
is used as the canonical source.

## Usage

``` r
load_result(path)
```

## Arguments

- path:

  Character scalar. Base path or `.md`/`.json` file path.

## Value

A
[ks_result](https://crow16384.github.io/ksAI/reference/is_ks_result.md)
object.
