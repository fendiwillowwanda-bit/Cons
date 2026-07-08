METHOD /scwm/if_ex_core_cr_int_cr~insert.

  DATA: lv_lgnum   TYPE /scwm/lgnum,
        lv_procty  TYPE /scwm/de_procty,
        lv_huident TYPE /scwm/de_huident,
        lv_memid   TYPE char80,
        lv_has_brf TYPE abap_bool,
        lt_ctx     TYPE STANDARD TABLE OF zsi2o_psa_ctx,
        ls_ctx     TYPE zsi2o_psa_ctx.

  FIELD-SYMBOLS:
    <ls_brf>    TYPE any,
    <lv_brfval> TYPE any.

  lv_lgnum  = is_ltap-lgnum.
  lv_procty = is_ltap-procty.

  CHECK lv_lgnum  IS NOT INITIAL.
  CHECK lv_procty IS NOT INITIAL.

*--------------------------------------------------------------------*
* BRF+ scope check only: LGNUM + PROCTY
*--------------------------------------------------------------------*
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

*--------------------------------------------------------------------*
* Import PSA/BIN context from ENRICH_DATA
*--------------------------------------------------------------------*
  lv_memid = |ZI2O_PSA_BIN_{ lv_lgnum }|.

  IMPORT lt_ctx = lt_ctx
    FROM MEMORY ID lv_memid.

  IF lt_ctx IS INITIAL.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* Match by DOCID + ITEMID if available
*--------------------------------------------------------------------*
  READ TABLE lt_ctx INTO ls_ctx
    WITH KEY lgnum  = is_ltap-lgnum
             procty = is_ltap-procty
             docid  = is_ltap-rdocid
             itemid = is_ltap-ritmid.

  IF sy-subrc NE 0.
    READ TABLE lt_ctx INTO ls_ctx
      WITH KEY lgnum  = is_ltap-lgnum
               procty = is_ltap-procty
               docid  = is_ltap-qdocid
               itemid = is_ltap-qitmid.
  ENDIF.

*--------------------------------------------------------------------*
* Fallback: match by destination bin from LTAP
*--------------------------------------------------------------------*
  IF sy-subrc NE 0
     AND is_ltap-nlpla IS NOT INITIAL.

    READ TABLE lt_ctx INTO ls_ctx
      WITH KEY lgnum  = is_ltap-lgnum
               procty = is_ltap-procty
               bin    = is_ltap-nlpla.

  ENDIF.

  IF sy-subrc NE 0.
    RETURN.
  ENDIF.

  IF ls_ctx-bin IS INITIAL
     OR ls_ctx-psa IS INITIAL.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* FIX: the method matched and validated the PSA/BIN context but never
* actually applied it anywhere - IS_LTAP is import-only, so the only
* way to get the value onto the pick HU is to call the update FM that
* already exists for exactly this purpose (ZFM_I2O_UPD_PICKHU_DEST).
* That call was missing, so this BAdI silently did nothing.
* NLENR/VLENR are the destination/source HU fields on the WT item -
* adjust the field names below if your IS_LTAP type names them
* differently.
*--------------------------------------------------------------------*
  lv_huident = is_ltap-nlenr.
  IF lv_huident IS INITIAL.
    lv_huident = is_ltap-vlenr.
  ENDIF.

  IF lv_huident IS INITIAL.
    RETURN.
  ENDIF.

  CALL FUNCTION 'ZFM_I2O_UPD_PICKHU_DEST'
    IN UPDATE TASK
    EXPORTING
      iv_lgnum           = lv_lgnum
      iv_huident         = lv_huident
      iv_destination_bin = ls_ctx-bin
      iv_destination_psa = ls_ctx-psa.

ENDMETHOD.
