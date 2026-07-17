#include "ks_facts.h"

#include <algorithm>
#include <limits>
#include <numeric>

namespace ksai {

uint32_t Dictionary::lookup(std::string_view v) {
  std::string key(v);
  auto it = value_to_idx_.find(key);
  if (it != value_to_idx_.end()) {
    return it->second;
  }
  const uint32_t idx = static_cast<uint32_t>(idx_to_value_.size());
  idx_to_value_.push_back(key);
  value_to_idx_.emplace(std::move(key), idx);
  return idx;
}

uint32_t Dictionary::lookup_existing(std::string_view v) const {
  auto it = value_to_idx_.find(std::string(v));
  if (it == value_to_idx_.end()) {
    return std::numeric_limits<uint32_t>::max();
  }
  return it->second;
}

std::string_view Dictionary::decode(uint32_t idx) const {
  if (idx >= idx_to_value_.size()) {
    return std::string_view{};
  }
  return idx_to_value_[idx];
}

uint32_t Dictionary::size() const {
  return static_cast<uint32_t>(idx_to_value_.size());
}

Rcpp::CharacterVector Dictionary::to_r() const {
  Rcpp::CharacterVector out(idx_to_value_.size());
  for (std::size_t i = 0; i < idx_to_value_.size(); ++i) {
    out[i] = idx_to_value_[i];
  }
  return out;
}

FactTable FactTable::subset(const std::vector<uint32_t>& row_ids) const {
  FactTable out;
  out.row_label_dict = row_label_dict;
  out.section_dict = section_dict;
  out.kind_dict = kind_dict;
  out.dim_dicts = dim_dicts;

  const std::size_t n = row_ids.size();
  out.row_label_col.reserve(n);
  out.section_col.reserve(n);
  out.kind_col.reserve(n);

  for (const auto& [name, _] : dim_cols) {
    out.dim_cols[name] = std::vector<uint32_t>();
    out.dim_cols[name].reserve(n);
  }
  for (const auto& [name, _] : measure_cols) {
    out.measure_cols[name] = std::vector<std::string>();
    out.measure_cols[name].reserve(n);
  }

  for (uint32_t rid : row_ids) {
    out.row_label_col.push_back(row_label_col[rid]);
    out.section_col.push_back(section_col[rid]);
    out.kind_col.push_back(kind_col[rid]);
    for (auto& [name, vec] : out.dim_cols) {
      vec.push_back(dim_cols.at(name)[rid]);
    }
    for (auto& [name, vec] : out.measure_cols) {
      vec.push_back(measure_cols.at(name)[rid]);
    }
  }
  return out;
}

void InvertedIndex::build(const FactTable& ft) {
  row_label_idx_.clear();
  section_idx_.clear();
  const std::size_t n = ft.n_rows();
  for (std::size_t i = 0; i < n; ++i) {
    row_label_idx_[ft.row_label_col[i]].push_back(static_cast<uint32_t>(i));
    if (ft.section_col[i] >= 0) {
      section_idx_[static_cast<uint32_t>(ft.section_col[i])].push_back(
          static_cast<uint32_t>(i));
    }
  }
  for (auto& [_, ids] : row_label_idx_) {
    std::ranges::sort(ids);
  }
  for (auto& [_, ids] : section_idx_) {
    std::ranges::sort(ids);
  }
}

namespace {

std::vector<uint32_t> union_postings(
    const std::unordered_map<uint32_t, std::vector<uint32_t>>& index,
    const std::vector<uint32_t>& keys) {
  std::vector<uint32_t> out;
  for (uint32_t key : keys) {
    auto it = index.find(key);
    if (it == index.end()) {
      continue;
    }
    out.insert(out.end(), it->second.begin(), it->second.end());
  }
  std::ranges::sort(out);
  out.erase(std::unique(out.begin(), out.end()), out.end());
  return out;
}

std::vector<uint32_t> intersect_sorted(std::vector<uint32_t> a,
                                       const std::vector<uint32_t>& b) {
  std::vector<uint32_t> out;
  std::ranges::set_intersection(a, b, std::back_inserter(out));
  return out;
}

} // namespace

std::vector<uint32_t> InvertedIndex::query(
    const std::vector<uint32_t>& row_label_ids,
    const std::vector<int32_t>& section_ids) const {
  std::vector<uint32_t> result;

  bool have_filter = false;
  if (!row_label_ids.empty()) {
    result = union_postings(row_label_idx_, row_label_ids);
    have_filter = true;
  }

  if (!section_ids.empty()) {
    std::vector<uint32_t> section_keys;
    section_keys.reserve(section_ids.size());
    for (int32_t sid : section_ids) {
      if (sid >= 0) {
        section_keys.push_back(static_cast<uint32_t>(sid));
      }
    }
    auto section_rows = union_postings(section_idx_, section_keys);
    if (!have_filter) {
      result = std::move(section_rows);
      have_filter = true;
    } else {
      result = intersect_sorted(std::move(result), section_rows);
    }
  }

  if (!have_filter) {
    // No filters: caller should request all rows via R-side path.
    return {};
  }
  return result;
}

} // namespace ksai

namespace {

std::string as_string_cell(SEXP x) {
  if (Rf_isNull(x) || Rf_length(x) == 0) {
    return "";
  }
  if (TYPEOF(x) == STRSXP) {
    Rcpp::String s(STRING_ELT(x, 0));
    if (s == NA_STRING) {
      return "";
    }
    return std::string(s);
  }
  if (TYPEOF(x) == REALSXP) {
    double v = REAL(x)[0];
    if (Rcpp::traits::is_na<REALSXP>(v)) {
      return "";
    }
    return std::to_string(v);
  }
  if (TYPEOF(x) == INTSXP) {
    int v = INTEGER(x)[0];
    if (v == NA_INTEGER) {
      return "";
    }
    return std::to_string(v);
  }
  if (TYPEOF(x) == LGLSXP) {
    int v = LOGICAL(x)[0];
    if (v == NA_LOGICAL) {
      return "";
    }
    return v ? "TRUE" : "FALSE";
  }
  return "";
}

} // namespace

//' @keywords internal
//' @noRd
// [[Rcpp::export(name = "ks_build_fact_table")]]
SEXP ks_build_fact_table(SEXP rows_list, SEXP schema_list) {
  Rcpp::List rows(rows_list);
  Rcpp::List schema(schema_list);

  Rcpp::CharacterVector dim_names = schema.containsElementNamed("dim_names")
                                        ? Rcpp::as<Rcpp::CharacterVector>(schema["dim_names"])
                                        : Rcpp::CharacterVector();
  Rcpp::CharacterVector measure_names =
      schema.containsElementNamed("measure_names")
          ? Rcpp::as<Rcpp::CharacterVector>(schema["measure_names"])
          : Rcpp::CharacterVector();

  auto* store = new ksai::FactStore();
  auto& ft = store->table;
  const int n = rows.size();

  ft.row_label_col.reserve(n);
  ft.section_col.reserve(n);
  ft.kind_col.reserve(n);

  for (int d = 0; d < dim_names.size(); ++d) {
    std::string name = Rcpp::as<std::string>(dim_names[d]);
    ft.dim_cols[name] = std::vector<uint32_t>();
    ft.dim_cols[name].reserve(n);
    ft.dim_dicts[name] = ksai::Dictionary();
  }
  for (int m = 0; m < measure_names.size(); ++m) {
    std::string name = Rcpp::as<std::string>(measure_names[m]);
    ft.measure_cols[name] = std::vector<std::string>();
    ft.measure_cols[name].reserve(n);
  }

  for (int i = 0; i < n; ++i) {
    Rcpp::List row = rows[i];
    std::string label = Rcpp::as<std::string>(row["row_label"]);
    ft.row_label_col.push_back(ft.row_label_dict.lookup(label));

    if (row.containsElementNamed("section") && !Rf_isNull(row["section"])) {
      std::string sec = Rcpp::as<std::string>(row["section"]);
      if (sec.empty()) {
        ft.section_col.push_back(-1);
      } else {
        ft.section_col.push_back(static_cast<int32_t>(ft.section_dict.lookup(sec)));
      }
    } else {
      ft.section_col.push_back(-1);
    }

    if (row.containsElementNamed("kind") && !Rf_isNull(row["kind"])) {
      std::string kind = Rcpp::as<std::string>(row["kind"]);
      if (kind.empty()) {
        ft.kind_col.push_back(-1);
      } else {
        ft.kind_col.push_back(static_cast<int32_t>(ft.kind_dict.lookup(kind)));
      }
    } else {
      ft.kind_col.push_back(-1);
    }

    Rcpp::List dims = row.containsElementNamed("dims") ? Rcpp::as<Rcpp::List>(row["dims"])
                                                       : Rcpp::List();
    for (int d = 0; d < dim_names.size(); ++d) {
      std::string name = Rcpp::as<std::string>(dim_names[d]);
      std::string val = "";
      if (dims.containsElementNamed(name.c_str())) {
        val = as_string_cell(dims[name]);
      }
      ft.dim_cols[name].push_back(ft.dim_dicts[name].lookup(val));
    }

    Rcpp::List measures = row.containsElementNamed("measures")
                              ? Rcpp::as<Rcpp::List>(row["measures"])
                              : Rcpp::List();
    for (int m = 0; m < measure_names.size(); ++m) {
      std::string name = Rcpp::as<std::string>(measure_names[m]);
      std::string val = "";
      if (measures.containsElementNamed(name.c_str())) {
        val = as_string_cell(measures[name]);
      }
      ft.measure_cols[name].push_back(val);
    }
  }

  store->index.build(ft);
  Rcpp::XPtr<ksai::FactStore> ptr(store, true);
  ptr.attr("class") = "ks_fact_store";
  return ptr;
}

//' @keywords internal
//' @noRd
// [[Rcpp::export(name = "ks_query_facts")]]
SEXP ks_query_facts(SEXP ptr, SEXP row_label_values, SEXP section_values) {
  Rcpp::XPtr<ksai::FactStore> store(ptr);
  Rcpp::CharacterVector row_vals(row_label_values);
  Rcpp::CharacterVector sec_vals(section_values);

  std::vector<uint32_t> row_ids;
  row_ids.reserve(row_vals.size());
  for (int i = 0; i < row_vals.size(); ++i) {
    if (row_vals[i] == NA_STRING) {
      continue;
    }
    uint32_t id = store->table.row_label_dict.lookup_existing(
        Rcpp::as<std::string>(row_vals[i]));
    if (id != std::numeric_limits<uint32_t>::max()) {
      row_ids.push_back(id);
    }
  }

  std::vector<int32_t> section_ids;
  section_ids.reserve(sec_vals.size());
  for (int i = 0; i < sec_vals.size(); ++i) {
    if (sec_vals[i] == NA_STRING) {
      continue;
    }
    uint32_t id = store->table.section_dict.lookup_existing(
        Rcpp::as<std::string>(sec_vals[i]));
    if (id != std::numeric_limits<uint32_t>::max()) {
      section_ids.push_back(static_cast<int32_t>(id));
    }
  }

  std::vector<uint32_t> matched;
  const bool filter_rows = row_vals.size() > 0;
  const bool filter_secs = sec_vals.size() > 0;

  if (!filter_rows && !filter_secs) {
    matched.resize(store->table.n_rows());
    std::iota(matched.begin(), matched.end(), 0u);
  } else if ((filter_rows && row_ids.empty()) || (filter_secs && section_ids.empty())) {
    // A requested filter resolved to no dictionary hits → empty result.
    matched.clear();
  } else {
    matched = store->index.query(row_ids, section_ids);
  }

  auto* out = new ksai::FactStore();
  out->table = store->table.subset(matched);
  out->index.build(out->table);
  Rcpp::XPtr<ksai::FactStore> out_ptr(out, true);
  out_ptr.attr("class") = "ks_fact_store";
  return out_ptr;
}

//' @keywords internal
//' @noRd
// [[Rcpp::export(name = "ks_decode_facts")]]
Rcpp::List ks_decode_facts(SEXP ptr) {
  Rcpp::XPtr<ksai::FactStore> store(ptr);
  const auto& ft = store->table;
  const int n = static_cast<int>(ft.n_rows());

  Rcpp::CharacterVector row_label(n);
  Rcpp::CharacterVector section(n);
  Rcpp::CharacterVector kind(n);

  for (int i = 0; i < n; ++i) {
    row_label[i] = std::string(ft.row_label_dict.decode(ft.row_label_col[i]));
    if (ft.section_col[i] < 0) {
      section[i] = NA_STRING;
    } else {
      section[i] = std::string(
          ft.section_dict.decode(static_cast<uint32_t>(ft.section_col[i])));
    }
    if (ft.kind_col[i] < 0) {
      kind[i] = NA_STRING;
    } else {
      kind[i] = std::string(
          ft.kind_dict.decode(static_cast<uint32_t>(ft.kind_col[i])));
    }
  }

  Rcpp::List dims = Rcpp::List::create();
  for (const auto& [name, vec] : ft.dim_cols) {
    Rcpp::CharacterVector col(n);
    const auto& dict = ft.dim_dicts.at(name);
    for (int i = 0; i < n; ++i) {
      col[i] = std::string(dict.decode(vec[i]));
    }
    dims[name] = col;
  }

  Rcpp::List measures = Rcpp::List::create();
  for (const auto& [name, vec] : ft.measure_cols) {
    Rcpp::CharacterVector col(n);
    for (int i = 0; i < n; ++i) {
      col[i] = vec[i];
    }
    measures[name] = col;
  }

  return Rcpp::List::create(
      Rcpp::_["n_rows"] = n,
      Rcpp::_["row_label"] = row_label,
      Rcpp::_["section"] = section,
      Rcpp::_["kind"] = kind,
      Rcpp::_["dims"] = dims,
      Rcpp::_["measures"] = measures);
}

//' @keywords internal
//' @noRd
// [[Rcpp::export(name = "ks_get_dictionaries")]]
Rcpp::List ks_get_dictionaries(SEXP ptr) {
  Rcpp::XPtr<ksai::FactStore> store(ptr);
  const auto& ft = store->table;

  Rcpp::List dim_dicts = Rcpp::List::create();
  for (const auto& [name, dict] : ft.dim_dicts) {
    dim_dicts[name] = dict.to_r();
  }

  return Rcpp::List::create(
      Rcpp::_["row_label"] = ft.row_label_dict.to_r(),
      Rcpp::_["section"] = ft.section_dict.to_r(),
      Rcpp::_["kind"] = ft.kind_dict.to_r(),
      Rcpp::_["dims"] = dim_dicts,
      Rcpp::_["n_rows"] = static_cast<int>(ft.n_rows()));
}
