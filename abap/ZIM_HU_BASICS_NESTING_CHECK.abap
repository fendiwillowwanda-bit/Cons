METHOD /scwm/if_ex_hu_basics_nesting~check.

  DATA: lv_lgnum        TYPE /scwm/lgnum,
        lv_dest_bin     TYPE /scwm/lgpla,
        lv_dest_psa     TYPE /scwm/de_psa,
        lv_old_top_guid TYPE /scwm/guid_hu,
        lv_new_top_guid TYPE /scwm/guid_hu,
        ls_curr_hu      TYPE /scwm/huhdr,
        ls_top_hu       TYPE /scwm/huhdr.

  FIELD-SYMBOLS:
    <ls_hu> TYPE /scwm/s_huhdr_int.


  lv_lgnum = cs_huhdr-lgnum.
  IF lv_lgnum IS INITIAL.
    lv_lgnum = cs_destination-lgnum.
  ENDIF.

  IF lv_lgnum IS INITIAL.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* Get destination from source/sub HU first
*--------------------------------------------------------------------*
  lv_dest_bin = cs_huhdr-destination_bin.
  lv_dest_psa = cs_huhdr-destination_psa.

*--------------------------------------------------------------------*
* If source is blank, get destination from destination/new HU
*--------------------------------------------------------------------*
  IF lv_dest_bin IS INITIAL
     AND lv_dest_psa IS INITIAL.
    lv_dest_bin = cs_destination-destination_bin.
    lv_dest_psa = cs_destination-destination_psa.
  ENDIF.

*--------------------------------------------------------------------*
* If still blank, read current HU from DB
*--------------------------------------------------------------------*
  IF lv_dest_bin IS INITIAL
     AND lv_dest_psa IS INITIAL
     AND cs_huhdr-guid_hu IS NOT INITIAL.

    SELECT SINGLE *
      FROM /scwm/huhdr
      INTO ls_curr_hu
      WHERE guid_hu = cs_huhdr-guid_hu.

    IF sy-subrc = 0.
      lv_dest_bin     = ls_curr_hu-destination_bin.
      lv_dest_psa     = ls_curr_hu-destination_psa.
      lv_old_top_guid = ls_curr_hu-guid_hu_top.
    ENDIF.

  ENDIF.

*--------------------------------------------------------------------*
* If still blank, read old top HU from DB
*--------------------------------------------------------------------*
  IF lv_dest_bin IS INITIAL
     AND lv_dest_psa IS INITIAL.

    IF lv_old_top_guid IS INITIAL.
      lv_old_top_guid = cs_huhdr-guid_hu_top.
    ENDIF.

    IF lv_old_top_guid IS NOT INITIAL.

      SELECT SINGLE *
        FROM /scwm/huhdr
        INTO ls_top_hu
        WHERE guid_hu = lv_old_top_guid.

      IF sy-subrc = 0.
        lv_dest_bin = ls_top_hu-destination_bin.
        lv_dest_psa = ls_top_hu-destination_psa.
      ENDIF.

    ENDIF.

  ENDIF.

*--------------------------------------------------------------------*
* If still blank, try hierarchy tables
*--------------------------------------------------------------------*
  IF lv_dest_bin IS INITIAL
     AND lv_dest_psa IS INITIAL.

    LOOP AT ct_highers ASSIGNING <ls_hu>.
      IF <ls_hu>-destination_bin IS NOT INITIAL
         OR <ls_hu>-destination_psa IS NOT INITIAL.
        lv_dest_bin = <ls_hu>-destination_bin.
        lv_dest_psa = <ls_hu>-destination_psa.
        EXIT.
      ENDIF.
    ENDLOOP.

  ENDIF.

  IF lv_dest_bin IS INITIAL
     AND lv_dest_psa IS INITIAL.

    LOOP AT ct_higherd ASSIGNING <ls_hu>.
      IF <ls_hu>-destination_bin IS NOT INITIAL
         OR <ls_hu>-destination_psa IS NOT INITIAL.
        lv_dest_bin = <ls_hu>-destination_bin.
        lv_dest_psa = <ls_hu>-destination_psa.
        EXIT.
      ENDIF.
    ENDLOOP.

  ENDIF.

  IF lv_dest_bin IS INITIAL
     AND lv_dest_psa IS INITIAL.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* FIX: fill the runtime structures unconditionally, BEFORE checking
* whether the new top HU already has a GUID. On a plain "Repack HU"
* the destination HU's GUID_HU/GUID_HU_TOP is frequently still blank
* at CHECK time (it gets assigned only once the HU is actually
* created), regardless of whether the result ends up nested (child)
* or as an independent HU at the same level. The old code put this
* block AFTER the GUID_HU_TOP lookup below and RETURNed before
* reaching it whenever the GUID wasn't there yet - so CS_DESTINATION
* (and therefore the Work Center "Final Dest. PSA/Bin" fields) never
* got the value, in both the "same level" and "child HU" cases.
*--------------------------------------------------------------------*
  cs_huhdr-destination_bin = lv_dest_bin.
  cs_huhdr-destination_psa = lv_dest_psa.

  cs_destination-destination_bin = lv_dest_bin.
  cs_destination-destination_psa = lv_dest_psa.

  LOOP AT ct_highers ASSIGNING <ls_hu>.
    <ls_hu>-destination_bin = lv_dest_bin.
    <ls_hu>-destination_psa = lv_dest_psa.
  ENDLOOP.

  LOOP AT ct_higherd ASSIGNING <ls_hu>.
    <ls_hu>-destination_bin = lv_dest_bin.
    <ls_hu>-destination_psa = lv_dest_psa.
  ENDLOOP.

*--------------------------------------------------------------------*
* New top HU after manual repack = CS_DESTINATION.
* This GUID can still be blank at CHECK time - the runtime structures
* above are already filled in that case, so we only skip the DB
* persistence below (it will be picked up again, e.g. by a later
* CHANGE event, once the GUID exists).
*--------------------------------------------------------------------*
  lv_new_top_guid = cs_destination-guid_hu.
  IF lv_new_top_guid IS INITIAL.
    lv_new_top_guid = cs_destination-guid_hu_top.
  ENDIF.

  IF lv_new_top_guid IS INITIAL.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* Persist new top HU + all child HUs under it
*--------------------------------------------------------------------*
  CALL FUNCTION 'ZFM_I2O_UPD_HU_TOP_DEST'
    IN UPDATE TASK
    EXPORTING
      iv_lgnum           = lv_lgnum
      iv_guid_top        = lv_new_top_guid
      iv_destination_bin = lv_dest_bin
      iv_destination_psa = lv_dest_psa.

ENDMETHOD.
