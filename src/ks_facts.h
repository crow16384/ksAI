#ifndef KS_FACTS_H
#define KS_FACTS_H

#include <Rcpp.h>
#include <cstdint>
#include <expected>
#include <ranges>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

#if defined(__cpp_lib_flat_map) && __cpp_lib_flat_map >= 202207L
#include <flat_map>
#define KS_DICT_MAP std::flat_map
#else
#include <map>
#define KS_DICT_MAP std::map
#endif

namespace ksai {

class Dictionary {
  KS_DICT_MAP<std::string, uint32_t> value_to_idx_;
  std::vector<std::string> idx_to_value_;

public:
  uint32_t lookup(std::string_view v);
  uint32_t lookup_existing(std::string_view v) const; // returns UINT32_MAX if missing
  std::string_view decode(uint32_t idx) const;
  uint32_t size() const;
  Rcpp::CharacterVector to_r() const;
};

class FactTable {
public:
  std::vector<uint32_t> row_label_col;
  std::vector<int32_t> section_col; // -1 = none
  std::vector<int32_t> kind_col;    // -1 = none
  std::unordered_map<std::string, std::vector<uint32_t>> dim_cols;
  std::unordered_map<std::string, std::vector<std::string>> measure_cols;

  Dictionary row_label_dict;
  Dictionary section_dict;
  Dictionary kind_dict;
  std::unordered_map<std::string, Dictionary> dim_dicts;

  std::size_t n_rows() const { return row_label_col.size(); }
  FactTable subset(const std::vector<uint32_t>& row_ids) const;
};

class InvertedIndex {
  std::unordered_map<uint32_t, std::vector<uint32_t>> row_label_idx_;
  std::unordered_map<uint32_t, std::vector<uint32_t>> section_idx_;

public:
  void build(const FactTable& ft);
  std::vector<uint32_t> query(
      const std::vector<uint32_t>& row_label_ids,
      const std::vector<int32_t>& section_ids) const;
};

using QueryResult = std::expected<std::vector<uint32_t>, std::string>;

struct FactStore {
  FactTable table;
  InvertedIndex index;
};

} // namespace ksai

#endif
