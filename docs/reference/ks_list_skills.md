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
#>          name   source                                                     path
#> 1 csr_section built-in /Users/meguty/Develop/R/ksAI/inst/prompts/csr_section.md
#> 2    describe built-in    /Users/meguty/Develop/R/ksAI/inst/prompts/describe.md
#> 3      review built-in      /Users/meguty/Develop/R/ksAI/inst/prompts/review.md
#> 4   summarize built-in   /Users/meguty/Develop/R/ksAI/inst/prompts/summarize.md
```
