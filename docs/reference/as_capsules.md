# as_capsules

```
as_capsules                package:ksAI                R Documentation

_B_u_i_l_d _C_l_i_n_i_c_a_l _C_a_p_s_u_l_e_s _f_r_o_m _C_o_n_t_e_x_t_s (_L_L_M)

_D_e_s_c_r_i_p_t_i_o_n:

     Groups *tables* and *figures* into a named semantic capsule tree
     using an LLM only (small or large). There is no rule-based / CDISC
     formation path. ‘model’ is required. Figure image pixels are
     attached for vision-capable models; R does not interpret plots.

_U_s_a_g_e:

     as_capsules(
       x,
       model,
       provider = ks_get_option("provider"),
       base_url = NULL,
       max_excerpt_rows = 12L,
       detail = c("compact", "full"),
       min_confidence = 0.5,
       batch_size = 24L,
       attach_images = TRUE,
       ...
     )
     
     ## S3 method for class 'ks_context'
     as_capsules(
       x,
       model,
       provider = ks_get_option("provider"),
       base_url = NULL,
       max_excerpt_rows = 12L,
       detail = c("compact", "full"),
       min_confidence = 0.5,
       batch_size = 24L,
       attach_images = TRUE,
       ...
     )
     
     ## S3 method for class 'ks_study'
     as_capsules(
       x,
       model,
       provider = ks_get_option("provider"),
       base_url = NULL,
       max_excerpt_rows = 12L,
       detail = c("compact", "full"),
       min_confidence = 0.5,
       batch_size = 24L,
       attach_images = TRUE,
       ...
     )
     
_A_r_g_u_m_e_n_t_s:

       x: A ‘ks_context’ or ‘ks_study’.

   model: LLM model name (required).

provider: LLM provider. Defaults to ‘ks_get_option()’‘"provider"’.

base_url: Optional provider URL override.

max_excerpt_rows: Maximum table rows included in each catalog excerpt.

  detail: ‘"compact"’ (default) or ‘"full"’ table excerpts.

min_confidence: Minimum confidence (0–1) to keep an LLM capsule.

batch_size: Maximum catalog items per classify call before an LLM merge
          pass.

attach_images: Logical. Attach figure assets via ellmer when readable.

     ...: Extra args forwarded to the ellmer chat constructor.

_V_a_l_u_e:

     A ‘ks_capsule_store’.

```
