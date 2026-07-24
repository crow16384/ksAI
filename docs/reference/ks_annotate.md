# ks_annotate

```
ks_annotate                package:ksAI                R Documentation

_A_n_n_o_t_a_t_e _C_a_p_s_u_l_e _S_t_o_r_e _w_i_t_h _S_e_m_a_n_t_i_c _M_e_t_a_d_a_t_a

_D_e_s_c_r_i_p_t_i_o_n:

     Enriches capsules in a ‘ks_capsule_store’ in two passes: a
     deterministic token/abbreviation pass, plus an optional small-LLM
     extraction pass.

_U_s_a_g_e:

     ks_annotate(
       store,
       model = NULL,
       provider = ks_get_option("provider"),
       base_url = NULL,
       batch_size = 64L,
       force = FALSE,
       ...
     )
     
_A_r_g_u_m_e_n_t_s:

   store: A ‘ks_capsule_store’.

   model: Optional model for the small semantic LLM pass.

provider: Provider for LLM pass. Defaults to
          ‘ks_get_option()’‘provider’.

base_url: Optional provider URL override.

batch_size: Integer batch size for deterministic pass.

   force: Recompute keyword/concept metadata even if already present.

     ...: Extra args forwarded to the chat constructor.

_V_a_l_u_e:

     Updated ‘ks_capsule_store’.

```
