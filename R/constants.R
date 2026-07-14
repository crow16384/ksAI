## Package-level constants for ksAI.
##
## These are internal (not exported) and provide stable reference values used
## across the import, chat, tools, and skills modules.

# ---------------------------------------------------------------------------
# Study sizing
# ---------------------------------------------------------------------------

# Studies with this many outputs or fewer inject all table contexts directly
# into the system prompt (small-study mode). Larger studies switch to
# tool-based retrieval (large-study mode). Overridable via
# ks_set_option("study_threshold", N).
SMALL_STUDY_THRESHOLD <- 20L

# ---------------------------------------------------------------------------
# ksTFL document types (mirror of ksTFL::.const_doc_types)
# ---------------------------------------------------------------------------

.KS_DOC_TYPES <- c("Table", "Figure", "Text")

# ---------------------------------------------------------------------------
# LLM providers supported via ellmer
# ---------------------------------------------------------------------------

.KS_PROVIDERS <- c("ollama", "lm_studio", "openai", "anthropic")

# ---------------------------------------------------------------------------
# Built-in CSR-writing skills (shipped in inst/prompts/)
# ---------------------------------------------------------------------------

.KS_BUILTIN_SKILLS <- c("describe", "summarize", "csr_section", "review")

# The system prompt is a special template, not a user-facing skill.
.KS_SYSTEM_PROMPT <- "system"
.KS_STUDY_INDEX_PROMPT <- "study_index"
# Focused system prompt for single-output skills (no whole-study context).
.KS_SINGLE_SYSTEM_PROMPT <- "system_single"

# ---------------------------------------------------------------------------
# Invisible control columns emitted by ksTFL table programs
# ---------------------------------------------------------------------------

# These columns carry row-level metadata rather than displayed values.
.KS_CONTROL_COLS <- c("SECTION", "ROW_KIND", "BREAK_BEFORE")

# File extension for a persisted ksAI study.
.KS_STUDY_EXT <- "ks"
