# ks_get_option

```
ks_get_option               package:ksAI               R Documentation

_G_e_t _o_r _S_e_t _k_s_A_I _O_p_t_i_o_n_s

_D_e_s_c_r_i_p_t_i_o_n:

     ‘ks_get_option()’ retrieves a package option; ‘ks_set_option()’
     updates one or more options for the current session.

_U_s_a_g_e:

     ks_get_option(key)
     
     ks_set_option(...)
     
_A_r_g_u_m_e_n_t_s:

     key: Character scalar. Option name. One of ‘"max_rows"’,
          ‘"skills_dir"’, ‘"provider"’, ‘"context_format"’,
          ‘"embed_model"’, ‘"embed_url"’.

     ...: Named ‘key = value’ pairs to set (for ‘ks_set_option()’).

_V_a_l_u_e:

     ‘ks_get_option()’ returns the option value. ‘ks_set_option()’
     invisibly returns the previous values of the changed options.

_E_x_a_m_p_l_e_s:

     ks_get_option("max_rows")
     old <- ks_set_option(max_rows = 300L)
     ks_set_option(!!!old)
     
```
