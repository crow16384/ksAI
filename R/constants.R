## Package-level constants for ksAI.
##
## These are internal (not exported) and provide stable reference values used
## across the import, chat, tools, and skills modules.

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

# ---------------------------------------------------------------------------
# Invisible control columns emitted by ksTFL table programs
# ---------------------------------------------------------------------------

# These columns carry row-level metadata rather than displayed values.
.KS_CONTROL_COLS <- c("SECTION", "ROW_KIND", "BREAK_BEFORE")

# File extension for a persisted ksAI study.
.KS_STUDY_EXT <- "ks"
