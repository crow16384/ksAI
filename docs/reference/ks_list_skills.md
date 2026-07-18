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
#>                                                                                                                       path
#> 1 /private/var/folders/rn/3s0h46m118j426j_fmjr1z8m0000gn/T/Rtmp7N6wAC/temp_libpath610414b022a9/ksAI/prompts/csr_section.md
#> 2    /private/var/folders/rn/3s0h46m118j426j_fmjr1z8m0000gn/T/Rtmp7N6wAC/temp_libpath610414b022a9/ksAI/prompts/describe.md
#> 3      /private/var/folders/rn/3s0h46m118j426j_fmjr1z8m0000gn/T/Rtmp7N6wAC/temp_libpath610414b022a9/ksAI/prompts/review.md
#> 4   /private/var/folders/rn/3s0h46m118j426j_fmjr1z8m0000gn/T/Rtmp7N6wAC/temp_libpath610414b022a9/ksAI/prompts/summarize.md
```
