REPORT zrp_i2o_hu_dest_reconcile.

* Standalone reconciliation job for HU repack (OB02 / RF /SCWM/RFUI).
* The BAdI-based approach (HU_BASICS_HUHDR~CREATE, both by setting
* CS_HUHDR directly and by an explicit UPDATE via
* CALL FUNCTION ... IN UPDATE TASK) was confirmed via debugger to
* compute the correct source-HU destination_bin/psa, but the value
* still came out blank in /scwm/huhdr afterwards (checked directly via
* SE16, not just the Work Center UI) - the packing framework's own
* commit/LUW handling for this transaction doesn't reliably carry it
* through. Rather than keep fighting that timing, this report runs as
* its own independent LUW/job and does a plain synchronous UPDATE, so
* there is nothing to race against.
*
* Logic: for any HU in LGNUM with blank DESTINATION_BIN/PSA, find the
* source HU via the warehouse task that moved stock into it
* (NLENR = this HU, VLENR = source HU - checked in both open and
* confirmed WT tables), then copy the source's destination_bin/psa.
* HUs with no matching WT (i.e. not created by a repack) are silently
* skipped - this only ever touches HUs it can resolve a source for.
*
* Schedule via SM36/SM37 on a short interval (e.g. every 5-10 min).
* Run with P_TEST = 'X' first to see what it WOULD change before
* letting it write.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
PARAMETERS: p_lgnum TYPE /scwm/lgnum OBLIGATORY,
            p_test  TYPE abap_bool AS CHECKBOX DEFAULT abap_true.
SELECTION-SCREEN END OF BLOCK b1.

DATA: lt_huhdr         TYPE STANDARD TABLE OF /scwm/huhdr,
      ls_huhdr         TYPE /scwm/huhdr,
      lv_src_huident   TYPE /scwm/de_huident,
      ls_src_hu        TYPE /scwm/huhdr,
      lv_count_checked TYPE i,
      lv_count_found   TYPE i,
      lv_count_updated TYPE i.

START-OF-SELECTION.

  SELECT *
    FROM /scwm/huhdr
    INTO TABLE @lt_huhdr
   WHERE lgnum           = @p_lgnum
     AND destination_bin = @space
     AND destination_psa = @space.

  WRITE: / |Found { lines( lt_huhdr ) } HU(s) with blank destination in { p_lgnum }.|.
  SKIP.

  LOOP AT lt_huhdr INTO ls_huhdr.

    lv_count_checked = lv_count_checked + 1.

    CLEAR: lv_src_huident, ls_src_hu.

*   Open WT first, then confirmed/history (in case the WT that
*   created this HU has already closed).
    SELECT SINGLE vlenr
      FROM /scwm/ordim_o
      INTO @lv_src_huident
     WHERE lgnum = @p_lgnum
       AND nlenr = @ls_huhdr-huident
       AND vlenr <> @space.

    IF sy-subrc <> 0.
      SELECT SINGLE vlenr
        FROM /scwm/ordim_c
        INTO @lv_src_huident
       WHERE lgnum = @p_lgnum
         AND nlenr = @ls_huhdr-huident
         AND vlenr <> @space.
    ENDIF.

    IF lv_src_huident IS INITIAL.
*     No WT links back to a source HU - not a repack result, skip.
      CONTINUE.
    ENDIF.

    SELECT SINGLE destination_bin, destination_psa
      FROM /scwm/huhdr
      INTO CORRESPONDING FIELDS OF @ls_src_hu
     WHERE lgnum   = @p_lgnum
       AND huident = @lv_src_huident.

    IF sy-subrc <> 0
       OR ls_src_hu-destination_bin IS INITIAL
       OR ls_src_hu-destination_psa IS INITIAL.
*     Source HU itself has no destination to copy - skip.
      CONTINUE.
    ENDIF.

    lv_count_found = lv_count_found + 1.

    WRITE: / |{ ls_huhdr-huident } <- source { lv_src_huident }: |,
             |{ ls_src_hu-destination_psa } / { ls_src_hu-destination_bin }|.

    IF p_test = abap_false.

      UPDATE /scwm/huhdr
        SET destination_bin = ls_src_hu-destination_bin
            destination_psa = ls_src_hu-destination_psa
       WHERE lgnum   = p_lgnum
         AND huident = ls_huhdr-huident.

      IF sy-subrc = 0.
        lv_count_updated = lv_count_updated + 1.
      ENDIF.

    ENDIF.

  ENDLOOP.

  SKIP.

  IF p_test = abap_true.
    WRITE: / |TEST MODE - nothing written. { lv_count_checked } checked, |,
             |{ lv_count_found } would be updated (listed above). |,
             |Uncheck "Test Run" to apply.|.
  ELSE.
    COMMIT WORK.
    WRITE: / |{ lv_count_updated } of { lv_count_checked } HU(s) updated.|.
  ENDIF.
