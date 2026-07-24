## Complete ksAI workflow demo — bundled pilot study (LM Studio)
##
## Run from an installed package:
##   Rscript system.file("examples", "pilot-study-workflows.R", package = "ksAI")
## Or from a development checkout:
##   Rscript inst/examples/pilot-study-workflows.R
##
## Prerequisites (LM Studio, local server on http://127.0.0.1:1234):
##   - qwen3.5-4b (or similar 4B) — domain classification + capsule annotation
##   - a larger chat model          — skills + ks_reason
##   - text-embedding-nomic-embed-text-v1.5 — embedding model (retrieval)
##
## Bundled data: inst/examples/pilot-study/meta (ksTFL save_report output).
##
## Workflows demonstrated:
##   A. Direct context  — ks_llm() on targeted tables (compact format)
##   B. Structured facts — as_facts() + retrieve() for row-level filtering
##   C. Capsule pipeline — as_capsules → annotate → embed → retrieve → reason
##      (model= required; Option A = small context / Option B = large n_ctx)
##   D. Result chaining — save_result() / load_result() + prior =

suppressPackageStartupMessages({
  library(cli)
})

# Load package: development tree or installed build.
if (file.exists("DESCRIPTION") && grepl("^Package:\\s*ksAI", readLines("DESCRIPTION", n = 1))) {
  if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all(quiet = TRUE)
  } else {
    library(ksAI)
  }
} else {
  library(ksAI)
}

# ---------------------------------------------------------------------------
# Paths — bundled pilot meta + writable output directory
# ---------------------------------------------------------------------------

.example_meta_path <- function() {
  installed <- system.file("examples", "pilot-study", "meta", package = "ksAI")
  if (nzchar(installed) && dir.exists(installed)) {
    return(installed)
  }
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg)) {
    script <- sub("^--file=", "", file_arg[[1]])
    dev <- file.path(dirname(script), "pilot-study", "meta")
    if (dir.exists(dev)) {
      return(normalizePath(dev))
    }
  }
  dev <- file.path(getwd(), "inst", "examples", "pilot-study", "meta")
  if (dir.exists(dev)) {
    return(normalizePath(dev))
  }
  cli::cli_abort(c(
    "Bundled pilot study meta folder not found.",
    i = "Install {.pkg ksAI} or run from the package source tree."
  ))
}

META_PATH <- .example_meta_path()
OUT_DIR   <- file.path(tempdir(), "ksAI-pilot-demo")

PROVIDER    <- "lm_studio"
# ellmer chat_lmstudio expects the host root (no /v1). Embedding needs /v1.
CHAT_URL    <- "http://127.0.0.1:1234"
EMBED_URL   <- "http://127.0.0.1:1234/v1"
MODEL_SMALL <- "google/gemma-4-e4b"           # 4B — semantic capsule enrichment
MODEL_LARGE <- "gemma-4-26b-a4b-it-mlx"       # 26B — reasoning / CSR drafting
EMBED_MODEL <- "text-embedding-nomic-embed-text-v1.5"

TABLES <- c(
  demographics = "14-2.01",
  efficacy_adas = "14-3.01",
  efficacy_cibic = "14-3.02",
  adverse_events = "14-5.01",
  laboratory = "14-6.01",
  vital_signs = "14-7.02"
)

# Set to FALSE to skip all live LLM / embedding calls (inspect objects only).
RUN_LLM <- TRUE

# Keep prompts inside typical LM Studio 8k contexts. Large tables (lab, VS, AE)
# exceed the window at max_rows=50; 20 is a safe default for this demo.
ks_set_option(
  provider = PROVIDER,
  context_format = "compact",
  max_rows = 20L,
  embed_model = EMBED_MODEL,
  embed_url = EMBED_URL
)

dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

hr <- function(title) {
  cli_h1(title)
}

cli_alert_info("Meta: {.path {META_PATH}}")
cli_alert_info("Output: {.path {OUT_DIR}}")

# ---------------------------------------------------------------------------
# 0. Discover available outputs
# ---------------------------------------------------------------------------

hr("0. Discover outputs")
catalog <- ks_list_ids(META_PATH)
cli_alert_info("{nrow(catalog)} outputs in pilot meta folder")
print(catalog[catalog$id %in% TABLES, c("id", "type", "title")])

# ---------------------------------------------------------------------------
# 1. Targeted load — six table types
# ---------------------------------------------------------------------------

hr("1. Targeted load")
study <- ks_load(META_PATH, ids = unname(TABLES))
study

# ---------------------------------------------------------------------------
# 2. Inspect context formats (no LLM)
# ---------------------------------------------------------------------------

hr("2. Context formats")

for (label in names(TABLES)) {
  id <- TABLES[[label]]
  ctx <- study[[id]]
  cli_h2("{label} ({id})")
  cli_text(
    "rows: {nrow(ctx$rows)} | compact: {nchar(as_compact(ctx))} chars | ",
    "markdown: {nchar(as_markdown(ctx))} chars"
  )
}

# Peek at compact DSL for demographics (span-header table).
cat("\n--- as_compact(14-2.01) preview ---\n")
cat(substr(as_compact(study[["14-2.01"]]), 1, 600), "\n...\n")

# ---------------------------------------------------------------------------
# 3. Workflow A — Direct context (ks_llm on individual tables)
# ---------------------------------------------------------------------------

hr("3. Workflow A — Direct context (ks_llm)")

if (RUN_LLM) {
  # 3a. Demographics — describe
  cli_h2("3a. Demographics — describe")
  out_dm <- ks_llm(
    study,
    ids = TABLES[["demographics"]],
    skill = "describe",
    model = MODEL_LARGE,
    provider = PROVIDER,
    base_url = CHAT_URL
  )
  cat(out_dm$response, "\n")

  # 3b. Primary efficacy (ADAS-Cog) — CSR section draft
  cli_h2("3b. Efficacy ADAS-Cog — csr_section")
  out_adas <- ks_llm(
    study,
    ids = TABLES[["efficacy_adas"]],
    skill = "csr_section",
    title = "ADAS-Cog (11) — Change from Baseline to Week 24",
    model = MODEL_LARGE,
    provider = PROVIDER,
    base_url = CHAT_URL
  )
  cat(out_adas$response, "\n")

  # 3c. Laboratory — clinician summary.
  # Full lab table is dense; reload a short visit window so the prompt fits.
  cli_h2("3c. Laboratory — summarize (clinician)")
  old_rows <- ks_set_option(max_rows = 12L)
  study_lb <- ks_load(META_PATH, ids = TABLES[["laboratory"]])
  ks_set_option(!!!old_rows)
  cli_alert_info(
    "Lab prompt size: {nchar(as_compact(study_lb[[TABLES[['laboratory']]]]))} compact chars ",
    "({length(study_lb[[TABLES[['laboratory']]]]$rows)} visits)"
  )
  out_lb <- ks_llm(
    study_lb,
    ids = TABLES[["laboratory"]],
    skill = "summarize",
    audience = "clinician",
    model = MODEL_LARGE,
    provider = PROVIDER,
    base_url = CHAT_URL
  )
  cat(out_lb$response, "\n")

  # 3d. Cross-table efficacy review (ADAS vs CIBIC)
  cli_h2("3d. Efficacy review — ADAS vs CIBIC")
  out_review <- ks_llm(
    study,
    ids = c(TABLES[["efficacy_adas"]], TABLES[["efficacy_cibic"]]),
    skill = "review",
    model = MODEL_LARGE,
    provider = PROVIDER,
    base_url = CHAT_URL
  )
  cat(out_review$response, "\n")
} else {
  cli_alert_warning("RUN_LLM = FALSE — skipping direct ks_llm() calls")
}

# ---------------------------------------------------------------------------
# 4. Workflow B — Structured facts (as_facts + retrieve)
# ---------------------------------------------------------------------------

hr("4. Workflow B — Structured facts")

# 4a. AE table — filter to cardiac SOC and render compact facts.
cli_h2("4a. AE — cardiac disorders (facts)")
facts_ae <- as_facts(study[[TABLES[["adverse_events"]]]])
facts_cardiac <- retrieve(facts_ae, rows = "CARDIAC DISORDERS")
cat(as_compact(facts_cardiac), "\n")

# 4b. Demographics — age row only.
cli_h2("4b. Demographics — age row (facts)")
facts_dm <- as_facts(study[[TABLES[["demographics"]]]])
facts_age <- retrieve(facts_dm, rows = "Age (y)")
cat(as_compact(facts_age), "\n")

# 4c. Laboratory — baseline visit, high-dose arm span filter.
cli_h2("4c. Laboratory — baseline visit, high dose arm (facts)")
facts_lb <- as_facts(study[[TABLES[["laboratory"]]]])
facts_bsln_high <- retrieve(facts_lb, rows = "Bsln", spans = "Xanomeline High")
cat(as_compact(facts_bsln_high), "\n")

# ---------------------------------------------------------------------------
# 5. Workflow C — Capsule pipeline
# ---------------------------------------------------------------------------

hr("5. Workflow C — Capsule pipeline")

# 5a. Build capsule store from tables + figures (LLM required).
# n_ctx is set when the model is loaded in LM Studio / Ollama — not in this call.
#
# Option A — small context (e.g. n_ctx = 8192): shrink each classify prompt;
#            partial trees are merged by a second LLM pass. Weaker for subtle
#            cross-output multi-membership than a single full-catalog call.
# Option B — large context (raise Context Length in LM Studio, e.g. 32k+):
#            larger batches / excerpts; better whole-catalog interpretation.
#            Use attach_images = TRUE only with a vision-capable model.

CAPSULE_CONTEXT <- Sys.getenv("KSAI_CAPSULE_CONTEXT", "small")  # "small" | "large"

if (identical(CAPSULE_CONTEXT, "large")) {
  cli_h2("5a. as_capsules — Option B (large n_ctx in LM Studio)")
  store <- as_capsules(
    study,
    model = MODEL_SMALL,
    provider = PROVIDER,
    base_url = CHAT_URL,
    detail = "compact",
    max_excerpt_rows = 12L,
    batch_size = 12L,
    attach_images = FALSE,  # TRUE only if MODEL_SMALL has vision
    params = ellmer::params(temperature = 0),
    api_args = list(enable_thinking = FALSE)
  )
} else {
  cli_h2("5a. as_capsules — Option A (fit 8k-class context)")
  store <- as_capsules(
    study,
    model = MODEL_SMALL,
    provider = PROVIDER,
    base_url = CHAT_URL,
    detail = "compact",
    max_excerpt_rows = 4L,
    batch_size = 1L,
    attach_images = FALSE,
    params = ellmer::params(temperature = 0),
    api_args = list(enable_thinking = FALSE)
  )
}
cli_alert_success("Built {length(store$capsules)} capsules")

# Inventory by capsule label / members.
for (cid in names(store$capsules)) {
  cap <- store$capsules[[cid]]
  cli_text(
    "{cid}: {cap$label} — members {paste(cap$member_ids, collapse = ', ')}"
  )
}

# Structural review (no LLM) and optional deep review.
print(review_capsules(store, study))
capsule_tree(store)

# 5b. Semantic enrichment — pass 1: deterministic keywords (fast, no model).
cli_h2("5b. Keyword pass (pure R)")
store <- ks_annotate(store)
sample_id <- names(store$capsules)[[1]]
cli_text(
  "Keywords for {sample_id}: ",
  paste(store$capsules[[sample_id]]$keywords, collapse = ", ")
)

# 5c. Semantic enrichment — pass 2: small LLM concepts (optional).
cli_h2("5c. LLM annotation pass ({MODEL_SMALL})")
DEMO_CAPSULE_IDS <- head(names(store$capsules), 6L)

if (RUN_LLM) {
  demo_store <- store
  demo_store$capsules <- store$capsules[DEMO_CAPSULE_IDS]
  demo_store <- ks_annotate(
    demo_store,
    model = MODEL_SMALL,
    provider = PROVIDER,
    base_url = CHAT_URL,
    force = TRUE
  )
  store$capsules[DEMO_CAPSULE_IDS] <- demo_store$capsules
  for (cid in DEMO_CAPSULE_IDS) {
    cap <- store$capsules[[cid]]
    cli_text("{cid}: concepts = {paste(head(cap$concepts, 4), collapse = ', ')}")
  }
} else {
  cli_alert_warning("RUN_LLM = FALSE — skipping annotation pass")
}

# 5d. Embedding vectors (OpenAI-compatible endpoint in LM Studio).
cli_h2("5d. Embed capsule texts ({EMBED_MODEL})")
if (RUN_LLM) {
  store <- ks_embed(store)
  n_emb <- sum(vapply(store$capsules, function(c) !is.null(c$embedding), logical(1)))
  cli_alert_success("Embedded {n_emb} / {length(store$capsules)} capsules")
} else {
  cli_alert_warning("RUN_LLM = FALSE — skipping embedding pass")
}

# Persist for reuse across sessions.
ksc_path <- file.path(OUT_DIR, "pilot_capsules.ksc")
save_capsules(store, ksc_path)
cli_alert_info("Saved capsule store to {.path {ksc_path}}")

# ---------------------------------------------------------------------------
# 6. Retrieval — content queries
# ---------------------------------------------------------------------------

hr("6. Retrieval (ks_retrieve)")

queries <- list(
  adverse_events = list(
    query = "cardiac disorders and bradycardia in the high dose arm",
    filter = list()
  ),
  efficacy = list(
    query = "ADAS-Cog change from baseline week 24 treatment difference",
    filter = list()
  ),
  laboratory = list(
    query = "liver enzymes ALT AST laboratory abnormalities",
    filter = list()
  ),
  vital_signs = list(
    query = "systolic blood pressure change from baseline end of treatment",
    filter = list()
  ),
  demographics = list(
    query = "age sex race baseline demographic characteristics",
    filter = list()
  )
)

if (RUN_LLM) {
  subsets <- lapply(names(queries), function(name) {
    q <- queries[[name]]
    cli_h2("Retrieve: {name}")
    sub <- ks_retrieve(
      store,
      query = q$query,
      n = 3L,
      filter = q$filter
    )
    print(sub)
    sub
  })
  names(subsets) <- names(queries)
} else {
  cli_alert_warning("RUN_LLM = FALSE — retrieval needs embeddings; inspect store only")
}

# ---------------------------------------------------------------------------
# 7. Reasoning — 26B model over retrieved capsules only
# ---------------------------------------------------------------------------

hr("7. Workflow C — Reasoning (ks_reason, {MODEL_LARGE})")

if (RUN_LLM) {
  # 7a. Safety — cardiac AE narrative.
  cli_h2("7a. Reason — cardiac adverse events")
  out_reason_ae <- ks_reason(
    store,
    query = "Summarize cardiac disorder incidence across treatment arms. Cite specific n(%) values.",
    n = 3L,
    expand = TRUE,
    model = MODEL_LARGE,
    provider = PROVIDER,
    base_url = CHAT_URL
  )
  cat(out_reason_ae$response, "\n")

  # 7b. Efficacy — ADAS-Cog treatment effect.
  cli_h2("7b. Reason — ADAS-Cog efficacy")
  out_reason_eff <- ks_reason(
    store,
    query = "What is the treatment difference for ADAS-Cog change from baseline at Week 24?",
    n = 3L,
    model = MODEL_LARGE,
    provider = PROVIDER,
    base_url = CHAT_URL
  )
  cat(out_reason_eff$response, "\n")

  # 7c. Laboratory — hepatic parameters.
  cli_h2("7c. Reason — laboratory hepatic values")
  out_reason_lb <- ks_reason(
    store,
    query = "Describe baseline and Week 24 laboratory summary statistics and any notable shifts.",
    n = 3L,
    model = MODEL_LARGE,
    provider = PROVIDER,
    base_url = CHAT_URL
  )
  cat(out_reason_lb$response, "\n")
} else {
  cli_alert_warning("RUN_LLM = FALSE — skipping ks_reason() calls")
}

# ---------------------------------------------------------------------------
# 8. Workflow D — Result chaining
# ---------------------------------------------------------------------------

hr("8. Workflow D — Result chaining")

if (RUN_LLM) {
  # Chaining doubles prompt size (table + prior). Use a compact efficacy
  # table so draft + prior fit the local 26B context window.
  cli_h2("8a. Draft ADAS CSR section")
  out_chain_draft <- ks_llm(
    study,
    ids = TABLES[["efficacy_adas"]],
    skill = "csr_section",
    title = "ADAS-Cog (11) — Change from Baseline to Week 24",
    model = MODEL_LARGE,
    provider = PROVIDER,
    base_url = CHAT_URL
  )

  paths <- save_result(out_chain_draft, file.path(OUT_DIR, "adas-draft"))
  cli_alert_success("Saved to {.path {paths$md}} and {.path {paths$json}}")

  cli_h2("8b. Refine with prior result")
  out_loaded <- load_result(paths$json)
  out_chain_refined <- ks_llm(
    study,
    ids = TABLES[["efficacy_adas"]],
    skill = "csr_section",
    title = "ADAS-Cog (11) — Change from Baseline to Week 24",
    prompt = "Tighten the narrative. Remove unsupported claims. Keep regulatory tone.",
    prior = out_loaded,
    model = MODEL_LARGE,
    provider = PROVIDER,
    base_url = CHAT_URL
  )
  save_result(out_chain_refined, file.path(OUT_DIR, "adas-refined"))
  cat(out_chain_refined$response, "\n")

  # Capsule reason → CSR: refine using prior only over a small efficacy table
  # (AE full table + prior exceeds typical local context).
  cli_h2("8c. Chain capsule reason → CSR refinement")
  save_result(out_reason_ae, file.path(OUT_DIR, "cardiac-reason"))
  out_ae_csr <- ks_llm(
    study,
    ids = TABLES[["efficacy_cibic"]],
    skill = "csr_section",
    title = "Safety signal follow-up (from capsule reason)",
    prompt = paste(
      "Using the prior capsule-based cardiac analysis as background,",
      "draft a short CSR note on how efficacy (CIBIC+) should be interpreted",
      "alongside the cardiac safety signal. Do not invent AE counts;",
      "refer to the prior for safety numbers."
    ),
    prior = load_result(file.path(OUT_DIR, "cardiac-reason")),
    model = MODEL_LARGE,
    provider = PROVIDER,
    base_url = CHAT_URL
  )
  save_result(out_ae_csr, file.path(OUT_DIR, "cardiac-csr"))
  cat(out_ae_csr$response, "\n")
} else {
  cli_alert_warning("RUN_LLM = FALSE — skipping result chaining")
}

# ---------------------------------------------------------------------------
# 9. Optional — persistent chat session (conversational follow-ups)
# ---------------------------------------------------------------------------

hr("9. Optional — ks_chat session")

if (RUN_LLM) {
  # ks_chat() embeds EVERY loaded output in the system prompt. Keep the
  # study small — do not pass the full six-table study here.
  study_chat <- ks_load(META_PATH, ids = TABLES[["demographics"]])
  chat <- ks_chat(
    study_chat,
    model = MODEL_LARGE,
    provider = PROVIDER,
    base_url = CHAT_URL
  )

  # Conversational follow-up on the already-embedded context (no second inject).
  followup_text <- as.character(
    chat$chat$chat("List the three most notable baseline imbalances between arms.")
  )
  cat(followup_text, "\n")

  # Skill call on the same session; ids must exist in study_chat.
  followup_skill <- ks_llm(
    chat,
    ids = TABLES[["demographics"]],
    skill = "describe"
  )
  cat(followup_skill$response, "\n")
} else {
  cli_alert_warning("RUN_LLM = FALSE — skipping ks_chat session")
}

cli_alert_success("Demo complete. Outputs in {.path {OUT_DIR}}")
