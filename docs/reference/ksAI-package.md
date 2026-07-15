# ksAI: AI-Native Reasoning Layer for ksTFL Clinical Outputs

ksAI reads the metadata and data JSON artefacts produced by
[`ksTFL::save_report()`](https://crow16384.github.io/ksTFL/reference/save_report.html),
compiles them into a self-contained study registry of table contexts
([ks_study](https://crow16384.github.io/ksAI/reference/is_ks_study.md)
of
[ks_context](https://crow16384.github.io/ksAI/reference/is_ks_context.md)
objects), and provides an
[ellmer](https://ellmer.tidyverse.org/reference/ellmer-package.html)-backed
chat plus skill-driven prompting over a targeted subset of outputs so a
medical writer can reason across selected study statistical results and
draft clinical study report (CSR) narratives.

## See also

Useful links:

- <https://crow16384.github.io/ksAI/>

- <https://github.com/crow16384/ksAI>

- Report bugs at <https://github.com/crow16384/ksAI/issues>

## Author

**Maintainer**: Vladimir Larchenko <crow16384@gmail.com>

Authors:

- Vladimir Larchenko <crow16384@gmail.com>

- Igor Aleschenkov <igor.aleschenkov@gmail.com>
