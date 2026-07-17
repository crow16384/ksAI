# Package index

## Study Loading and Persistence

- [`ks_list_ids()`](https://crow16384.github.io/ksAI/reference/ks_list_ids.md)
  :

  List Available Output IDs in a Meta Folder or `.ks` File

- [`ks_load()`](https://crow16384.github.io/ksAI/reference/ks_load.md) :

  Load Selected Outputs from a ksTFL Meta Folder or `.ks` File

- [`save_study()`](https://crow16384.github.io/ksAI/reference/save_study.md)
  :

  Save a Study to a `.ks` File

## Chat and Skills

- [`ks_chat()`](https://crow16384.github.io/ksAI/reference/ks_chat.md) :
  Open an AI Chat Session Over Loaded Outputs
- [`ks_llm()`](https://crow16384.github.io/ksAI/reference/ks_llm.md) :
  Run a Skill or Free Prompt Against Selected Outputs
- [`ks_list_skills()`](https://crow16384.github.io/ksAI/reference/ks_list_skills.md)
  : List Available Skills

## Result Persistence

- [`is_ks_result()`](https://crow16384.github.io/ksAI/reference/is_ks_result.md)
  : The ks_result Class
- [`save_result()`](https://crow16384.github.io/ksAI/reference/save_result.md)
  : Persist a ks_result as Markdown and JSON
- [`load_result()`](https://crow16384.github.io/ksAI/reference/load_result.md)
  : Load a saved ks_result

## Context Utilities

- [`is_ks_context()`](https://crow16384.github.io/ksAI/reference/is_ks_context.md)
  :

  The `ks_context` Class

- [`as_json()`](https://crow16384.github.io/ksAI/reference/as_json.md) :

  Render a `ks_context` as a JSON String

- [`as_markdown()`](https://crow16384.github.io/ksAI/reference/as_markdown.md)
  :

  Render a `ks_context` as a Human-Readable Markdown Table

- [`as_compact()`](https://crow16384.github.io/ksAI/reference/as_compact.md)
  :

  Render a `ks_context` as Compact DSL Text

- [`enrich_context()`](https://crow16384.github.io/ksAI/reference/enrich_context.md)
  : Enrich a Table Context with User Knowledge

## CKR and Structured Facts

- [`is_ks_facts()`](https://crow16384.github.io/ksAI/reference/is_ks_facts.md)
  :

  The `ks_facts` Class

- [`as_facts()`](https://crow16384.github.io/ksAI/reference/as_facts.md)
  :

  Convert a `ks_context` into a Retrievable Fact Store

- [`retrieve()`](https://crow16384.github.io/ksAI/reference/retrieve.md)
  :

  Filter a `ks_facts` Store by Row Labels, Sections, or Spans

## Clinical Capsules

- [`is_ks_capsule()`](https://crow16384.github.io/ksAI/reference/is_ks_capsule.md)
  :

  The `ks_capsule` Class

- [`is_ks_capsule_store()`](https://crow16384.github.io/ksAI/reference/is_ks_capsule_store.md)
  :

  The `ks_capsule_store` Class

- [`as_capsules()`](https://crow16384.github.io/ksAI/reference/as_capsules.md)
  : Build Clinical Capsules from Contexts

- [`save_capsules()`](https://crow16384.github.io/ksAI/reference/save_capsules.md)
  :

  Save a Capsule Store to a `.ksc` File

- [`load_capsules()`](https://crow16384.github.io/ksAI/reference/load_capsules.md)
  :

  Load a Capsule Store from a `.ksc` File

- [`ks_annotate()`](https://crow16384.github.io/ksAI/reference/ks_annotate.md)
  : Annotate Capsule Store with Semantic Metadata

- [`ks_embed()`](https://crow16384.github.io/ksAI/reference/ks_embed.md)
  : Embed Capsule Texts

- [`ks_retrieve()`](https://crow16384.github.io/ksAI/reference/ks_retrieve.md)
  : Retrieve Relevant Clinical Capsules

- [`ks_reason()`](https://crow16384.github.io/ksAI/reference/ks_reason.md)
  : Reason Over Retrieved Capsules

## Study and Session Utilities

- [`is_ks_study()`](https://crow16384.github.io/ksAI/reference/is_ks_study.md)
  :

  The `ks_study` Class

- [`` `[[`( ``*`<ks_study>`*`)`](https://crow16384.github.io/ksAI/reference/sub-sub-.ks_study.md)
  : Look up an output by id across all types

- [`is_kschat()`](https://crow16384.github.io/ksAI/reference/is_kschat.md)
  :

  Test for a `kschat` Object

- [`ks_get_option()`](https://crow16384.github.io/ksAI/reference/ks_get_option.md)
  [`ks_set_option()`](https://crow16384.github.io/ksAI/reference/ks_get_option.md)
  : Get or Set ksAI Options
