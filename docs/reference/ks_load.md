# Load Selected Outputs from a ksTFL Meta Folder or `.ks` File

Loads only the requested output ids into a
[ks_study](https://crow16384.github.io/ksAI/reference/is_ks_study.md)
object.

## Usage

``` r
ks_load(
  path,
  ids = NULL,
  latest_only = TRUE,
  max_rows = ks_get_option("max_rows")
)
```

## Arguments

- path:

  Character scalar. ksTFL meta folder or `.ks` file.

- ids:

  Optional character vector of output ids to load. If `NULL`, all
  available outputs are loaded.

- latest_only:

  Logical. When reading a meta folder, keep only reports marked as
  latest if the index carries `is_latest`.

- max_rows:

  Integer. Maximum table rows embedded per context.

## Value

A [ks_study](https://crow16384.github.io/ksAI/reference/is_ks_study.md)
object containing only the selected outputs.

## Examples

``` r
if (FALSE) { # \dontrun{
study <- ks_load("path/to/outputs/meta", ids = c("14-3.01", "14-3.02"))
} # }
```
