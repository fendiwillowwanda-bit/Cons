*&---------------------------------------------------------------------*
*& Include          LZFG_I2O_RF_MFG_RCVF01
*&---------------------------------------------------------------------*
FORM frm_build_autopack_items_mrhu
  USING    iv_lgnum   TYPE /scwm/lgnum
           iv_docid   TYPE /scwm/de_docid
           iv_itemid  TYPE /scdl/dl_itemid
           iv_doccat  TYPE /scwm/de_doccat
           iv_prod    TYPE /scdl/dl_productno
           iv_qty     TYPE /scdl/dl_quantity
           iv_uom     TYPE /scwm/de_unit
           iv_guid_ps TYPE /scwm/de_guid_ps
           iv_hutyp   TYPE /scwm/de_rf_hu_typ
           iv_gmbin   TYPE /scwm/lgpla
  CHANGING ct_items   TYPE /scwm/tt_ps_autopack.

  CONSTANTS:
    lc_pak_procty TYPE c LENGTH 4 VALUE 'ZM01'.

  DATA:
    ls_auto_item     TYPE /scwm/s_ps_autopack,
    ls_proci         TYPE /scdl/db_proci_i,
    lv_matid         TYPE /scwm/de_matid,
    lv_batchid       TYPE /scwm/de_batchid,
    lv_entitled      TYPE /scwm/de_entitled,
    lv_owner         TYPE /scwm/de_owner,
    lv_prod_int      TYPE /scdl/dl_productno,
    lv_matnr         TYPE matnr,
    lv_batch         TYPE /scdl/dl_batchno,
    lv_itemid        TYPE /scdl/dl_itemid,
    lv_qty           TYPE /scdl/dl_quantity,
    lv_uom           TYPE /scwm/de_unit,
    lv_cat           TYPE /lime/stock_category,
    lv_owner_role    TYPE /lime/owner_role,
    lv_entitled_role TYPE /scwm/de_entitled_role,
    lv_pak_plant     TYPE c LENGTH 4,
    lv_pak_locid     TYPE /sapapo/locid,
    lv_vfdat         TYPE /scwm/sled,
    lv_gmbin         TYPE /scwm/dl_gmbin,
    lv_message       TYPE string.

  FIELD-SYMBOLS:
    <lv_any> TYPE any.

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

  CLEAR ct_items.

*--------------------------------------------------------------------*
* Normalize product
*--------------------------------------------------------------------*
  lv_prod_int = iv_prod.

  CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
    EXPORTING
      input        = lv_prod_int
    IMPORTING
      output       = lv_prod_int
    EXCEPTIONS
      length_error = 1
      OTHERS       = 2.

  IF sy-subrc <> 0.
    MESSAGE e035(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  lv_matnr = lv_prod_int.

*--------------------------------------------------------------------*
* Get real PDI item from DB
*--------------------------------------------------------------------*
  CLEAR ls_proci.

  IF iv_itemid IS NOT INITIAL.
    SELECT SINGLE *
      FROM /scdl/db_proci_i
      WHERE docid  = @iv_docid
        AND itemid = @iv_itemid
      INTO @ls_proci.
  ENDIF.

  IF ls_proci IS INITIAL.
    SELECT SINGLE * ##WARN_OK
      FROM /scdl/db_proci_i
      WHERE docid     = @iv_docid
        AND productno = @lv_prod_int
      INTO @ls_proci.
  ENDIF.

  IF ls_proci IS INITIAL.
    SELECT SINGLE * ##WARN_OK
      FROM /scdl/db_proci_i
      WHERE docid = @iv_docid
      INTO @ls_proci.
  ENDIF.

  IF ls_proci IS INITIAL.
    MESSAGE e030(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* Use PDI values as source
*--------------------------------------------------------------------*
  lv_itemid   = ls_proci-itemid.
  lv_prod_int = ls_proci-productno.
  lv_matid    = ls_proci-productid.
  lv_batch    = ls_proci-batchno.
  lv_entitled = ls_proci-entitled.
  lv_qty      = ls_proci-qty.
  lv_uom      = ls_proci-uom.

  IF lv_qty IS INITIAL.
    lv_qty = iv_qty.
  ENDIF.

  IF lv_uom IS INITIAL.
    lv_uom = iv_uom.
  ENDIF.

  IF lv_uom IS INITIAL.
    MESSAGE e033(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  IF lv_matid IS INITIAL.
    MESSAGE e034(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* Goods Movement Bin only
*--------------------------------------------------------------------*
  CLEAR lv_gmbin.

  get_comp '/SCWM/GMBIN' lv_gmbin ls_proci.

  IF lv_gmbin IS INITIAL.
    get_comp 'GMBIN' lv_gmbin ls_proci.
  ENDIF.

  IF lv_gmbin IS INITIAL.
    lv_gmbin = iv_gmbin.
  ENDIF.

*--------------------------------------------------------------------*
* Owner / entitled / roles
*--------------------------------------------------------------------*
  get_comp 'OWNER' lv_owner ls_proci.

  IF lv_owner IS INITIAL.
    lv_owner = lv_entitled.
  ENDIF.

  get_comp 'OWNER_ROLE'    lv_owner_role    ls_proci.
  get_comp 'ENTITLED_ROLE' lv_entitled_role ls_proci.

  IF lv_owner_role IS INITIAL.
    get_comp 'OWNERROLE' lv_owner_role ls_proci.
  ENDIF.

  IF lv_entitled_role IS INITIAL.
    get_comp 'ENTITLEDROLE' lv_entitled_role ls_proci.
  ENDIF.

  IF lv_owner_role IS INITIAL.
    lv_owner_role = lv_entitled_role.
  ENDIF.

  IF lv_entitled_role IS INITIAL.
    lv_entitled_role = lv_owner_role.
  ENDIF.

*--------------------------------------------------------------------*
* Stock category
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

  IF lv_cat = 'P'.
    lv_cat = 'P2'.
  ENDIF.

*--------------------------------------------------------------------*
* Dynamic PAK_PLANT
*--------------------------------------------------------------------*
  get_comp 'PAK_PLANT' lv_pak_plant ls_proci.

  IF lv_pak_plant IS INITIAL AND lv_entitled CP 'PLANT*'.
    lv_pak_plant = lv_entitled+5(4).
  ENDIF.

  IF lv_pak_plant IS INITIAL AND lv_owner CP 'PLANT*'.
    lv_pak_plant = lv_owner+5(4).
  ENDIF.

*--------------------------------------------------------------------*
* Dynamic PAK_LOCID
*--------------------------------------------------------------------*
  CLEAR lv_pak_locid.

  get_comp 'PAK_LOCID' lv_pak_locid ls_proci.

  IF lv_pak_locid IS INITIAL.
    get_comp 'LOCID' lv_pak_locid ls_proci.
  ENDIF.

  IF lv_pak_locid IS INITIAL.
    get_comp 'LOCATIONID' lv_pak_locid ls_proci.
  ENDIF.

  IF lv_pak_locid IS INITIAL
  AND lv_entitled IS NOT INITIAL.
    SELECT SINGLE locid
      FROM /sapapo/loc
      WHERE locno = @lv_entitled
      INTO @lv_pak_locid.
  ENDIF.

  IF lv_pak_locid IS INITIAL
  AND lv_owner IS NOT INITIAL.
    SELECT SINGLE locid
      FROM /sapapo/loc
      WHERE locno = @lv_owner
      INTO @lv_pak_locid.
  ENDIF.

  IF lv_pak_locid IS INITIAL
  AND lv_pak_plant IS NOT INITIAL.

    DATA(lv_locno_plant) = |PLANT{ lv_pak_plant }|.

    SELECT SINGLE locid
      FROM /sapapo/loc
      WHERE locno = @lv_locno_plant
      INTO @lv_pak_locid.
  ENDIF.

*--------------------------------------------------------------------*
* VFDAT / SLED
*--------------------------------------------------------------------*
  CLEAR lv_vfdat.

  get_comp 'VFDAT' lv_vfdat ls_proci.

  IF lv_vfdat IS INITIAL.
    get_comp 'SLED' lv_vfdat ls_proci.
  ENDIF.

  IF lv_vfdat IS INITIAL.
    get_comp 'EXPIRY_DATE' lv_vfdat ls_proci.
  ENDIF.

  IF lv_vfdat IS INITIAL
  AND lv_matnr IS NOT INITIAL
  AND lv_batch IS NOT INITIAL
  AND lv_pak_plant IS NOT INITIAL.
    SELECT SINGLE vfdat
      FROM mcha
      WHERE matnr = @lv_matnr
        AND werks = @lv_pak_plant
        AND charg = @lv_batch
      INTO @lv_vfdat.
  ENDIF.

  IF lv_vfdat IS INITIAL
  AND lv_matnr IS NOT INITIAL
  AND lv_batch IS NOT INITIAL.
    SELECT SINGLE vfdat
      FROM mch1
      WHERE matnr = @lv_matnr
        AND charg = @lv_batch
      INTO @lv_vfdat.
  ENDIF.

*--------------------------------------------------------------------*
* BATCHID
*--------------------------------------------------------------------*
  CLEAR lv_batchid.

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
* Build AutoPack item
*--------------------------------------------------------------------*
  CLEAR ls_auto_item.

  ls_auto_item-stock-qdocid  = iv_docid.
  ls_auto_item-stock-qdoccat = iv_doccat.
  ls_auto_item-stock-qitmid  = lv_itemid.

  set_comp 'LGNUM'         ls_auto_item-stock iv_lgnum.
  set_comp 'DOCCAT'        ls_auto_item-stock iv_doccat.
  set_comp 'QDOCCAT'       ls_auto_item-stock iv_doccat.
  set_comp 'QDOCID'        ls_auto_item-stock iv_docid.
  set_comp 'QITMID'        ls_auto_item-stock lv_itemid.
  set_comp 'ODDOCCAT'      ls_auto_item-stock iv_doccat.
  set_comp 'ODOCID'        ls_auto_item-stock iv_docid.
  set_comp 'OITMID'        ls_auto_item-stock lv_itemid.
  set_comp 'MATID'         ls_auto_item-stock lv_matid.
  set_comp 'PRODUCTID'     ls_auto_item-stock lv_matid.
  set_comp 'PRODUCTNO'     ls_auto_item-stock lv_prod_int.
  set_comp 'PRODUCTNO_EXT' ls_auto_item-stock lv_prod_int.
  set_comp 'PRODUCT'       ls_auto_item-stock lv_prod_int.
  set_comp 'MATNR'         ls_auto_item-stock lv_prod_int.
  set_comp 'BATCHNO'       ls_auto_item-stock lv_batch.

  IF lv_batchid IS NOT INITIAL.
    set_comp 'BATCHID' ls_auto_item-stock lv_batchid.
  ENDIF.

  IF lv_cat IS NOT INITIAL.
    set_comp 'CAT' ls_auto_item-stock lv_cat.
  ENDIF.

  IF lv_owner IS NOT INITIAL.
    set_comp 'OWNER' ls_auto_item-stock lv_owner.
  ENDIF.

  IF lv_owner_role IS NOT INITIAL.
    set_comp 'OWNER_ROLE' ls_auto_item-stock lv_owner_role.
  ENDIF.

  IF lv_entitled IS NOT INITIAL.
    set_comp 'ENTITLED' ls_auto_item-stock lv_entitled.
  ENDIF.

  IF lv_entitled_role IS NOT INITIAL.
    set_comp 'ENTITLED_ROLE' ls_auto_item-stock lv_entitled_role.
  ENDIF.

  IF lv_vfdat IS NOT INITIAL.
    set_comp 'VFDAT' ls_auto_item-stock lv_vfdat.
  ENDIF.

  IF lv_gmbin IS NOT INITIAL.
    set_comp 'GMBIN'       ls_auto_item-stock lv_gmbin.
    set_comp '/SCWM/GMBIN' ls_auto_item-stock lv_gmbin.
  ENDIF.

  set_comp 'QTY'      ls_auto_item-stock lv_qty.
  set_comp 'QUAN'     ls_auto_item-stock lv_qty.
  set_comp 'QUANTITY' ls_auto_item-stock lv_qty.
  set_comp 'UOM'      ls_auto_item-stock lv_uom.
  set_comp 'UNIT'     ls_auto_item-stock lv_uom.
  set_comp 'UNIT_Q'   ls_auto_item-stock lv_uom.
  set_comp 'MEINS'    ls_auto_item-stock lv_uom.
  set_comp 'ALTME'    ls_auto_item-stock lv_uom.
  set_comp 'GUID_PS'  ls_auto_item-stock iv_guid_ps.

  CLEAR ls_auto_item-cond.

  ls_auto_item-cond-quantity = lv_qty.
  ls_auto_item-cond-unit_q   = lv_uom.

  set_comp 'LGNUM'         ls_auto_item-det iv_lgnum.
  set_comp 'DOCCAT'        ls_auto_item-det iv_doccat.
  set_comp 'QDOCCAT'       ls_auto_item-det iv_doccat.
  set_comp 'QDOCID'        ls_auto_item-det iv_docid.
  set_comp 'QITMID'        ls_auto_item-det lv_itemid.
  set_comp 'ODDOCCAT'      ls_auto_item-det iv_doccat.
  set_comp 'ODOCID'        ls_auto_item-det iv_docid.
  set_comp 'OITMID'        ls_auto_item-det lv_itemid.
  set_comp 'MATID'         ls_auto_item-det lv_matid.
  set_comp 'PRODUCTID'     ls_auto_item-det lv_matid.
  set_comp 'PAK_MATID'     ls_auto_item-det lv_matid.
  set_comp 'PAK_REFMATID'  ls_auto_item-det lv_matid.

  IF lv_pak_locid IS NOT INITIAL.
    set_comp 'PAK_LOCID' ls_auto_item-det lv_pak_locid.
  ENDIF.

  IF lv_pak_plant IS NOT INITIAL.
    set_comp 'PAK_PLANT' ls_auto_item-det lv_pak_plant.
  ENDIF.

  set_comp 'PAK_PROCTY' ls_auto_item-det lc_pak_procty.

  IF iv_hutyp IS NOT INITIAL.
    set_comp 'PAK_HUTYP_DFLT' ls_auto_item-det iv_hutyp.
    set_comp 'PAK_HUTYP'      ls_auto_item-det iv_hutyp.
    set_comp 'HUTYP_DFLT'     ls_auto_item-det iv_hutyp.
    set_comp 'HUTYP'          ls_auto_item-det iv_hutyp.
  ENDIF.

  set_comp 'PRODUCTNO'     ls_auto_item-det lv_prod_int.
  set_comp 'PRODUCTNO_EXT' ls_auto_item-det lv_prod_int.
  set_comp 'PRODUCT'       ls_auto_item-det lv_prod_int.
  set_comp 'MATNR'         ls_auto_item-det lv_prod_int.
  set_comp 'BATCHNO'       ls_auto_item-det lv_batch.

  IF lv_batchid IS NOT INITIAL.
    set_comp 'BATCHID' ls_auto_item-det lv_batchid.
  ENDIF.

  IF lv_cat IS NOT INITIAL.
    set_comp 'CAT' ls_auto_item-det lv_cat.
  ENDIF.

  IF lv_owner IS NOT INITIAL.
    set_comp 'OWNER' ls_auto_item-det lv_owner.
  ENDIF.

  IF lv_owner_role IS NOT INITIAL.
    set_comp 'OWNER_ROLE' ls_auto_item-det lv_owner_role.
  ENDIF.

  IF lv_entitled IS NOT INITIAL.
    set_comp 'ENTITLED' ls_auto_item-det lv_entitled.
  ENDIF.

  IF lv_entitled_role IS NOT INITIAL.
    set_comp 'ENTITLED_ROLE' ls_auto_item-det lv_entitled_role.
  ENDIF.

  IF lv_vfdat IS NOT INITIAL.
    set_comp 'VFDAT' ls_auto_item-det lv_vfdat.
  ENDIF.

  IF lv_gmbin IS NOT INITIAL.
    set_comp 'GMBIN'       ls_auto_item-det lv_gmbin.
    set_comp '/SCWM/GMBIN' ls_auto_item-det lv_gmbin.
  ENDIF.

  set_comp 'QUANTITY' ls_auto_item-det lv_qty.
  set_comp 'QTY'      ls_auto_item-det lv_qty.
  set_comp 'QUAN'     ls_auto_item-det lv_qty.
  set_comp 'UNIT_Q'   ls_auto_item-det lv_uom.
  set_comp 'UNIT'     ls_auto_item-det lv_uom.
  set_comp 'UOM'      ls_auto_item-det lv_uom.
  set_comp 'MEINS'    ls_auto_item-det lv_uom.
  set_comp 'ALTME'    ls_auto_item-det lv_uom.
  set_comp 'GUID_PS'  ls_auto_item-det iv_guid_ps.

  APPEND ls_auto_item TO ct_items.

ENDFORM.


FORM frm_pmat_from_packspec_mrhu
  USING    iv_matid    TYPE /scwm/de_matid
           iv_plant    TYPE c
           iv_qty      TYPE /scwm/de_rf_qty
           iv_uom      TYPE /scwm/de_unit
  CHANGING cv_pmat     TYPE /scwm/de_rf_pmat
           cv_guid_ps  TYPE /scwm/de_guid_ps.

  DATA:
    ls_det_fields TYPE /scwm/pak_com_i,
    ls_cond       TYPE /scwm/s_ps_cond,
    ls_dlv_item   TYPE /scwm/dlv_docid_item_str,
    lt_packspec   TYPE /scwm/tt_guid_ps,
    lv_guid_ps    TYPE /scwm/de_guid_ps,
    lt_egroup     TYPE /scwm/tt_ps_elementgroup,
    lv_valid_on   TYPE timestamp,
    lv_message    TYPE string.

  FIELD-SYMBOLS:
    <lv_any>     TYPE any,
    <lt_anytab>  TYPE ANY TABLE,
    <ls_anyline> TYPE any.

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

  CLEAR:
    cv_pmat,
    cv_guid_ps.

  IF iv_matid IS INITIAL OR iv_plant IS INITIAL.
    RETURN.
  ENDIF.

  set_comp 'PAK_MATID'    ls_det_fields iv_matid.
  set_comp 'PAK_REFMATID' ls_det_fields iv_matid.
  set_comp 'PAK_PLANT'    ls_det_fields iv_plant.
  set_comp 'PAK_PROCTY'   ls_det_fields 'ZM01'.

  ls_cond-quantity = iv_qty.
  ls_cond-unit_q   = iv_uom.

  GET TIME STAMP FIELD lv_valid_on.

  CALL FUNCTION '/SCWM/PS_FIND_AND_EVALUATE'
    EXPORTING
      is_fields       = ls_det_fields
      iv_procedure    = '0IBD'
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

  READ TABLE lt_packspec INTO lv_guid_ps INDEX 1.
  IF sy-subrc <> 0 OR lv_guid_ps IS INITIAL.
    RETURN.
  ENDIF.

  cv_guid_ps = lv_guid_ps.

  CALL FUNCTION '/SCWM/PS_PACKSPEC_GET'
    EXPORTING
      iv_guid_ps       = lv_guid_ps
      iv_read_elements = abap_true
      iv_no_buffer     = abap_true
      iv_loguom        = iv_uom
    IMPORTING
      et_elementgroup  = lt_egroup
    EXCEPTIONS
      error            = 1
      OTHERS           = 2.

  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  LOOP AT lt_egroup ASSIGNING FIELD-SYMBOL(<ls_egroup>).

    ASSIGN COMPONENT 'ELEMENTS' OF STRUCTURE <ls_egroup> TO <lv_any>.
    IF sy-subrc <> 0 OR <lv_any> IS NOT ASSIGNED.
      CONTINUE.
    ENDIF.

    ASSIGN <lv_any> TO <lt_anytab>.

    IF <lt_anytab> IS NOT ASSIGNED.
      UNASSIGN <lv_any>.
      CONTINUE.
    ENDIF.

    LOOP AT <lt_anytab> ASSIGNING <ls_anyline>.

      get_comp 'MATNR' cv_pmat <ls_anyline>.

      IF cv_pmat IS INITIAL.
        get_comp 'PRODUCTNO' cv_pmat <ls_anyline>.
      ENDIF.

      IF cv_pmat IS INITIAL.
        get_comp 'PAK_MATNR' cv_pmat <ls_anyline>.
      ENDIF.

      IF cv_pmat IS INITIAL.
        get_comp 'PMAT' cv_pmat <ls_anyline>.
      ENDIF.

      IF cv_pmat IS NOT INITIAL.
        CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
          EXPORTING
            input        = cv_pmat
          IMPORTING
            output       = cv_pmat
          EXCEPTIONS
            length_error = 1
            OTHERS       = 2.

        IF sy-subrc <> 0.
          MESSAGE e036(zmsg_i2o_rf) INTO lv_message.
          MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.

          CLEAR cv_pmat.
          EXIT.
        ENDIF.
      ENDIF.

    ENDLOOP.

    UNASSIGN <lv_any>.

    IF cv_pmat IS NOT INITIAL.
      EXIT.
    ENDIF.

  ENDLOOP.

ENDFORM.


FORM frm_get_egr_item_for_mrhu
  USING    iv_lgnum      TYPE /scwm/lgnum ##NEEDED
           iv_manuford   TYPE /scwm/de_rf_prod_order
           iv_prod       TYPE /scdl/dl_productno
  CHANGING cv_egr_docid  TYPE /scdl/dl_docid
           cv_egr_itemid TYPE /scdl/dl_itemid.

  CONSTANTS:
    lc_tab_refdoc TYPE tabname VALUE '/SCDL/DB_REFDOC'.

  DATA:
    lv_manuford_raw TYPE /scwm/de_rf_prod_order,
    lv_manuford_in  TYPE aufnr,
    lv_manuford_out TYPE aufnr,
    lv_prod_int     TYPE /scdl/dl_productno,
    lv_where        TYPE string,
    lv_ord_field    TYPE fieldname,
    lv_docid        TYPE /scdl/dl_docid,
    lv_itemid       TYPE /scdl/dl_itemid,
    lt_dfies        TYPE STANDARD TABLE OF dfies,
    lt_candidates   TYPE STANDARD TABLE OF fieldname WITH EMPTY KEY,
    ls_proci        TYPE /scdl/db_proci_i,
    lv_message      TYPE string.

  DATA:
    lr_refdoc_tab TYPE REF TO data.

  FIELD-SYMBOLS:
    <lt_refdoc> TYPE STANDARD TABLE,
    <ls_refdoc> TYPE any,
    <lv_any>    TYPE any.

  CLEAR:
    cv_egr_docid,
    cv_egr_itemid.

*--------------------------------------------------------------------*
* Normalize process order and product
*--------------------------------------------------------------------*
  lv_manuford_raw = iv_manuford.
  CONDENSE lv_manuford_raw NO-GAPS.

  lv_manuford_in = lv_manuford_raw.

  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = lv_manuford_in
    IMPORTING
      output = lv_manuford_in.

  lv_manuford_out = lv_manuford_in.

  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
    EXPORTING
      input  = lv_manuford_in
    IMPORTING
      output = lv_manuford_out.

  lv_prod_int = iv_prod.

  CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
    EXPORTING
      input        = lv_prod_int
    IMPORTING
      output       = lv_prod_int
    EXCEPTIONS
      length_error = 1
      OTHERS       = 2.

  IF sy-subrc <> 0.
    MESSAGE e037(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* Read DDIC fields of /SCDL/DB_REFDOC
*--------------------------------------------------------------------*
  CALL FUNCTION 'DDIF_FIELDINFO_GET'
    EXPORTING
      tabname        = lc_tab_refdoc
      langu          = sy-langu
    TABLES
      dfies_tab      = lt_dfies
    EXCEPTIONS
      not_found      = 1
      internal_error = 2
      OTHERS         = 3.

  IF sy-subrc <> 0 OR lt_dfies IS INITIAL.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* Find reference document number field dynamically
*--------------------------------------------------------------------*
  APPEND 'REFDOCNO'   TO lt_candidates.
  APPEND 'REF_DOC_NO' TO lt_candidates.
  APPEND 'REFDOC_NO'  TO lt_candidates.
  APPEND 'REFNO'      TO lt_candidates.
  APPEND 'DOCNO_REF'  TO lt_candidates.
  APPEND 'ERP_DOCNO'  TO lt_candidates.
  APPEND 'SNDOC'      TO lt_candidates.
  APPEND 'MANUFORD'   TO lt_candidates.
  APPEND 'PROD_ORDER' TO lt_candidates.
  APPEND 'AUFNR'      TO lt_candidates.

  LOOP AT lt_candidates INTO DATA(lv_candidate).
    READ TABLE lt_dfies TRANSPORTING NO FIELDS
      WITH KEY fieldname = lv_candidate.

    IF sy-subrc = 0.
      lv_ord_field = lv_candidate.
      EXIT.
    ENDIF.
  ENDLOOP.

  IF lv_ord_field IS INITIAL.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* Build dynamic WHERE for process order variants
*--------------------------------------------------------------------*
  lv_where =
    |{ lv_ord_field } = '{ lv_manuford_raw }'| &&
    | OR { lv_ord_field } = '{ lv_manuford_in }'| &&
    | OR { lv_ord_field } = '{ lv_manuford_out }'|.

*--------------------------------------------------------------------*
* Read reference document rows dynamically
*--------------------------------------------------------------------*
  TRY.
      CREATE DATA lr_refdoc_tab TYPE STANDARD TABLE OF (lc_tab_refdoc).
      ASSIGN lr_refdoc_tab->* TO <lt_refdoc>.

      SELECT *
        FROM (lc_tab_refdoc)
        WHERE (lv_where)
        INTO TABLE @<lt_refdoc>
        UP TO 500 ROWS.

    CATCH cx_root.
      RETURN.
  ENDTRY.

  IF <lt_refdoc> IS INITIAL.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* For each reference hit, validate actual EGR item in /SCDL/DB_PROCI_I
*--------------------------------------------------------------------*
  LOOP AT <lt_refdoc> ASSIGNING <ls_refdoc>.

    CLEAR:
      lv_docid,
      lv_itemid,
      ls_proci.

    ASSIGN COMPONENT 'DOCID' OF STRUCTURE <ls_refdoc> TO <lv_any>.
    IF sy-subrc = 0 AND <lv_any> IS ASSIGNED.
      lv_docid = <lv_any>.
      UNASSIGN <lv_any>.
    ENDIF.

    ASSIGN COMPONENT 'ITEMID' OF STRUCTURE <ls_refdoc> TO <lv_any>.
    IF sy-subrc = 0 AND <lv_any> IS ASSIGNED.
      lv_itemid = <lv_any>.
      UNASSIGN <lv_any>.
    ENDIF.

    IF lv_docid IS INITIAL.
      CONTINUE.
    ENDIF.

    IF lv_itemid IS NOT INITIAL.
      SELECT SINGLE *
        FROM /scdl/db_proci_i
        WHERE docid     = @lv_docid
          AND itemid    = @lv_itemid
          AND doccat    = @/scdl/if_dl_c=>sc_doccat_egr_prd
          AND productno = @lv_prod_int
        INTO @ls_proci.
    ENDIF.

    IF ls_proci IS INITIAL.
      SELECT SINGLE * ##WARN_OK
        FROM /scdl/db_proci_i
        WHERE docid     = @lv_docid
          AND doccat    = @/scdl/if_dl_c=>sc_doccat_egr_prd
          AND productno = @lv_prod_int
        INTO @ls_proci.
    ENDIF.

    IF ls_proci IS INITIAL.
      CONTINUE.
    ENDIF.

    cv_egr_docid  = ls_proci-docid.
    cv_egr_itemid = ls_proci-itemid.
    RETURN.

  ENDLOOP.

ENDFORM.


FORM frm_normalize_uom
  USING    iv_uom     TYPE /scwm/de_unit
  CHANGING cv_uom_int TYPE /scwm/de_unit.

  CLEAR cv_uom_int.

  cv_uom_int = iv_uom.

  CALL FUNCTION 'CONVERSION_EXIT_CUNIT_INPUT'
    EXPORTING
      input          = iv_uom
      language       = sy-langu
    IMPORTING
      output         = cv_uom_int
    EXCEPTIONS
      unit_not_found = 1
      OTHERS         = 2.

  IF sy-subrc <> 0 OR cv_uom_int IS INITIAL.
    cv_uom_int = iv_uom.
  ENDIF.

ENDFORM.

FORM frm_get_zapack_hus_from_dlv
  USING    iv_lgnum  TYPE /scwm/lgnum
           iv_docid  TYPE /scwm/de_docid
           iv_itemid TYPE /scdl/dl_itemid
           iv_doccat TYPE /scwm/de_doccat
  CHANGING ct_huhdr  TYPE /scwm/tt_huhdr_int
           ct_huitm  TYPE /scwm/tt_huitm_int.

  DATA:
    lt_parmbind TYPE abap_func_parmbind_tab,
    ls_parmbind TYPE abap_func_parmbind,
    lt_excpbind TYPE abap_func_excpbind_tab,
    ls_excpbind TYPE abap_func_excpbind,
    ls_dlv_item TYPE /scwm/dlv_docid_item_str.

  CLEAR:
    ct_huhdr,
    ct_huitm,
    lt_parmbind,
    lt_excpbind,
    ls_dlv_item.

  ls_dlv_item-doccat = iv_doccat.
  ls_dlv_item-docid  = iv_docid.
  ls_dlv_item-itemid = iv_itemid.

  TRY.
      CLEAR ls_parmbind.
      ls_parmbind-name = 'IV_LGNUM'.
      ls_parmbind-kind = abap_func_exporting.
      GET REFERENCE OF iv_lgnum INTO ls_parmbind-value.
      INSERT ls_parmbind INTO TABLE lt_parmbind.

      CLEAR ls_parmbind.
      ls_parmbind-name = 'IS_DLV_ITEM'.
      ls_parmbind-kind = abap_func_exporting.
      GET REFERENCE OF ls_dlv_item INTO ls_parmbind-value.
      INSERT ls_parmbind INTO TABLE lt_parmbind.

      CLEAR ls_parmbind.
      ls_parmbind-name = 'ET_HUHDR'.
      ls_parmbind-kind = abap_func_importing.
      GET REFERENCE OF ct_huhdr INTO ls_parmbind-value.
      INSERT ls_parmbind INTO TABLE lt_parmbind.

      CLEAR ls_parmbind.
      ls_parmbind-name = 'ET_HUITM'.
      ls_parmbind-kind = abap_func_importing.
      GET REFERENCE OF ct_huitm INTO ls_parmbind-value.
      INSERT ls_parmbind INTO TABLE lt_parmbind.

      CLEAR ls_excpbind.
      ls_excpbind-name  = 'OTHERS'.
      ls_excpbind-value = 1.
      INSERT ls_excpbind INTO TABLE lt_excpbind.

      CALL FUNCTION '/SCWM/DLV_GET_HUS_FOR_DLV_ITEM'
        PARAMETER-TABLE lt_parmbind
        EXCEPTION-TABLE lt_excpbind.

    CATCH cx_root.
      CLEAR:
        ct_huhdr,
        ct_huitm.
  ENDTRY.

ENDFORM.

FORM frm_prepare_zapack_hu
  USING iv_uom TYPE /scwm/de_unit.

  DATA:
    ls_huhdr       TYPE /scwm/s_huhdr_int,
    ls_huitm       TYPE /scwm/s_huitm_int,
    lv_guid_hu     TYPE /scwm/guid_hu,
    lv_guid_parent TYPE /scwm/guid_hu.

  FIELD-SYMBOLS:
    <lv_any> TYPE any.

  DEFINE get_comp.
    CLEAR &2.
    ASSIGN COMPONENT &1 OF STRUCTURE &3 TO <lv_any>.
    IF sy-subrc = 0 AND <lv_any> IS ASSIGNED.
      &2 = <lv_any>.
      UNASSIGN <lv_any>.
    ENDIF.
  END-OF-DEFINITION.

  CLEAR:
    gt_zapack_hu,
    gv_zapack_lines,
    gs_zapack_hu.

  LOOP AT gt_zap_huhdr INTO ls_huhdr.

    CLEAR:
      gs_zapack_hu,
      lv_guid_hu.

    get_comp 'HUIDENT'     gs_zapack_hu-huident ls_huhdr.
    get_comp 'HU_ID'       gs_zapack_hu-huident ls_huhdr.
    get_comp 'EXIDV'       gs_zapack_hu-huident ls_huhdr.
    get_comp 'EXID'        gs_zapack_hu-huident ls_huhdr.
    get_comp 'HUIDENT_EXT' gs_zapack_hu-huident ls_huhdr.

    get_comp 'GUID_HU' lv_guid_hu ls_huhdr.

    IF gs_zapack_hu-huident IS INITIAL
    AND lv_guid_hu IS NOT INITIAL.

      SELECT SINGLE huident
        FROM /scwm/huhdr
        WHERE guid_hu = @lv_guid_hu
        INTO @gs_zapack_hu-huident.

    ENDIF.

    IF gs_zapack_hu-huident IS INITIAL.
      CONTINUE.
    ENDIF.

    LOOP AT gt_zap_huitm INTO ls_huitm.

      CLEAR lv_guid_parent.

      get_comp 'GUID_PARENT' lv_guid_parent ls_huitm.

      IF lv_guid_parent IS INITIAL.
        get_comp 'GUID_HU' lv_guid_parent ls_huitm.
      ENDIF.

      IF lv_guid_hu IS NOT INITIAL
      AND lv_guid_parent IS NOT INITIAL
      AND lv_guid_parent <> lv_guid_hu.
        CONTINUE.
      ENDIF.

      get_comp 'QUAN'     gs_zapack_hu-qty ls_huitm.
      get_comp 'QTY'      gs_zapack_hu-qty ls_huitm.
      get_comp 'QUANTITY' gs_zapack_hu-qty ls_huitm.

      get_comp 'MEINS'  gs_zapack_hu-uom ls_huitm.
      get_comp 'ALTME'  gs_zapack_hu-uom ls_huitm.
      get_comp 'UOM'    gs_zapack_hu-uom ls_huitm.
      get_comp 'UNIT'   gs_zapack_hu-uom ls_huitm.
      get_comp 'UNIT_Q' gs_zapack_hu-uom ls_huitm.

      EXIT.

    ENDLOOP.

    IF gs_zapack_hu-qty IS INITIAL.
      gs_zapack_hu-qty = 1.
    ENDIF.

    IF gs_zapack_hu-uom IS INITIAL.
      gs_zapack_hu-uom = iv_uom.
    ENDIF.

    APPEND gs_zapack_hu TO gt_zapack_hu.

  ENDLOOP.

  SORT gt_zapack_hu BY huident.
  DELETE ADJACENT DUPLICATES FROM gt_zapack_hu COMPARING huident.

  gv_zapack_lines = lines( gt_zapack_hu ).

  IF gv_zapack_idx IS INITIAL.
    gv_zapack_idx = 1.
  ENDIF.

ENDFORM.


FORM frm_get_zapack_hist_id
  USING    iv_key TYPE any
  CHANGING cv_id  TYPE indx_srtfd.

  cv_id = |ZAPACK_{ sy-uname }_{ iv_key }|.

ENDFORM.

FORM frm_refresh_zapack_hu_from_db.

  DATA:
    lt_old_hu        TYPE STANDARD TABLE OF ty_zapack_hu WITH EMPTY KEY,
    lt_valid_hu      TYPE STANDARD TABLE OF ty_zapack_hu WITH EMPTY KEY,
    lt_huident_range TYPE RANGE OF /scwm/de_huident,
    lt_db_huident    TYPE SORTED TABLE OF /scwm/de_huident
                     WITH UNIQUE KEY table_line.

  CLEAR:
    lt_old_hu,
    lt_valid_hu,
    lt_huident_range,
    lt_db_huident.

  lt_old_hu = gt_zapack_hu.

  LOOP AT gt_zapack_hu INTO DATA(ls_zapack_hu).
    IF ls_zapack_hu-huident IS NOT INITIAL.
      APPEND VALUE #( sign   = 'I'
                      option = 'EQ'
                      low    = ls_zapack_hu-huident ) TO lt_huident_range.
    ENDIF.
  ENDLOOP.

  IF lt_huident_range IS INITIAL.
    RETURN.
  ENDIF.

  SELECT huident
    FROM /scwm/huhdr
    WHERE huident IN @lt_huident_range
    INTO TABLE @DATA(lt_huident_db).

  IF lt_huident_db IS INITIAL.
    gt_zapack_hu    = lt_old_hu.
    gv_zapack_lines = lines( gt_zapack_hu ).
    RETURN.
  ENDIF.

  lt_db_huident = CORRESPONDING #( lt_huident_db ).

  LOOP AT gt_zapack_hu INTO ls_zapack_hu.
    READ TABLE lt_db_huident TRANSPORTING NO FIELDS
      WITH TABLE KEY table_line = ls_zapack_hu-huident.

    IF sy-subrc = 0.
      APPEND ls_zapack_hu TO lt_valid_hu.
    ENDIF.
  ENDLOOP.

  IF lt_valid_hu IS NOT INITIAL.
    gt_zapack_hu = lt_valid_hu.
  ELSE.
    gt_zapack_hu = lt_old_hu.
  ENDIF.

  gv_zapack_lines = lines( gt_zapack_hu ).

  IF gv_zapack_idx IS INITIAL.
    gv_zapack_idx = 1.
  ENDIF.

ENDFORM.

MODULE status_9001 OUTPUT.

  DATA:
    lv_hist_id TYPE indx_srtfd,
    lv_lines   TYPE i.

  IF gt_zapack_hu IS INITIAL.

    IF gv_manuford IS NOT INITIAL.

      CLEAR lv_hist_id.

      PERFORM frm_get_zapack_hist_id
        USING    gv_manuford
        CHANGING lv_hist_id.

      IMPORT gt_zapack_hu = gt_zapack_hu
        FROM MEMORY ID lv_hist_id.

      IF gt_zapack_hu IS INITIAL.
        IMPORT gt_zapack_hu = gt_zapack_hu
          FROM DATABASE indx(zz)
          ID lv_hist_id.
      ENDIF.

    ENDIF.

    IF gt_zapack_hu IS INITIAL.

      CLEAR lv_hist_id.

      PERFORM frm_get_zapack_hist_id
        USING    sy-uname
        CHANGING lv_hist_id.

      IMPORT gt_zapack_hu = gt_zapack_hu
        FROM MEMORY ID lv_hist_id.

      IF gt_zapack_hu IS INITIAL.
        IMPORT gt_zapack_hu = gt_zapack_hu
          FROM DATABASE indx(zz)
          ID lv_hist_id.
      ENDIF.

    ENDIF.

  ENDIF.

  IF gt_zapack_hu IS NOT INITIAL.
    PERFORM frm_refresh_zapack_hu_from_db.
  ENDIF.

  lv_lines = lines( gt_zapack_hu ).
  gv_zapack_lines = lv_lines.

  IF gv_zapack_idx IS INITIAL.
    gv_zapack_idx = 1.
  ENDIF.

ENDMODULE.


MODULE fill_9001_loop OUTPUT.

  DATA lv_index TYPE i.

  FIELD-SYMBOLS:
    <lv_any> TYPE any.

  DEFINE set_comp.
    ASSIGN COMPONENT &1 OF STRUCTURE &2 TO <lv_any>.
    IF sy-subrc = 0 AND <lv_any> IS ASSIGNED.
      <lv_any> = &3.
      UNASSIGN <lv_any>.
    ENDIF.
  END-OF-DEFINITION.

  CLEAR:
    gs_zapack_hu,
    gs_rf_rehu_hu,
    gs_rf_mfg_hu.

  lv_index = gv_zapack_idx + sy-stepl - 1.

  READ TABLE gt_zapack_hu INTO gs_zapack_hu INDEX lv_index.
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  set_comp 'HUIDENT'  gs_rf_rehu_hu gs_zapack_hu-huident.
  set_comp 'HU'       gs_rf_rehu_hu gs_zapack_hu-huident.
  set_comp 'RFHU'     gs_rf_rehu_hu gs_zapack_hu-huident.
  set_comp 'RFLASTHU' gs_rf_rehu_hu gs_zapack_hu-huident.
  set_comp 'QTY'      gs_rf_rehu_hu gs_zapack_hu-qty.
  set_comp 'QUAN'     gs_rf_rehu_hu gs_zapack_hu-qty.
  set_comp 'UOM'      gs_rf_rehu_hu gs_zapack_hu-uom.
  set_comp 'ALTME'    gs_rf_rehu_hu gs_zapack_hu-uom.

  set_comp 'RFHU'     gs_rf_mfg_hu gs_zapack_hu-huident.
  set_comp 'RFLASTHU' gs_rf_mfg_hu gs_zapack_hu-huident.
  set_comp 'QTY'      gs_rf_mfg_hu gs_zapack_hu-qty.
  set_comp 'QUAN'     gs_rf_mfg_hu gs_zapack_hu-qty.
  set_comp 'UOM'      gs_rf_mfg_hu gs_zapack_hu-uom.
  set_comp 'ALTME'    gs_rf_mfg_hu gs_zapack_hu-uom.

ENDMODULE.


MODULE input_9001_loop INPUT ##NEEDED.
ENDMODULE.


MODULE user_command_9001 INPUT.

  CASE sy-ucomm.

    WHEN 'PGUP'.
      IF gv_zapack_idx > 1.
        gv_zapack_idx = gv_zapack_idx - 1.
      ENDIF.
      LEAVE TO SCREEN 9001.

    WHEN 'PGDN'.
      IF gv_zapack_idx < gv_zapack_lines.
        gv_zapack_idx = gv_zapack_idx + 1.
      ENDIF.
      LEAVE TO SCREEN 9001.

    WHEN 'ENTER' OR 'ENTR' OR 'OK'.
      LEAVE TO SCREEN 0.

  ENDCASE.

  CLEAR sy-ucomm.

ENDMODULE.
