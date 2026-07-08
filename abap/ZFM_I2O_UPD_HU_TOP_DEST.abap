FUNCTION zfm_i2o_upd_hu_top_dest.
*"----------------------------------------------------------------------
*"*"Update Function Module:
*"
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_LGNUM) TYPE  /SCWM/LGNUM
*"     VALUE(IV_GUID_TOP) TYPE  /SCWM/GUID_HU
*"     VALUE(IV_DESTINATION_BIN) TYPE  /SCWM/LGPLA
*"     VALUE(IV_DESTINATION_PSA) TYPE  /SCWM/DE_PSA
*"----------------------------------------------------------------------

  CHECK iv_lgnum           IS NOT INITIAL.
  CHECK iv_guid_top        IS NOT INITIAL.
  CHECK iv_destination_bin IS NOT INITIAL.
  CHECK iv_destination_psa IS NOT INITIAL.

*--------------------------------------------------------------------*
* Update TOP HU
*--------------------------------------------------------------------*
  UPDATE /scwm/huhdr
    SET destination_bin = iv_destination_bin
        destination_psa = iv_destination_psa
    WHERE lgnum   = iv_lgnum
      AND guid_hu = iv_guid_top.

*--------------------------------------------------------------------*
* Update all SUB HUs under same top HU
*--------------------------------------------------------------------*
  UPDATE /scwm/huhdr
    SET destination_bin = iv_destination_bin
        destination_psa = iv_destination_psa
    WHERE lgnum       = iv_lgnum
      AND guid_hu_top = iv_guid_top.

ENDFUNCTION.
