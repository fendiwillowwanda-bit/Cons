METHOD /scwm/if_ex_hu_basics_huhdr~create.

* CAVEAT on the staging-queue path below (kept, not changed):
* LV_PROCTY is picked from whatever context row happens to be first
* in LT_CTX (sorted LGNUM/PROCTY/DOCID/ITEMID ascending), not from
* anything tied to the HU actually being created. Fine as long as
* only one process type is queued per LGNUM at a time; if that stops
* holding true, pass a real correlation key through instead of
* guessing from queue order.
*
* FIX: manual "Repack HU" at the work center (OB02) never runs
* ENRICH_DATA, so LT_CTX is always empty for it and this method used
* to RETURN with the new HU's destination left blank - confirmed via
* debugger (LT_CTX = Initial Standard Table at the IF check). Added
* PATH 2 below: when the staging queue has nothing, find the SOURCE
* HU via the warehouse task that moved stock into this new HU
* (NLENR = this HU, VLENR = source HU) and copy its destination
* bin/psa. Works for a plain 1:1 repack (single HU) and for an HU
* split (each new HU independently finds its own source WT). If the
* new HU already has a GUID_HU_TOP at creation (nested case), also
* push the value through the whole hierarchy via
* ZFM_I2O_UPD_HU_TOP_DEST so the top HU + siblings stay in sync -
* CS_HUHDR only updates the one record being created right now.

  DATA: lv_lgnum       TYPE /scwm/lgnum,
        lv_procty      TYPE /scwm/de_procty,
        lv_memid       TYPE char80,
        lv_has_brf     TYPE abap_bool,
        lv_src_huident TYPE /scwm/de_huident,
        lt_ctx         TYPE STANDARD TABLE OF zsi2o_psa_ctx,
        ls_ctx         TYPE zsi2o_psa_ctx,
        ls_src_hu      TYPE /scwm/huhdr.

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

*--------------------------------------------------------------------*
* PATH 1: staging queue populated by ENRICH_DATA (MFG staging flow
* only - always empty for a manual OB02 repack).
*--------------------------------------------------------------------*
  lv_memid = |ZI2O_PSA_BIN_{ lv_lgnum }|.

  IMPORT lt_ctx = lt_ctx
    FROM MEMORY ID lv_memid.

  IF lt_ctx IS NOT INITIAL.

    DELETE lt_ctx WHERE lgnum <> lv_lgnum.
    DELETE lt_ctx WHERE procty IS INITIAL.

    IF lt_ctx IS NOT INITIAL.

      READ TABLE lt_ctx INTO ls_ctx INDEX 1.
      IF sy-subrc = 0.
        lv_procty = ls_ctx-procty.
      ENDIF.

      IF lv_procty IS NOT INITIAL.

        DELETE lt_ctx WHERE procty <> lv_procty.

        IF lt_ctx IS NOT INITIAL.

          zcl_brfplus_data=>get_psa_bin(
            EXPORTING
              iv_lgnum  = lv_lgnum
            IMPORTING
              et_result = DATA(lt_psabin) ).

          IF lt_psabin IS NOT INITIAL.

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

              SORT lt_ctx BY itemid DESCENDING.

              CLEAR ls_ctx.
              READ TABLE lt_ctx INTO ls_ctx INDEX 1.
              IF sy-subrc = 0
                 AND ls_ctx-bin IS NOT INITIAL
                 AND ls_ctx-psa IS NOT INITIAL.

                cs_huhdr-destination_bin = ls_ctx-bin.
                cs_huhdr-destination_psa = ls_ctx-psa.

                DELETE lt_ctx INDEX 1.

                EXPORT lt_ctx = lt_ctx
                  TO MEMORY ID lv_memid.

              ENDIF.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDIF.

  IF cs_huhdr-destination_bin IS NOT INITIAL
     AND cs_huhdr-destination_psa IS NOT INITIAL.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* PATH 2 (new): OB02 manual repack - no staging context available.
* Find the source HU via the WT that put stock into this new HU.
* Check open WTs first, then confirmed/history in case the WT that
* triggered this HU creation already closed by the time CREATE fires.
*--------------------------------------------------------------------*
  SELECT SINGLE vlenr
    FROM /scwm/ordim_o
    INTO @lv_src_huident
   WHERE lgnum = @lv_lgnum
     AND nlenr = @cs_huhdr-huident
     AND vlenr <> @space.

  IF sy-subrc <> 0.
    SELECT SINGLE vlenr
      FROM /scwm/ordim_c
      INTO @lv_src_huident
     WHERE lgnum = @lv_lgnum
       AND nlenr = @cs_huhdr-huident
       AND vlenr <> @space.
  ENDIF.

  IF lv_src_huident IS INITIAL.
    RETURN.
  ENDIF.

  SELECT SINGLE destination_bin, destination_psa
    FROM /scwm/huhdr
    INTO CORRESPONDING FIELDS OF @ls_src_hu
   WHERE lgnum   = @lv_lgnum
     AND huident = @lv_src_huident.

  IF sy-subrc <> 0
     OR ls_src_hu-destination_bin IS INITIAL
     OR ls_src_hu-destination_psa IS INITIAL.
    RETURN.
  ENDIF.

  cs_huhdr-destination_bin = ls_src_hu-destination_bin.
  cs_huhdr-destination_psa = ls_src_hu-destination_psa.

*--------------------------------------------------------------------*
* Nested case: this new HU already has a top at creation time -
* CS_HUHDR above only saves this one record, so push the value
* through the whole hierarchy (top HU + all its children) too.
* Single-level HU: GUID_HU_TOP is blank, nothing else to update -
* this record IS the lowest (and only) level, already handled above.
*--------------------------------------------------------------------*
  IF cs_huhdr-guid_hu_top IS NOT INITIAL.

    CALL FUNCTION 'ZFM_I2O_UPD_HU_TOP_DEST'
      IN UPDATE TASK
      EXPORTING
        iv_lgnum           = lv_lgnum
        iv_guid_top        = cs_huhdr-guid_hu_top
        iv_destination_bin = cs_huhdr-destination_bin
        iv_destination_psa = cs_huhdr-destination_psa.

  ENDIF.

ENDMETHOD.
