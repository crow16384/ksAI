# Save a Study to a `.ks` File

Serialises a
[ks_study](https://crow16384.github.io/ksAI/reference/is_ks_study.md)
(with all embedded contexts) to a self-contained JSON file. Reload with
[`ks_load()`](https://crow16384.github.io/ksAI/reference/ks_load.md).
The original ksTFL meta folder is not needed to reload.

## Usage

``` r
save_study(study, path)
```

## Arguments

- study:

  A
  [ks_study](https://crow16384.github.io/ksAI/reference/is_ks_study.md)
  object.

- path:

  Character scalar. Output path; a `.ks` extension is added if missing.

## Value

Invisibly, the normalised path written.

## Examples

``` r
if (FALSE) { # \dontrun{
study <- ks_load("path/to/outputs/meta", ids = c("14-3.01"))
save_study(study, "my_study.ks")
study2 <- ks_load("my_study.ks")
} # }
```
