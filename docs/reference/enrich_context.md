# enrich_context

```
enrich_context              package:ksAI               R Documentation

_E_n_r_i_c_h _a _T_a_b_l_e _C_o_n_t_e_x_t _w_i_t_h _U_s_e_r _K_n_o_w_l_e_d_g_e

_D_e_s_c_r_i_p_t_i_o_n:

     Returns a new ‘ks_context’ with user-supplied metadata overlaid.
     The original object is not modified. ‘annotations’ are merged with
     any existing annotations rather than replaced.

_U_s_a_g_e:

     enrich_context(ctx, population = NULL, source = NULL, annotations = list())
     
_A_r_g_u_m_e_n_t_s:

     ctx: A ‘ks_context’ object.

population: Optional character scalar. Overrides the analysis
          population.

  source: Optional character scalar. Overrides the source program.

annotations: Named list of free-form metadata to merge in.

_V_a_l_u_e:

     A new ‘ks_context’ object.

_E_x_a_m_p_l_e_s:

     ## Not run:
     
     ctx <- study$tables[["14-3.01"]]
     ctx <- enrich_context(ctx, population = "ITT",
                           annotations = list(sap_ref = "Section 9.2"))
     ## End(Not run)
     
```
