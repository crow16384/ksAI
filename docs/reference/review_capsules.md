# review_capsules

```
review_capsules              package:ksAI              R Documentation

_S_t_r_u_c_t_u_r_a_l _A_u_d_i_t _o_f _a _C_a_p_s_u_l_e _S_t_o_r_e

_D_e_s_c_r_i_p_t_i_o_n:

     Offline checks (no LLM): empty capsules, unknown members, cycles,
     orphans.

_U_s_a_g_e:

     review_capsules(store, study = NULL)
     
_A_r_g_u_m_e_n_t_s:

   store: A ‘ks_capsule_store’.

   study: Optional ‘ks_study’ for catalog membership checks.

_V_a_l_u_e:

     A ‘ks_capsule_review’ list with findings.

```
