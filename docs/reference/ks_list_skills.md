# List Available Skills

Returns the CSR-writing skills available to
[`ks_llm()`](https://crow16384.github.io/ksAI/reference/ks_llm.md),
combining the package built-ins with any user skills in
`ks_get_option("skills_dir")`. User skills shadow built-ins of the same
name.

## Usage

``` r
ks_list_skills()
```

## Value

A data frame with columns `name`, `source` (`"user"` or `"built-in"`),
and `path`.

## Examples

``` r
ks_list_skills()
#>          name   source
#> 1 csr_section built-in
#> 2    describe built-in
#> 3      review built-in
#> 4   summarize built-in
#>                                                                    path
#> 1 /Users/meguty/Library/R/arm64/4.6/library/ksAI/prompts/csr_section.md
#> 2    /Users/meguty/Library/R/arm64/4.6/library/ksAI/prompts/describe.md
#> 3      /Users/meguty/Library/R/arm64/4.6/library/ksAI/prompts/review.md
#> 4   /Users/meguty/Library/R/arm64/4.6/library/ksAI/prompts/summarize.md
```
