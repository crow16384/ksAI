# ks_retrieve

```
ks_retrieve                package:ksAI                R Documentation

_R_e_t_r_i_e_v_e _R_e_l_e_v_a_n_t _C_l_i_n_i_c_a_l _C_a_p_s_u_l_e_s

_D_e_s_c_r_i_p_t_i_o_n:

     Scores capsules against a query using embedding similarity,
     keyword overlap, and metadata matching, then returns the
     top-ranked subset.

_U_s_a_g_e:

     ks_retrieve(
       store,
       query,
       n = 5L,
       filter = list(),
       weights = list(semantic = 0.6, keyword = 0.3, metadata = 0.1),
       model = ks_get_option("embed_model"),
       base_url = ks_get_option("embed_url")
     )
     
_A_r_g_u_m_e_n_t_s:

   store: A ‘ks_capsule_store’.

   query: User question or retrieval query.

       n: Maximum number of capsules to return.

  filter: Optional named list with any of: ‘label’, ‘population’,
          ‘member_id’ (output id that must be among capsule members).

 weights: Named numeric list with ‘semantic’, ‘keyword’, ‘metadata’.

   model: Embedding model for query embedding.

base_url: Embedding endpoint base URL.

_V_a_l_u_e:

     A ‘ks_capsule_subset’.

```
