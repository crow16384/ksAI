# ks_review_capsules

```
ks_review_capsules            package:ksAI             R Documentation

_L_L_M _D_e_e_p _R_e_v_i_e_w _o_f _C_a_p_s_u_l_e_s

_D_e_s_c_r_i_p_t_i_o_n:

     Asks an LLM (typically vision-capable for figures) to critique
     capsule grouping and member content.

_U_s_a_g_e:

     ks_review_capsules(
       store,
       study,
       model,
       capsule_ids = NULL,
       provider = ks_get_option("provider"),
       base_url = NULL,
       attach_images = TRUE,
       echo = "none",
       ...
     )
     
_A_r_g_u_m_e_n_t_s:

   store: A ‘ks_capsule_store’.

   study: A ‘ks_study’ for member expansion and figure assets.

   model: LLM model name.

capsule_ids: Optional subset of capsule ids (default: all).

provider: LLM provider.

base_url: Optional provider URL.

attach_images: Logical. Attach figure images for vision models.

    echo: Echo mode for ellmer.

     ...: Extra args to the chat constructor.

_V_a_l_u_e:

     A ks_result.

```
