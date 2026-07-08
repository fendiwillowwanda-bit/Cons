METHOD /scwm/if_ex_hu_basics_huhdr~create.

* CAVEAT (not changed - flagging for awareness, needs a design
* decision, not a one-line fix):
* LV_PROCTY below is picked from whatever context row happens to be
* first in LT_CTX (sorted LGNUM/PROCTY/DOCID/ITEMID ascending), not
* from anything tied to the HU actually being created - this method's
* interface gives no DOCID/ITEMID to correlate against. That's fine
* as long as only one process type is ever queued per LGNUM between
* staging and HU creation, but if two staging users are active on the
* same warehouse number at once with different process types, this
* can pop the wrong PSA/Bin for the wrong HU. If that turns out to
* happen in practice, the real fix is to pass a correlation key (e.g.
* WCR/screen field already available in IS_CREATE at the ENRICH_DATA
* call site) through to this method instead of guessing from queue
* order.

  DATA: lv_lgnum   TYPE /scwm/lgnum,
        lv_procty  TYPE /scwm/de_procty,
        lv_memid   TYPE char80,
        lv_has_brf TYPE abap_bool,
        lt_ctx     TYPE STANDARD TABLE OF zsi2o_psa_ctx,
        ls_ctx     TYPE zsi2o_psa_ctx.

  FIELD-SYMBOLS:
    <ls_brf>    TYPE any,
    <lv_any>    TYPE any,
    <lv_brfval> TYPE any.

  IF cs_huhdr-destination_bin IS NOT INITIAL
     OR cs_huhdr-destination_psa IS NOT INITIAL.
    RETURN.
  ENDIF.

  ASSIGN COMPONENT 'LGNUM' OF STRUCTURE cs_huhdr TO <lv_any>.
  IF sy-subrc = 0.
    lv_lgnum = <lv_any>.
  ENDIF.

  IF lv_lgnum IS INITIAL.
    lv_lgnum = /scwm/cl_tm=>sv_lgnum.
  ENDIF.

  IF lv_lgnum IS INITIAL.
    RETURN.
  ENDIF.

  IF cs_huhdr-huident IS INITIAL.
    RETURN.
  ENDIF.

  lv_memid = |ZI2O_PSA_BIN_{ lv_lgnum }|.

  IMPORT lt_ctx = lt_ctx
    FROM MEMORY ID lv_memid.

  IF lt_ctx IS INITIAL.
    RETURN.
  ENDIF.

  DELETE lt_ctx WHERE lgnum <> lv_lgnum.
  DELETE lt_ctx WHERE procty IS INITIAL.

  IF lt_ctx IS INITIAL.
    RETURN.
  ENDIF.

  READ TABLE lt_ctx INTO ls_ctx INDEX 1.
  IF sy-subrc = 0.
    lv_procty = ls_ctx-procty.
  ENDIF.

  IF lv_procty IS INITIAL.
    RETURN.
  ENDIF.

  DELETE lt_ctx WHERE procty <> lv_procty.

  IF lt_ctx IS INITIAL.
    RETURN.
  ENDIF.

  zcl_brfplus_data=>get_psa_bin(
    EXPORTING
      iv_lgnum  = lv_lgnum
    IMPORTING
      et_result = DATA(lt_psabin) ).

  IF lt_psabin IS INITIAL.
    RETURN.
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

  IF lv_has_brf IS INITIAL.
    RETURN.
  ENDIF.

  SORT lt_ctx BY itemid DESCENDING.

  CLEAR ls_ctx.
  READ TABLE lt_ctx INTO ls_ctx INDEX 1.
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  IF ls_ctx-bin IS INITIAL
     OR ls_ctx-psa IS INITIAL.
    RETURN.
  ENDIF.

  cs_huhdr-destination_bin = ls_ctx-bin.
  cs_huhdr-destination_psa = ls_ctx-psa.

  DELETE lt_ctx INDEX 1.

  EXPORT lt_ctx = lt_ctx
    TO MEMORY ID lv_memid.

ENDMETHOD.
