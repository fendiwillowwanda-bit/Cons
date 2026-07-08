*&---------------------------------------------------------------------*
*& Include          LZFG_I2O_RF_RECEIVING_HUSF39
*&---------------------------------------------------------------------*

FORM frm_derive_plant_from_entitled
  USING    iv_entitled TYPE /scwm/de_entitled
  CHANGING cv_plant    TYPE c.
* NOTE: generic C type, no LENGTH here - FORM interfaces don't allow a
* LENGTH addition on generic types (only DATA/TYPES/CONSTANTS do); the
* actual length (4) comes from the caller's TYPE c LENGTH 4 variable.

  CLEAR cv_plant.

  IF iv_entitled CP 'PLANT*' AND strlen( iv_entitled ) >= 9.
    cv_plant = iv_entitled+5(4).        "PLANTSGAD -> SGAD
  ELSEIF strlen( iv_entitled ) = 4.
    " Entitled already holds a bare plant/SCU code (any plant, not
    " just SGAD) - avoid hardcoding a single site here.
    cv_plant = iv_entitled.
  ENDIF.

ENDFORM.

FORM frm_determine_packspec_rehu
  USING    iv_matid     TYPE /scwm/de_matid
           iv_plant     TYPE c
           iv_pak_locid TYPE /sapapo/locid
           iv_qty       TYPE /scdl/dl_quantity
           iv_uom       TYPE /scwm/de_unit
  CHANGING cv_guid_ps   TYPE /scwm/de_guid_ps.

* Resolves the PackSpec explicitly, the same way the proven-working
* Process Order receiving flow does (frm_pmat_from_packspec_mrhu),
* instead of only finding out whether /SCWM/HU_AUTOPACK_IBDLV managed
* to determine one internally after the fact. PAK_PLANT and PAK_LOCID
* are both offered as condition fields - whichever one the '0IBD'
* condition table actually keys on will match; set_comp no-ops for the
* field that doesn't exist/apply.

  CONSTANTS lc_procedure TYPE /scwm/de_dlvap_ctlist VALUE '0IBD'.

  DATA: ls_det_fields TYPE /scwm/pak_com_i,
        ls_cond       TYPE /scwm/s_ps_cond,
        ls_dlv_item   TYPE /scwm/dlv_docid_item_str,
        lt_packspec   TYPE /scwm/tt_guid_ps,
        lv_valid_on   TYPE timestamp.

  FIELD-SYMBOLS <lv_any> TYPE any.

  DEFINE set_comp.
    ASSIGN COMPONENT &1 OF STRUCTURE &2 TO <lv_any>.
    IF sy-subrc = 0 AND <lv_any> IS ASSIGNED.
      <lv_any> = &3.
      UNASSIGN <lv_any>.
    ENDIF.
  END-OF-DEFINITION.

  CLEAR cv_guid_ps.

  IF iv_matid IS INITIAL.
    RETURN.
  ENDIF.

  CLEAR ls_det_fields.
  set_comp 'PAK_MATID'    ls_det_fields iv_matid.
  set_comp 'PAK_REFMATID' ls_det_fields iv_matid.

  IF iv_plant IS NOT INITIAL.
    set_comp 'PAK_PLANT' ls_det_fields iv_plant.
  ENDIF.

  IF iv_pak_locid IS NOT INITIAL.
    set_comp 'PAK_LOCID' ls_det_fields iv_pak_locid.
  ENDIF.

  CLEAR ls_cond.
  ls_cond-quantity = iv_qty.
  ls_cond-unit_q   = iv_uom.

  CLEAR ls_dlv_item.

  GET TIME STAMP FIELD lv_valid_on.

  CALL FUNCTION '/SCWM/PS_FIND_AND_EVALUATE'
    EXPORTING
      is_fields       = ls_det_fields
      iv_procedure    = lc_procedure
      is_condition    = ls_cond
      i_data          = ls_dlv_item
      iv_valid_on     = lv_valid_on
      iv_read_refmat  = abap_true
    IMPORTING
      et_packspec     = lt_packspec
    EXCEPTIONS
      determine_error = 1
      read_error      = 2
      no_record_found = 3
      OTHERS          = 4.

  IF sy-subrc <> 0 OR lt_packspec IS INITIAL.
    RETURN.
  ENDIF.

  READ TABLE lt_packspec INTO cv_guid_ps INDEX 1.

ENDFORM.

FORM frm_build_autopack_items_rehu
  USING    iv_lgnum   TYPE /scwm/lgnum
           iv_docid   TYPE /scwm/de_docid
           iv_itemid  TYPE /scdl/dl_itemid
           iv_doccat  TYPE /scwm/de_doccat
           iv_prod    TYPE /scwm/de_rf_matnr
           iv_batch   TYPE /scwm/de_rf_charg
           iv_qty     TYPE /scdl/dl_quantity
           iv_uom     TYPE /scwm/de_unit
           is_rehu    TYPE /scwm/s_rf_admin_rehu
  CHANGING ct_items   TYPE /scwm/tt_ps_autopack
           cv_guid_ps TYPE /scwm/de_guid_ps.

  DATA: ls_auto_item TYPE /scwm/s_ps_autopack,
        ls_rehu_item TYPE /scwm/dlv_item_out_prd_str,
        ls_proci     TYPE /scdl/db_proci_i,
        lv_matid     TYPE /scwm/de_matid,
        lv_batchid   TYPE /scwm/de_batchid,
        lv_entitled  TYPE /scwm/de_entitled,
        lv_prod_int  TYPE matnr,
        lv_itemid    TYPE /scdl/dl_itemid,
        lv_plant     TYPE c LENGTH 4,
        lv_scu       TYPE /sapapo/locno,
        lv_pak_locid TYPE /sapapo/locid,
        lv_cat       TYPE /lime/stock_category,
        lv_vfdat     TYPE /scwm/sled.

  FIELD-SYMBOLS <lv_any> TYPE any.

  DEFINE set_comp.
    ASSIGN COMPONENT &1 OF STRUCTURE &2 TO <lv_any>.
    IF sy-subrc = 0 AND <lv_any> IS ASSIGNED.
      <lv_any> = &3.
      UNASSIGN <lv_any>.
    ENDIF.
  END-OF-DEFINITION.

  DEFINE get_comp.
    CLEAR &2.
    ASSIGN COMPONENT &1 OF STRUCTURE &3 TO <lv_any>.
    IF sy-subrc = 0 AND <lv_any> IS ASSIGNED.
      &2 = <lv_any>.
      UNASSIGN <lv_any>.
    ENDIF.
  END-OF-DEFINITION.

  CLEAR: ct_items,
         cv_guid_ps,
         ls_proci,
         ls_auto_item,
         ls_rehu_item,
         lv_batchid,
         lv_cat,
         lv_vfdat,
         lv_pak_locid.

*--------------------------------------------------------------------*
* Get exact delivery item
*--------------------------------------------------------------------*
  IF iv_itemid IS NOT INITIAL.
    SELECT SINGLE *
      FROM /scdl/db_proci_i
      WHERE docid  = @iv_docid
        AND itemid = @iv_itemid
      INTO @ls_proci.
  ENDIF.

  IF sy-subrc <> 0 AND iv_batch IS NOT INITIAL.
    SELECT SINGLE *
      FROM /scdl/db_proci_i
      WHERE docid   = @iv_docid
        AND batchno = @iv_batch
      INTO @ls_proci.
  ENDIF.

  " Falling straight through to "docid only" below (a multi-item
  " delivery) grabs whatever row the DB returns first, regardless of
  " which product was actually scanned - confirmed live: it picked
  " item 10's product instead of the intended item 20, so the wrong
  " PackSpec (belonging to item 10's material) got determined. Match
  " by the scanned product first, same fallback used in
  " ZFM_I2O_RF_REHU_CRT_BATCH_PAI, before resorting to that blind grab.
  IF sy-subrc <> 0 AND iv_prod IS NOT INITIAL.
    DATA(lv_prod_lookup) = CONV matnr( iv_prod ).

    CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
      EXPORTING
        input  = lv_prod_lookup
      IMPORTING
        output = lv_prod_lookup.

    SELECT SINGLE *
      FROM /scdl/db_proci_i
      WHERE docid     = @iv_docid
        AND productno = @lv_prod_lookup
      INTO @ls_proci.
  ENDIF.

  IF sy-subrc <> 0.
    SELECT SINGLE *
      FROM /scdl/db_proci_i
      WHERE docid = @iv_docid
      INTO @ls_proci.
  ENDIF.

  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  lv_itemid   = ls_proci-itemid.
  lv_prod_int = ls_proci-productno.
  lv_matid    = ls_proci-productid.
  lv_entitled = ls_proci-entitled.

*--------------------------------------------------------------------*
* RF item
*--------------------------------------------------------------------*
  READ TABLE is_rehu-itms INTO ls_rehu_item
    WITH KEY docid  = iv_docid
             itemid = lv_itemid.

  IF sy-subrc <> 0 AND lv_prod_int IS NOT INITIAL.
    READ TABLE is_rehu-itms INTO ls_rehu_item
      WITH KEY product-productno = lv_prod_int.
  ENDIF.

  IF sy-subrc <> 0.
    READ TABLE is_rehu-itms INTO ls_rehu_item
      WITH KEY docid = iv_docid.
  ENDIF.

  IF lv_prod_int IS INITIAL.
    lv_prod_int = iv_prod.
  ENDIF.

  CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
    EXPORTING
      input  = lv_prod_int
    IMPORTING
      output = lv_prod_int.

  IF lv_matid IS INITIAL.
    lv_matid = ls_rehu_item-product-productid.
  ENDIF.

  IF lv_entitled IS INITIAL.
    lv_entitled = ls_rehu_item-sapext-entitled.
  ENDIF.

*--------------------------------------------------------------------*
* PackSpec condition key: Supply Chain Unit (PAK_LOCID)
* Try multiple LOCNO conventions, same priority order used by the
* proven-working Process Order receiving flow (frm_build_autopack_
* items_mrhu): entitled as-is first, then 'SCU'+plant, then a
* reconstructed 'PLANT'+plant. Whichever one actually has a location
* master record in /SAPAPO/LOC wins; the others are no-ops.
*--------------------------------------------------------------------*
  CLEAR: lv_plant,
         lv_scu,
         lv_pak_locid.

  PERFORM frm_derive_plant_from_entitled
    USING    lv_entitled
    CHANGING lv_plant.

  IF lv_pak_locid IS INITIAL AND lv_entitled IS NOT INITIAL.
    SELECT SINGLE locid
      FROM /sapapo/loc
      WHERE locno = @lv_entitled
      INTO @lv_pak_locid.
  ENDIF.

  IF lv_pak_locid IS INITIAL AND lv_plant IS NOT INITIAL.
    CONCATENATE 'SCU' lv_plant INTO lv_scu. "e.g. SCUSGAD

    SELECT SINGLE locid
      FROM /sapapo/loc
      WHERE locno = @lv_scu
      INTO @lv_pak_locid.
  ENDIF.

  IF lv_pak_locid IS INITIAL AND lv_plant IS NOT INITIAL.
    DATA(lv_locno_plant) = |PLANT{ lv_plant }|.

    SELECT SINGLE locid
      FROM /sapapo/loc
      WHERE locno = @lv_locno_plant
      INTO @lv_pak_locid.
  ENDIF.

*--------------------------------------------------------------------*
* Determine PackSpec explicitly (mirrors the proven-working Process
* Order flow) instead of only finding out afterwards whether
* /SCWM/HU_AUTOPACK_IBDLV managed to determine one internally.
*--------------------------------------------------------------------*
  PERFORM frm_determine_packspec_rehu
    USING    lv_matid
             lv_plant
             lv_pak_locid
             iv_qty
             iv_uom
    CHANGING cv_guid_ps.

*--------------------------------------------------------------------*
* Stock category (mirrors the proven-working Process Order flow,
* frm_build_autopack_items_mrhu)
*--------------------------------------------------------------------*
  get_comp 'CAT' lv_cat ls_proci.

  IF lv_cat IS INITIAL.
    get_comp 'STOCK_CAT' lv_cat ls_proci.
  ENDIF.

  IF lv_cat IS INITIAL.
    get_comp 'STOCK_CATEGORY' lv_cat ls_proci.
  ENDIF.

  IF lv_cat IS INITIAL.
    get_comp 'STOCK_TYPE' lv_cat ls_proci.
  ENDIF.

* Confirmed live via debugger: for Procurement, ls_proci's raw CAT
* resolves to 'F2', not 'P' - the 'P' -> 'P2' override copied from the
* Process Order flow never actually applied here, it was a dead branch
* for this scenario. Removed so lv_cat is used exactly as resolved
* from the delivery item, matching what /scwm/aqua actually stores.
*--------------------------------------------------------------------*
* VFDAT / SLED
*--------------------------------------------------------------------*
  get_comp 'VFDAT' lv_vfdat ls_proci.

  IF lv_vfdat IS INITIAL.
    get_comp 'SLED' lv_vfdat ls_proci.
  ENDIF.

  IF lv_vfdat IS INITIAL.
    get_comp 'EXPIRY_DATE' lv_vfdat ls_proci.
  ENDIF.

  IF lv_vfdat IS INITIAL
  AND lv_prod_int IS NOT INITIAL
  AND iv_batch    IS NOT INITIAL
  AND lv_plant    IS NOT INITIAL.
    SELECT SINGLE vfdat
      FROM mcha
      WHERE matnr = @lv_prod_int
        AND werks = @lv_plant
        AND charg = @iv_batch
      INTO @lv_vfdat.
  ENDIF.

  IF lv_vfdat IS INITIAL
  AND lv_prod_int IS NOT INITIAL
  AND iv_batch    IS NOT INITIAL.
    SELECT SINGLE vfdat
      FROM mch1
      WHERE matnr = @lv_prod_int
        AND charg = @iv_batch
      INTO @lv_vfdat.
  ENDIF.

*--------------------------------------------------------------------*
* BATCHID - was never resolved before (declared but left blank),
* causing /SCWM/HU_AUTOPACK_IBDLV to reject with "Could not find the
* item to pack" since the stock/item structure carried no batch
* reference for a batch-managed material. Resolve it the same way the
* proven-working Process Order flow does.
*--------------------------------------------------------------------*
  get_comp 'BATCHID' lv_batchid ls_proci.

  IF lv_batchid IS INITIAL.
    get_comp 'BATCH_GUID' lv_batchid ls_proci.
  ENDIF.

  IF lv_batchid IS INITIAL.
    get_comp 'GUID_BATCH' lv_batchid ls_proci.
  ENDIF.

  IF lv_batchid IS INITIAL
  AND iv_lgnum    IS NOT INITIAL
  AND lv_matid    IS NOT INITIAL
  AND lv_entitled IS NOT INITIAL
  AND lv_cat      IS NOT INITIAL
  AND lv_vfdat    IS NOT INITIAL.

    SELECT SINGLE batchid ##WARN_OK
      FROM /scwm/aqua
      WHERE lgnum    = @iv_lgnum
        AND matid    = @lv_matid
        AND entitled = @lv_entitled
        AND cat      = @lv_cat
        AND vfdat    = @lv_vfdat
      INTO @lv_batchid.
  ENDIF.

*--------------------------------------------------------------------*
* STOCK
*--------------------------------------------------------------------*
  MOVE-CORRESPONDING ls_rehu_item-stock   TO ls_auto_item-stock.
  MOVE-CORRESPONDING ls_rehu_item-product TO ls_auto_item-stock.
  MOVE-CORRESPONDING ls_proci             TO ls_auto_item-stock.

  ls_auto_item-stock-qdocid  = iv_docid.
  ls_auto_item-stock-qdoccat = iv_doccat.
  ls_auto_item-stock-qitmid  = lv_itemid.

  set_comp 'LGNUM'         ls_auto_item-stock iv_lgnum.
  set_comp 'DOCCAT'        ls_auto_item-stock iv_doccat.
  set_comp 'MATID'         ls_auto_item-stock lv_matid.
  set_comp 'PRODUCTID'     ls_auto_item-stock lv_matid.
  set_comp 'PRODUCTNO'     ls_auto_item-stock lv_prod_int.
  set_comp 'PRODUCTNO_EXT' ls_auto_item-stock lv_prod_int.
  set_comp 'BATCHNO'       ls_auto_item-stock iv_batch.
  set_comp 'BATCHID'       ls_auto_item-stock lv_batchid.

  IF lv_cat IS NOT INITIAL.
    set_comp 'CAT' ls_auto_item-stock lv_cat.
  ENDIF.

  set_comp 'ENTITLED'      ls_auto_item-stock lv_entitled.
  set_comp 'ENTITLED_ROLE' ls_auto_item-stock 'BP'.
  set_comp 'QTY'           ls_auto_item-stock iv_qty.
  set_comp 'QUAN'          ls_auto_item-stock iv_qty.
  set_comp 'UOM'           ls_auto_item-stock iv_uom.
  set_comp 'UNIT'          ls_auto_item-stock iv_uom.

  IF cv_guid_ps IS NOT INITIAL.
    set_comp 'GUID_PS' ls_auto_item-stock cv_guid_ps.
  ENDIF.

*--------------------------------------------------------------------*
* COND
*--------------------------------------------------------------------*
  ls_auto_item-cond-quantity = iv_qty.
  ls_auto_item-cond-unit_q   = iv_uom.

*--------------------------------------------------------------------*
* DET for PackSpec determination
*--------------------------------------------------------------------*
  MOVE-CORRESPONDING ls_rehu_item         TO ls_auto_item-det.
  MOVE-CORRESPONDING ls_rehu_item-product TO ls_auto_item-det.
  MOVE-CORRESPONDING ls_rehu_item-sapext  TO ls_auto_item-det.
  MOVE-CORRESPONDING ls_proci             TO ls_auto_item-det.

  set_comp 'DOCCAT'       ls_auto_item-det iv_doccat.
  set_comp 'LGNUM'        ls_auto_item-det iv_lgnum.

  " PAK_PLANT is what the proven-working Process Order receiving flow
  " (frm_pmat_from_packspec_mrhu / frm_build_autopack_items_mrhu) keys
  " its PackSpec determination on - it never converts through
  " /SAPAPO/LOC for PAK_LOCID. Set both: PAK_PLANT as the primary key,
  " PAK_LOCID as a best-effort extra in case this procedure's condition
  " table also uses it (harmless if the field/lookup doesn't apply -
  " set_comp no-ops when the target component doesn't exist, and a
  " blank lv_pak_locid just leaves that field unset).
  set_comp 'PAK_PLANT'    ls_auto_item-det lv_plant.
  set_comp 'PAK_LOCID'    ls_auto_item-det lv_pak_locid.

  set_comp 'PAK_MATID'    ls_auto_item-det lv_matid.
  set_comp 'PAK_REFMATID' ls_auto_item-det lv_matid.
  set_comp 'MATID'        ls_auto_item-det lv_matid.
  set_comp 'PRODUCTID'    ls_auto_item-det lv_matid.

  set_comp 'PRODUCTNO'     ls_auto_item-det lv_prod_int.
  set_comp 'PRODUCTNO_EXT' ls_auto_item-det lv_prod_int.
  set_comp 'PRODUCT'       ls_auto_item-det lv_prod_int.
  set_comp 'MATNR'         ls_auto_item-det lv_prod_int.

  set_comp 'BATCHNO'      ls_auto_item-det iv_batch.
  set_comp 'BATCHID'      ls_auto_item-det lv_batchid.

  IF lv_cat IS NOT INITIAL.
    set_comp 'CAT' ls_auto_item-det lv_cat.
  ENDIF.

  set_comp 'ENTITLED'     ls_auto_item-det lv_entitled.
  set_comp 'ENTITLED_ROLE' ls_auto_item-det 'BP'.

  set_comp 'QUANTITY'     ls_auto_item-det iv_qty.
  set_comp 'QTY'          ls_auto_item-det iv_qty.
  set_comp 'UNIT_Q'       ls_auto_item-det iv_uom.
  set_comp 'UNIT'         ls_auto_item-det iv_uom.
  set_comp 'UOM'          ls_auto_item-det iv_uom.

  IF cv_guid_ps IS NOT INITIAL.
    set_comp 'GUID_PS' ls_auto_item-det cv_guid_ps.
  ENDIF.

  APPEND ls_auto_item TO ct_items.

ENDFORM.

FORM frm_prepare_zapack_hu.

  DATA: ls_huhdr       TYPE /scwm/s_huhdr_int,
        ls_huitm       TYPE /scwm/s_huitm_int,
        lv_guid_hu     TYPE x LENGTH 16,
        lv_guid_parent TYPE x LENGTH 16.

  FIELD-SYMBOLS <lv_any> TYPE any.

  DEFINE get_comp.
    IF &2 IS INITIAL.
      ASSIGN COMPONENT &1 OF STRUCTURE &3 TO <lv_any>.
      IF sy-subrc = 0 AND <lv_any> IS ASSIGNED.
        &2 = <lv_any>.
        UNASSIGN <lv_any>.
      ENDIF.
    ENDIF.
  END-OF-DEFINITION.

  CLEAR: gv_zapack_lines,
         gs_rf_rehu_hu,
         gt_zapack_hu.

  IF gv_zapack_idx IS INITIAL.
    gv_zapack_idx = 1.
  ENDIF.

  LOOP AT gt_zap_huhdr INTO ls_huhdr.

    CLEAR: gs_zapack_hu,
           lv_guid_hu.

    get_comp 'HUIDENT' gs_zapack_hu-huident ls_huhdr.
    get_comp 'GUID_HU' lv_guid_hu ls_huhdr.

    IF gs_zapack_hu-huident IS INITIAL.
      CONTINUE.
    ENDIF.

    LOOP AT gt_zap_huitm INTO ls_huitm.

      CLEAR lv_guid_parent.

      get_comp 'GUID_PARENT'    lv_guid_parent ls_huitm.
      get_comp 'GUID_HU_PARENT' lv_guid_parent ls_huitm.
      get_comp 'GUID_HU'        lv_guid_parent ls_huitm.

      IF lv_guid_parent <> lv_guid_hu.
        CONTINUE.
      ENDIF.

      get_comp 'QUAN'  gs_zapack_hu-qty ls_huitm.
      get_comp 'QTY'   gs_zapack_hu-qty ls_huitm.
      get_comp 'NISTA' gs_zapack_hu-qty ls_huitm.

      get_comp 'UNIT_Q' gs_zapack_hu-uom ls_huitm.
      get_comp 'UNIT'   gs_zapack_hu-uom ls_huitm.
      get_comp 'UOM'    gs_zapack_hu-uom ls_huitm.
      get_comp 'ALTME'  gs_zapack_hu-uom ls_huitm.
      get_comp 'MEINS'  gs_zapack_hu-uom ls_huitm.

      EXIT.

    ENDLOOP.

    IF gs_zapack_hu-qty IS INITIAL OR gs_zapack_hu-uom IS INITIAL.
      CONTINUE.
    ENDIF.

    READ TABLE gt_zapack_hu TRANSPORTING NO FIELDS
      WITH KEY huident = gs_zapack_hu-huident.

    IF sy-subrc <> 0.
      APPEND gs_zapack_hu TO gt_zapack_hu.
    ENDIF.

  ENDLOOP.

  gv_zapack_lines = lines( gt_zapack_hu ).

  CLEAR: gs_zapack_hu,
         gs_rf_rehu_hu.

ENDFORM.

FORM frm_rehu_hu_proposal_fallback
  USING    iv_procedure    TYPE /scwm/de_dlvap_ctlist
           iv_valid_on     TYPE timestamp
           iv_read_refmat  TYPE char1
           io_pack         TYPE REF TO /scwm/cl_dlv_pack_ibdl
  CHANGING ct_items        TYPE /scwm/tt_ps_autopack
           ct_huhdr        TYPE /scwm/tt_huhdr_int
           ct_huitm        TYPE /scwm/tt_huitm_int
           ct_return       TYPE bapirettab
           cv_severity     TYPE bapi_mtype.

* NOTE: not currently invoked from ZFM_I2O_RF_REHU_ZAPACK_PAI - the main
* flow calls /SCWM/HU_AUTOPACK_IBDLV directly and hard-errors when no
* PackSpec is found (per FDS 7.1: "Unable to proceed to next screen"),
* which this fallback's manual proposal path would otherwise bypass.
* Kept for reference / future use; wire it in deliberately if a
* fallback-without-PackSpec path is actually wanted.

  DATA: ls_det_fields TYPE /scwm/pak_com_i,
        ls_cond       TYPE /scwm/s_ps_cond,
        ls_dlv_item   TYPE /scwm/dlv_docid_item_str,
        lt_packspec   TYPE /scwm/tt_guid_ps,
        lt_pack       TYPE /scwm/tt_packitem,
        ls_pack       TYPE /scwm/s_packitem,
        ls_return     TYPE bapiret2,
        lt_return     TYPE bapirettab.

  FIELD-SYMBOLS <ls_item> TYPE /scwm/s_ps_autopack.

  CLEAR: ct_huhdr,
         ct_huitm,
         ct_return,
         cv_severity.

  LOOP AT ct_items ASSIGNING <ls_item>.

    CLEAR: ls_det_fields,
           ls_cond,
           ls_dlv_item,
           lt_packspec,
           ls_pack.

    MOVE-CORRESPONDING <ls_item>-det  TO ls_det_fields.
    MOVE-CORRESPONDING <ls_item>-cond TO ls_cond.

    ls_dlv_item-docid  = <ls_item>-stock-qdocid.
    ls_dlv_item-doccat = <ls_item>-stock-qdoccat.
    ls_dlv_item-itemid = <ls_item>-stock-qitmid.

    CALL FUNCTION '/SCWM/PS_FIND_AND_EVALUATE'
      EXPORTING
        is_fields          = ls_det_fields
        iv_procedure       = iv_procedure
        is_condition       = ls_cond
        i_data             = ls_dlv_item
        iv_valid_on        = iv_valid_on
        iv_read_refmat     = iv_read_refmat
        iv_buffer_packspec = space
      IMPORTING
        et_packspec        = lt_packspec
      EXCEPTIONS
        determine_error    = 1
        read_error         = 2
        no_record_found    = 3
        OTHERS             = 4.

    IF sy-subrc <> 0 OR lt_packspec IS INITIAL.
      CLEAR ls_return.
      MESSAGE e026(zmsg_i2o_rf) INTO ls_return-message.
      ls_return-type   = 'E'.
      ls_return-id     = 'ZMSG_I2O_RF'.
      ls_return-number = '026'.
      APPEND ls_return TO ct_return.
      cv_severity = 'E'.
      RETURN.
    ENDIF.

    MOVE-CORRESPONDING <ls_item>-stock TO ls_pack.

    READ TABLE lt_packspec INTO ls_pack-guid_ps INDEX 1.

    ls_pack-quan = ls_cond-quantity.
    ls_pack-unit = ls_cond-unit_q.

    APPEND ls_pack TO lt_pack.

  ENDLOOP.

  IF lt_pack IS INITIAL.
    CLEAR ls_return.
    MESSAGE e030(zmsg_i2o_rf) INTO ls_return-message.
    ls_return-type   = 'E'.
    ls_return-id     = 'ZMSG_I2O_RF'.
    ls_return-number = '030'.
    APPEND ls_return TO ct_return.
    cv_severity = 'E'.
    RETURN.
  ENDIF.

  CALL FUNCTION '/SCWM/HU_PROPOSAL'
    EXPORTING
      it_pack     = lt_pack
      io_pack_ref = io_pack
    IMPORTING
      et_huhdr    = ct_huhdr
      et_huitm    = ct_huitm
      et_return   = lt_return
      ev_severity = cv_severity.

  IF ct_huhdr IS INITIAL.
    READ TABLE lt_return INTO ls_return
      WITH KEY id = '/SCWM/CONDTECH_BASIC'.
    IF sy-subrc = 0.
      MESSAGE e016(zmsg_i2o_rf) WITH
        |PackSpec found OK, but HU_PROPOSAL's packaging-material/HU-type|
     && | determination failed: { ls_return-message }|.
    ENDIF.
  ENDIF.

  APPEND LINES OF lt_return TO ct_return.

ENDFORM.

FORM frm_refresh_zapack_hu_from_db.

  DATA lt_valid_hu TYPE STANDARD TABLE OF ty_zapack_hu WITH EMPTY KEY.

  LOOP AT gt_zapack_hu INTO DATA(ls_zapack_hu).

    SELECT SINGLE huident
      FROM /scwm/huhdr
      WHERE huident = @ls_zapack_hu-huident
      INTO @DATA(lv_huident).

    IF sy-subrc = 0.
      APPEND ls_zapack_hu TO lt_valid_hu.
    ENDIF.

  ENDLOOP.

  gt_zapack_hu    = lt_valid_hu.
  gv_zapack_lines = lines( gt_zapack_hu ).

  IF gv_zapack_idx > gv_zapack_lines.
    gv_zapack_idx = gv_zapack_lines.
  ENDIF.

  IF gv_zapack_idx IS INITIAL.
    gv_zapack_idx = 1.
  ENDIF.

ENDFORM.

FORM frm_get_zapack_hist_id
  USING    iv_docid  TYPE /scwm/de_docid
           iv_itemid TYPE /scdl/dl_itemid
           iv_batch  TYPE /scwm/de_rf_charg
  CHANGING cv_id     TYPE indx_srtfd.

  cv_id = |ZAPACK_{ sy-uname }_{ iv_docid }_{ iv_itemid }_{ iv_batch }|.

ENDFORM.

MODULE status_9016 OUTPUT.

  DATA lv_hist_id TYPE indx_srtfd.

  CLEAR gt_zapack_hu.

  PERFORM frm_get_zapack_hist_id
    USING gv_docid gv_itemid gv_batch
    CHANGING lv_hist_id.

  IF gv_docid IS NOT INITIAL
 AND gv_itemid IS NOT INITIAL.

    IMPORT gt_zapack_hu = gt_zapack_hu
      FROM DATABASE indx(zz)
      ID lv_hist_id.

  ENDIF.

  PERFORM frm_refresh_zapack_hu_from_db.

  gv_zapack_lines = lines( gt_zapack_hu ).

  IF gv_zapack_idx IS INITIAL.
    gv_zapack_idx = 1.
  ENDIF.

ENDMODULE.

MODULE fill_9016_loop OUTPUT.

  DATA lv_index TYPE i.

  CLEAR: gs_rf_rehu_hu,
         gs_zapack_hu.

  lv_index = gv_zapack_idx + sy-stepl - 1.

  READ TABLE gt_zapack_hu INTO gs_zapack_hu INDEX lv_index.
  IF sy-subrc = 0.
    gs_rf_rehu_hu-huident = gs_zapack_hu-huident.
  ENDIF.

ENDMODULE.

MODULE input_9016_loop INPUT.
  "No input handling needed for display-only rows
ENDMODULE.

MODULE user_command_9016 INPUT.

  DATA lv_hist_id TYPE indx_srtfd.

  CASE sy-ucomm.

    WHEN 'PGUP'.
      IF gv_zapack_idx > 1.
        gv_zapack_idx = gv_zapack_idx - 1.
      ENDIF.

    WHEN 'PGDN'.
      IF gv_zapack_idx < gv_zapack_lines.
        gv_zapack_idx = gv_zapack_idx + 1.
      ENDIF.

    WHEN 'ENTER' OR 'ENTR' OR 'OK'.

      PERFORM frm_get_zapack_hist_id
        USING gv_docid gv_itemid gv_batch
        CHANGING lv_hist_id.

      DELETE FROM DATABASE indx(zz) ID lv_hist_id.
      FREE MEMORY ID lv_hist_id.

      CLEAR: gt_zapack_hu,
             gt_zap_huhdr,
             gt_zap_huitm,
             gs_zapack_hu,
             gs_rf_rehu_hu,
             gv_zapack_idx,
             gv_zapack_lines.

      gv_zapack_idx = 1.

  ENDCASE.

  CLEAR sy-ucomm.

ENDMODULE.

