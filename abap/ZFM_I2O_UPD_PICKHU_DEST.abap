FUNCTION zfm_i2o_upd_pickhu_dest.
*"----------------------------------------------------------------------
*"*"Update Function Module:
*"
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_LGNUM) TYPE  /SCWM/LGNUM
*"     VALUE(IV_HUIDENT) TYPE  /SCWM/DE_HUIDENT
*"     VALUE(IV_DESTINATION_BIN) TYPE  /SCWM/LGPLA
*"     VALUE(IV_DESTINATION_PSA) TYPE  /SCWM/DE_PSA
*"----------------------------------------------------------------------

  DATA: ls_huhdr    TYPE /scwm/huhdr,
        lv_top_guid TYPE /scwm/guid_hu.

  CHECK iv_lgnum           IS NOT INITIAL.
  CHECK iv_huident         IS NOT INITIAL.
  CHECK iv_destination_bin IS NOT INITIAL.
  CHECK iv_destination_psa IS NOT INITIAL.

*--------------------------------------------------------------------*
* Get exact pick HU
*--------------------------------------------------------------------*
  SELECT SINGLE *
    FROM /scwm/huhdr
    INTO ls_huhdr
   WHERE lgnum   = iv_lgnum
     AND huident = iv_huident.

  IF sy-subrc <> 0.

    SELECT SINGLE vlenr
      FROM /scwm/ordim_o
      INTO @DATA(lv_huident)
     WHERE lgnum = @iv_lgnum
       AND nlpla = @iv_destination_bin
       AND vlenr <> @space.

    IF sy-subrc <> 0.
      SELECT SINGLE nlenr
        FROM /scwm/ordim_o
        INTO @lv_huident
       WHERE lgnum = @iv_lgnum
         AND nlpla = @iv_destination_bin
         AND nlenr <> @space.
    ENDIF.

    IF lv_huident IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE *
      FROM /scwm/huhdr
      INTO ls_huhdr
     WHERE lgnum   = iv_lgnum
       AND huident = lv_huident.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

  ENDIF.

*--------------------------------------------------------------------*
* Determine top HU
*--------------------------------------------------------------------*
  lv_top_guid = ls_huhdr-guid_hu_top.

  IF lv_top_guid IS INITIAL.
    lv_top_guid = ls_huhdr-guid_hu.
  ENDIF.

  IF lv_top_guid IS INITIAL.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* Update top HU
*--------------------------------------------------------------------*
  UPDATE /scwm/huhdr
    SET destination_bin = iv_destination_bin
        destination_psa = iv_destination_psa
   WHERE lgnum   = iv_lgnum
     AND guid_hu = lv_top_guid.

*--------------------------------------------------------------------*
* Update child HUs under same top HU
*--------------------------------------------------------------------*
  UPDATE /scwm/huhdr
    SET destination_bin = iv_destination_bin
        destination_psa = iv_destination_psa
   WHERE lgnum       = iv_lgnum
     AND guid_hu_top = lv_top_guid.

ENDFUNCTION.
