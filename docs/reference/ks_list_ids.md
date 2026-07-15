# List Available Output IDs in a Meta Folder or `.ks` File

For a ksTFL meta folder, this scans spec metadata and returns available
output ids without loading table data. For a saved `.ks` file, ids are
read from the serialized study payload.

## Usage

``` r
ks_list_ids(path, latest_only = TRUE)
```

## Arguments

- path:

  Character scalar. ksTFL meta folder or `.ks` file.

- latest_only:

  Logical. When reading a meta folder, keep only reports marked as
  latest if the index carries `is_latest`.

## Value

Data frame with columns `id`, `type`, and `title`.

## Examples

``` r
if (FALSE) { # \dontrun{
ids <- ks_list_ids("path/to/outputs/meta")
ids
} # }
```
