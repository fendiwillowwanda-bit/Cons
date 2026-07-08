METHOD /scwm/if_ex_who_eew_change~update.

* No functional change vs. the original - reviewed and kept as-is.

  DATA: lv_lgnum   TYPE /scwm/lgnum,
        lv_procty  TYPE /scwm/de_procty,
        lv_has_brf TYPE abap_bool.

  FIELD-SYMBOLS:
    <ls_who>    TYPE any,
    <ls_brf>    TYPE any,
    <lv_any>    TYPE any,
    <lv_brfval> TYPE any.

  LOOP AT it_who ASSIGNING <ls_who>.

    CLEAR:
      lv_lgnum,
      lv_procty,
      lv_has_brf.

    ASSIGN COMPONENT 'LGNUM' OF STRUCTURE <ls_who> TO <lv_any>.
    IF sy-subrc = 0.
      lv_lgnum = <lv_any>.
    ENDIF.

    ASSIGN COMPONENT 'PROCTY' OF STRUCTURE <ls_who> TO <lv_any>.
    IF sy-subrc = 0.
      lv_procty = <lv_any>.
    ENDIF.

    IF lv_procty IS INITIAL.
      ASSIGN COMPONENT 'HDR_PROCTY' OF STRUCTURE <ls_who> TO <lv_any>.
      IF sy-subrc = 0.
        lv_procty = <lv_any>.
      ENDIF.
    ENDIF.

    CHECK lv_lgnum  IS NOT INITIAL.
    CHECK lv_procty IS NOT INITIAL.

    zcl_brfplus_data=>get_psa_bin(
      EXPORTING
        iv_lgnum  = lv_lgnum
      IMPORTING
        et_result = DATA(lt_psabin) ).

    IF lt_psabin IS INITIAL.
      CONTINUE.
    ENDIF.

    LOOP AT lt_psabin ASSIGNING <ls_brf>.

      ASSIGN COMPONENT 'LGNUM' OF STRUCTURE <ls_brf> TO <lv_brfval>.
      IF sy-subrc = 0
         AND <lv_brfval> IS NOT INITIAL
         AND <lv_brfval> <> lv_lgnum.
        CONTINUE.
      ENDIF.

      ASSIGN COMPONENT 'PROCTY' OF STRUCTURE <ls_brf> TO <lv_brfval>.
      IF sy-subrc = 0
         AND <lv_brfval> = lv_procty.
        lv_has_brf = abap_true.
        EXIT.
      ENDIF.

    ENDLOOP.

    IF lv_has_brf = abap_true.
      cv_badi_used = abap_true.
    ENDIF.

  ENDLOOP.

ENDMETHOD.
