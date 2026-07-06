FUNCTION zfm_i2o_rf_mrhu_zapack_pai.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  CHANGING
*"     REFERENCE(CS_MFG_RCV_HU) TYPE  /SCWM/S_RF_MFG_RCV_HU
*"     REFERENCE(CS_MFG_RCV_WC) TYPE  /SCWM/S_RF_MFG_RCV_WC
*"  EXCEPTIONS
*"      ERROR
*"----------------------------------------------------------------------

  CONSTANTS:
    lc_doccat_inb TYPE /scwm/de_doccat       VALUE /scdl/if_dl_doc_c=>sc_doccat_inb_prd,
    lc_procedure  TYPE /scwm/de_dlvap_ctlist VALUE '0IBD'.

  DATA:
    lv_lgnum        TYPE /scwm/lgnum,
    lv_manuford     TYPE /scwm/de_rf_prod_order,
    lv_qty          TYPE /scwm/de_rf_qty,
    lv_qty_dlv      TYPE /scdl/dl_quantity,
    lv_qty_rf       TYPE /scwm/de_rf_qty_char,
    lv_uom          TYPE /scwm/de_unit,
    lv_uom_int      TYPE /scwm/de_unit,
    lv_uom_pack     TYPE /scwm/de_unit,
    lv_prod         TYPE /scwm/de_rf_matnr,
    lv_prod_int     TYPE /scdl/dl_productno,
    lv_bin          TYPE /scwm/lgpla,
    lv_docid        TYPE /scwm/de_docid,
    lv_itemid       TYPE /scdl/dl_itemid,
    lv_check_itemid TYPE /scdl/dl_itemid,
    lv_doccat       TYPE /scwm/de_doccat,
    lv_severity     TYPE bapi_mtype ##NEEDED,
    lv_valid_on     TYPE timestamp,
    lv_hist_id      TYPE indx_srtfd,
    lv_qty_per_hu   TYPE /scwm/de_rf_qty VALUE '1',
    lv_pmat_auto    TYPE /scwm/de_rf_pmat,
    lv_hutyp        TYPE /scwm/de_rf_hu_typ,
    lv_batch        TYPE /scwm/de_rf_charg,
    lv_pddat        TYPE /scwm/sp_pddat,
    lv_sled         TYPE /scwm/sled,
    lv_guid_ps      TYPE /scwm/de_guid_ps,
    lv_matid        TYPE /scwm/de_matid,
    lv_docno        TYPE /scdl/dl_docno ##NEEDED,
    lv_pak_plant    TYPE c LENGTH 4,
    lv_entitled     TYPE /scwm/de_entitled,
    lv_dlv_uom      TYPE /scwm/de_unit,
    lv_gmbin        TYPE /scwm/dl_gmbin,
    lv_message      TYPE string.

  DATA:
    lt_docid  TYPE /scwm/tt_docid,
    lt_items  TYPE /scwm/tt_ps_autopack,
    lt_huhdr  TYPE /scwm/tt_huhdr_int,
    lt_huitm  TYPE /scwm/tt_huitm_int,
    lt_return TYPE bapirettab,
    ls_return TYPE bapiret2.

  DATA:
    lv_egr_docid  TYPE /scdl/dl_docid,
    lv_egr_itemid TYPE /scdl/dl_itemid,
    lv_success    TYPE abap_bool,
    lt_bapiret    TYPE bapirettab ##NEEDED.

  DATA:
    ls_proci_pai TYPE /scdl/db_proci_i,
    lo_pack      TYPE REF TO /scwm/cl_dlv_pack_ibdl.

  DATA:
    lv_foreign_lock  TYPE xfeld,
    lv_batch_initial TYPE char1,
    lv_tw_items      TYPE boole_d,
    lv_asr_brfw      TYPE boole_d,
    lv_asr_mixed     TYPE boole_d.

  FIELD-SYMBOLS:
    <lv_any> TYPE any.

  DEFINE get_comp.
    IF &2 IS INITIAL.
      ASSIGN COMPONENT &1 OF STRUCTURE &3 TO <lv_any>.
      IF sy-subrc = 0 AND <lv_any> IS ASSIGNED.
        &2 = <lv_any>.
        UNASSIGN <lv_any>.
      ENDIF.
    ENDIF.
  END-OF-DEFINITION.

  DEFINE set_comp.
    ASSIGN COMPONENT &1 OF STRUCTURE &2 TO <lv_any>.
    IF sy-subrc = 0 AND <lv_any> IS ASSIGNED.
      <lv_any> = &3.
      UNASSIGN <lv_any>.
    ENDIF.
  END-OF-DEFINITION.

*--------------------------------------------------------------------*
* Read RF values
*--------------------------------------------------------------------*
  get_comp 'LGNUM'       lv_lgnum    cs_mfg_rcv_wc.
  get_comp 'LGNUM'       lv_lgnum    cs_mfg_rcv_hu.

  get_comp 'LGPLA'       lv_bin      cs_mfg_rcv_wc.
  get_comp 'BIN'         lv_bin      cs_mfg_rcv_hu.
  get_comp 'LGPLA'       lv_bin      cs_mfg_rcv_hu.
  get_comp 'NLPLA'       lv_bin      cs_mfg_rcv_hu.

  get_comp 'PROD_ORDER'  lv_manuford cs_mfg_rcv_hu.
  get_comp 'MANUFORD'    lv_manuford cs_mfg_rcv_hu.

  get_comp 'MATNR'       lv_prod     cs_mfg_rcv_hu.
  get_comp 'MATNR_VERIF' lv_prod     cs_mfg_rcv_hu.
  get_comp 'PROD'        lv_prod     cs_mfg_rcv_hu.
  get_comp 'PRODUCT'     lv_prod     cs_mfg_rcv_hu.

  get_comp 'QTY'         lv_qty_rf   cs_mfg_rcv_hu.
  get_comp 'QTY_LABEL'   lv_qty_rf   cs_mfg_rcv_hu.
  get_comp 'ACTQTY'      lv_qty_rf   cs_mfg_rcv_hu.

  get_comp 'CHARG'       lv_batch    cs_mfg_rcv_hu.
  get_comp 'BATCHNO'     lv_batch    cs_mfg_rcv_hu.
  get_comp 'BATCH'       lv_batch    cs_mfg_rcv_hu.

  get_comp 'PDDAT'       lv_pddat    cs_mfg_rcv_hu.
  get_comp 'PDATE'       lv_pddat    cs_mfg_rcv_hu.

  get_comp 'SLED'        lv_sled     cs_mfg_rcv_hu.
  get_comp 'VFDAT'       lv_sled     cs_mfg_rcv_hu.
  get_comp 'BBD'         lv_sled     cs_mfg_rcv_hu.

  IF lv_qty_rf IS NOT INITIAL.
    lv_qty = lv_qty_rf.
    CONDENSE lv_qty NO-GAPS.
  ENDIF.

  get_comp 'ALTME'       lv_uom      cs_mfg_rcv_hu.
  get_comp 'UOM'         lv_uom      cs_mfg_rcv_hu.

*--------------------------------------------------------------------*
* Validate PMAT input - must be blank for AutoPack
*--------------------------------------------------------------------*
  DATA lv_pmat_input TYPE /scwm/de_rf_pmat.

  get_comp 'PMAT' lv_pmat_input cs_mfg_rcv_hu.

  IF lv_pmat_input IS NOT INITIAL.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e031(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  gv_manuford = lv_manuford.

  CLEAR lv_hist_id.

  PERFORM frm_get_zapack_hist_id
    USING    lv_manuford
    CHANGING lv_hist_id.

  DELETE FROM DATABASE indx(zz) ID lv_hist_id.
  FREE MEMORY ID lv_hist_id.

  CLEAR lv_hist_id.

  PERFORM frm_get_zapack_hist_id
    USING    sy-uname
    CHANGING lv_hist_id.

  DELETE FROM DATABASE indx(zz) ID lv_hist_id.
  FREE MEMORY ID lv_hist_id.

  CLEAR:
    gt_zapack_hu,
    gt_zap_huhdr,
    gt_zap_huitm,
    gs_zapack_hu,
    gv_zapack_idx,
    gv_zapack_lines.

*--------------------------------------------------------------------*
* Validate RF input
*--------------------------------------------------------------------*
  IF lv_lgnum    IS INITIAL
  OR lv_manuford IS INITIAL
  OR lv_prod     IS INITIAL
  OR lv_qty      IS INITIAL
  OR lv_uom      IS INITIAL
  OR lv_bin      IS INITIAL.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e022(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  IF lv_qty <= 0.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e023(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* Normalize product and UoM
*--------------------------------------------------------------------*
  PERFORM frm_normalize_uom
    USING    lv_uom
    CHANGING lv_uom_int.

  IF lv_uom_int IS INITIAL.
    lv_uom_int = lv_uom.
  ENDIF.

  lv_qty_dlv  = lv_qty.
  lv_prod_int = lv_prod.

  CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
    EXPORTING
      input        = lv_prod_int
    IMPORTING
      output       = lv_prod_int
    EXCEPTIONS
      length_error = 1
      OTHERS       = 2.

  IF sy-subrc <> 0.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e037(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* Get EGR item for process order/product
*--------------------------------------------------------------------*
  CLEAR:
    lv_egr_docid,
    lv_egr_itemid.

  PERFORM frm_get_egr_item_for_mrhu
    USING    lv_lgnum
             lv_manuford
             lv_prod_int
    CHANGING lv_egr_docid
             lv_egr_itemid.

  IF lv_egr_docid IS INITIAL OR lv_egr_itemid IS INITIAL.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e024(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* Create PDI from EGR
*--------------------------------------------------------------------*
  CLEAR:
    lv_docid,
    lv_itemid,
    lv_docno,
    lv_success,
    lv_message,
    lt_bapiret.

  CALL FUNCTION 'ZFM_I2O_RF_MRHU_CRT_IBD_DOCID'
    EXPORTING
      iv_lgnum      = lv_lgnum
      iv_egr_docid  = lv_egr_docid
      iv_egr_itemid = lv_egr_itemid
      iv_lgpla      = lv_bin
    IMPORTING
      ev_docid      = lv_docid
      ev_itemid     = lv_itemid
      ev_docno      = lv_docno
      ev_success    = lv_success
      ev_message    = lv_message
      et_bapiret    = lt_bapiret
    EXCEPTIONS
      error         = 1
      OTHERS        = 2.

  IF sy-subrc <> 0
  OR lv_success <> abap_true
  OR lv_docid IS INITIAL
  OR lv_itemid IS INITIAL.

    /scwm/cl_tm=>cleanup( ).

    IF lv_message IS INITIAL.
      MESSAGE e025(zmsg_i2o_rf) INTO lv_message.
    ELSE.
      MESSAGE e016(zmsg_i2o_rf) WITH lv_message INTO lv_message.
    ENDIF.

    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* Read saved PDI item and validate GMBIN from BAdI/BRF+
*--------------------------------------------------------------------*
  CLEAR:
    lv_check_itemid,
    lv_gmbin,
    ls_proci_pai.

  SELECT SINGLE *
    FROM /scdl/db_proci_i
    WHERE docid  = @lv_docid
      AND itemid = @lv_itemid
    INTO @ls_proci_pai.

  IF sy-subrc <> 0 OR ls_proci_pai IS INITIAL.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e025(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  lv_check_itemid = ls_proci_pai-itemid.

  IF lv_check_itemid IS INITIAL.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e025(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  get_comp '/SCWM/GMBIN' lv_gmbin ls_proci_pai.
  get_comp 'GMBIN'       lv_gmbin ls_proci_pai.

  IF lv_gmbin IS INITIAL.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e020(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* Use PDI item as source for AutoPack
*--------------------------------------------------------------------*
  lv_qty_dlv  = lv_qty.
  lv_prod_int = ls_proci_pai-productno.
  lv_batch    = ls_proci_pai-batchno.
  lv_dlv_uom  = ls_proci_pai-uom.
  lv_matid    = ls_proci_pai-productid.
  lv_entitled = ls_proci_pai-entitled.

  IF lv_matid IS INITIAL.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e025(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  IF lv_dlv_uom IS INITIAL.
    lv_dlv_uom = lv_uom_int.
  ENDIF.

  IF lv_dlv_uom IS INITIAL.
    lv_dlv_uom = lv_uom.
  ENDIF.

  lv_uom_pack = lv_dlv_uom.

*--------------------------------------------------------------------*
* Derive plant from entitled
*--------------------------------------------------------------------*
  CLEAR lv_pak_plant.

  IF lv_entitled CP 'PLANT*'.
    lv_pak_plant = lv_entitled+5(4).
  ENDIF.

  IF lv_pak_plant IS INITIAL.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e026(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  cs_mfg_rcv_hu-s_item-product-productid = lv_matid.

*--------------------------------------------------------------------*
* Get PMAT / GUID_PS from PackSpec
*--------------------------------------------------------------------*
  CLEAR:
    lv_pmat_auto,
    lv_guid_ps.

  PERFORM frm_pmat_from_packspec_mrhu
    USING    lv_matid
             lv_pak_plant
             lv_qty_per_hu
             lv_uom_pack
    CHANGING lv_pmat_auto
             lv_guid_ps.

  IF lv_pmat_auto IS INITIAL OR lv_guid_ps IS INITIAL.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e026(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  CLEAR lv_hutyp.

  SELECT SINGLE hutyp_dflt ##WARN_OK
    FROM scmprd_matkey
    WHERE matnr = @lv_pmat_auto
    INTO @lv_hutyp.

  IF lv_hutyp IS INITIAL.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e027(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* Init standard inbound delivery packing object
*--------------------------------------------------------------------*
  lv_doccat = lc_doccat_inb.

  CLEAR lt_docid.
  APPEND VALUE /scwm/s_docid( docid = lv_docid ) TO lt_docid.

  TRY.
      /scwm/cl_tm=>cleanup( ).

      /scwm/cl_tm=>set_lgnum(
        EXPORTING
          iv_lgnum = lv_lgnum ).

      CREATE OBJECT lo_pack.

      CLEAR:
        lv_foreign_lock,
        lv_batch_initial,
        lv_tw_items,
        lv_asr_brfw,
        lv_asr_mixed.

      lo_pack->init(
        EXPORTING
          iv_lgnum         = lv_lgnum
          it_docid         = lt_docid
          iv_doccat        = lv_doccat
          iv_no_refresh    = abap_false
          iv_lock_dlv      = abap_true
        IMPORTING
          ev_foreign_lock  = lv_foreign_lock
          ev_batch_initial = lv_batch_initial
          ev_tw_items      = lv_tw_items
          ev_asr_brfw      = lv_asr_brfw
          ev_asr_mixed     = lv_asr_mixed ).

    CATCH cx_root INTO DATA(lx_pack_init).
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      /scwm/cl_tm=>cleanup( ).
      lv_message = lx_pack_init->get_text( ).
      MESSAGE e016(zmsg_i2o_rf) WITH lv_message INTO lv_message.
      MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
  ENDTRY.

  IF lv_foreign_lock IS NOT INITIAL.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e028(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  IF lv_batch_initial IS NOT INITIAL.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e029(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  IF lv_tw_items = abap_true.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e016(zmsg_i2o_rf) WITH 'Inbound delivery contains TU items' INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  IF lv_asr_brfw = abap_true OR lv_asr_mixed = abap_true.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e016(zmsg_i2o_rf) WITH 'Inbound delivery status is not valid for AutoPack' INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* Build AutoPack item from saved PDI
*--------------------------------------------------------------------*
  CLEAR lt_items.

  PERFORM frm_build_autopack_items_mrhu
    USING    lv_lgnum
             lv_docid
             lv_itemid
             lv_doccat
             lv_prod_int
             lv_qty_dlv
             lv_uom_pack
             lv_guid_ps
             lv_hutyp
             lv_gmbin
    CHANGING lt_items.

  IF lt_items IS INITIAL.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e030(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* Execute standard AutoPack
*--------------------------------------------------------------------*
  GET TIME STAMP FIELD lv_valid_on.

  CLEAR:
    lt_huhdr,
    lt_huitm,
    lt_return,
    lv_severity.

  CALL FUNCTION '/SCWM/HU_AUTOPACK_IBDLV'
    EXPORTING
      it_items       = lt_items
      iv_procedure   = lc_procedure
      iv_valid_on    = lv_valid_on
      iv_read_refmat = abap_true
      io_pack        = lo_pack
    IMPORTING
      et_huhdr       = lt_huhdr
      et_huitm       = lt_huitm
      et_return      = lt_return
      ev_severity    = lv_severity.

*--------------------------------------------------------------------*
* AutoPack error handling
*--------------------------------------------------------------------*
  CLEAR ls_return.

  READ TABLE lt_return INTO ls_return WITH KEY type = 'A'.
  IF sy-subrc = 0.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e016(zmsg_i2o_rf) WITH ls_return-message INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  CLEAR ls_return.

  READ TABLE lt_return INTO ls_return WITH KEY type = 'E'.
  IF sy-subrc = 0.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e016(zmsg_i2o_rf) WITH ls_return-message INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  IF lt_huhdr IS INITIAL.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e031(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* Save packing
*--------------------------------------------------------------------*
  TRY.
      lo_pack->/scwm/if_pack_bas~save( ).

    CATCH cx_root INTO DATA(lx_pack_save).
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      /scwm/cl_tm=>cleanup( ).
      lv_message = lx_pack_save->get_text( ).
      MESSAGE e016(zmsg_i2o_rf) WITH lv_message INTO lv_message.
      MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
  ENDTRY.

  COMMIT WORK AND WAIT.

  WAIT UP TO 1 SECONDS.

*--------------------------------------------------------------------*
* Prepare RF 9001 display
*--------------------------------------------------------------------*
  CLEAR:
    gt_zapack_hu,
    gt_zap_huhdr,
    gt_zap_huitm,
    gs_zapack_hu,
    gv_zapack_lines.

  "Use AutoPack result first
  APPEND LINES OF lt_huhdr TO gt_zap_huhdr.
  APPEND LINES OF lt_huitm TO gt_zap_huitm.

  "Fallback from DB only if AutoPack result is blank
  IF gt_zap_huhdr IS INITIAL OR gt_zap_huitm IS INITIAL.

    PERFORM frm_get_zapack_hus_from_dlv
      USING    lv_lgnum
               lv_docid
               lv_itemid
               lv_doccat
      CHANGING gt_zap_huhdr
               gt_zap_huitm.

  ENDIF.

  PERFORM frm_prepare_zapack_hu USING lv_uom_pack.

  IF gt_zapack_hu IS INITIAL.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e031(zmsg_i2o_rf) INTO lv_message.
    MESSAGE lv_message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  gv_zapack_idx   = 1.
  gv_zapack_lines = lines( gt_zapack_hu ).

  CLEAR lv_hist_id.

  PERFORM frm_get_zapack_hist_id
    USING    lv_manuford
    CHANGING lv_hist_id.

  DELETE FROM DATABASE indx(zz) ID lv_hist_id.

  EXPORT gt_zapack_hu = gt_zapack_hu
    TO DATABASE indx(zz)
    ID lv_hist_id.

  EXPORT gt_zapack_hu = gt_zapack_hu
    TO MEMORY ID lv_hist_id.

  COMMIT WORK AND WAIT.

  CLEAR lv_hist_id.

  PERFORM frm_get_zapack_hist_id
    USING    sy-uname
    CHANGING lv_hist_id.

  DELETE FROM DATABASE indx(zz) ID lv_hist_id.

  EXPORT gt_zapack_hu = gt_zapack_hu
    TO DATABASE indx(zz)
    ID lv_hist_id.

  EXPORT gt_zapack_hu = gt_zapack_hu
    TO MEMORY ID lv_hist_id.

*--------------------------------------------------------------------*
* Clear RF input fields
*--------------------------------------------------------------------*
  set_comp 'RFHU'     cs_mfg_rcv_hu space.
  set_comp 'HU'       cs_mfg_rcv_hu space.
  set_comp 'HUIDENT'  cs_mfg_rcv_hu space.
  set_comp 'RFLASTHU' cs_mfg_rcv_hu space.
  set_comp 'PMAT'     cs_mfg_rcv_hu space.
  set_comp 'HUTYP'    cs_mfg_rcv_hu space.

  /scwm/cl_tm=>cleanup( ).

  MESSAGE s032(zmsg_i2o_rf).

ENDFUNCTION.
