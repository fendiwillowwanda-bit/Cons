FUNCTION zfm_i2o_rf_rehu_zapack_pai.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  CHANGING
*"     REFERENCE(CS_REHU_HU) TYPE  /SCWM/S_RF_REHU_HU
*"     REFERENCE(CT_REHU_HU) TYPE  /SCWM/TT_RF_REHU_HU
*"     REFERENCE(CS_REHU) TYPE  /SCWM/S_RF_ADMIN_REHU
*"     REFERENCE(CS_REHU_PROD) TYPE  /SCWM/S_RF_REHU_PROD
*"     REFERENCE(CT_REHU_PROD) TYPE  /SCWM/TT_RF_REHU_PROD
*"     REFERENCE(CS_REHU_DLV) TYPE  /SCWM/S_RF_UNLO_DOCID
*"     REFERENCE(CT_REHU_DLV) TYPE  /SCWM/TT_RF_UNLO_DOCID
*"  EXCEPTIONS
*"      ERROR
*"----------------------------------------------------------------------

  DATA: lv_lgnum     TYPE /scwm/lgnum,
        lv_docid     TYPE /scwm/de_docid,
        lv_itemid    TYPE /scdl/dl_itemid,
        lv_prod      TYPE /scwm/de_rf_matnr,
        lv_dlvno     TYPE /scdl/dl_docno,
        lv_qty       TYPE /scdl/dl_quantity,
        lv_qty_char  TYPE /scwm/de_rf_qty_char,
        lv_uom       TYPE /scwm/de_unit,
        lv_batch     TYPE /scwm/de_rf_charg,
        lv_doccat    TYPE /scwm/de_doccat,
        lv_procedure TYPE /scwm/de_dlvap_ctlist,
        lv_valid_on  TYPE timestamp,
        lv_severity  TYPE bapi_mtype,
        lv_hist_id   TYPE indx_srtfd,
        lv_pmat      TYPE /scwm/de_rf_pmat,
        lv_guid_ps   TYPE /scwm/de_guid_ps,
        lv_save_errtext TYPE c LENGTH 200.

  DATA: lt_docid  TYPE /scwm/tt_docid,
        lt_items  TYPE /scwm/tt_ps_autopack,
        lt_huhdr  TYPE /scwm/tt_huhdr_int,
        lt_huitm  TYPE /scwm/tt_huitm_int,
        lt_return TYPE bapirettab,
        ls_return TYPE bapiret2.

  DATA: lo_pack       TYPE REF TO /scwm/cl_dlv_pack_ibdl,
        lv_foreign    TYPE xfeld,
        lv_batch_init TYPE char1,
        lv_tw_items   TYPE boole_d,
        lv_asr_brfw   TYPE boole_d,
        lv_asr_mixed  TYPE boole_d.

  FIELD-SYMBOLS: <lv_any>      TYPE any,
                 <ls_rehu_dlv> TYPE any.

  CONSTANTS:
    lc_doccat_inb TYPE /scwm/de_doccat       VALUE /scdl/if_dl_doc_c=>sc_doccat_inb_prd,
    lc_procedure  TYPE /scwm/de_dlvap_ctlist VALUE '0IBD'.

  DEFINE get_comp_if_initial.
    IF &2 IS INITIAL.
      ASSIGN COMPONENT &1 OF STRUCTURE &3 TO <lv_any>.
      IF sy-subrc = 0 AND <lv_any> IS ASSIGNED.
        &2 = <lv_any>.
        UNASSIGN <lv_any>.
      ENDIF.
    ENDIF.
  END-OF-DEFINITION.

*--------------------------------------------------------------------*
* Read RF values
*--------------------------------------------------------------------*
  get_comp_if_initial 'LGNUM' lv_lgnum cs_rehu.
  get_comp_if_initial 'LGNUM' lv_lgnum cs_rehu_hu.
  get_comp_if_initial 'LGNUM' lv_lgnum cs_rehu_prod.
  get_comp_if_initial 'LGNUM' lv_lgnum cs_rehu_dlv.

  get_comp_if_initial 'DOCID' lv_docid cs_rehu_dlv.
  get_comp_if_initial 'DOCID' lv_docid cs_rehu.
  get_comp_if_initial 'DOCID' lv_docid cs_rehu_hu.
  get_comp_if_initial 'DOCID' lv_docid cs_rehu_prod.

  IF lv_docid IS INITIAL.
    LOOP AT ct_rehu_dlv ASSIGNING <ls_rehu_dlv>.
      get_comp_if_initial 'DOCID' lv_docid <ls_rehu_dlv>.
      EXIT.
    ENDLOOP.
  ENDIF.

  get_comp_if_initial 'ITEMID' lv_itemid cs_rehu_hu.
  get_comp_if_initial 'RITMID' lv_itemid cs_rehu_hu.
  get_comp_if_initial 'ITEMID' lv_itemid cs_rehu_prod.

  get_comp_if_initial 'MATNR'       lv_prod cs_rehu_prod.
  get_comp_if_initial 'MATNR_VERIF' lv_prod cs_rehu_prod.
  get_comp_if_initial 'PROD'        lv_prod cs_rehu_prod.
  get_comp_if_initial 'PRODUCT'     lv_prod cs_rehu_prod.

  get_comp_if_initial 'NISTA_VERIF' lv_qty_char cs_rehu_prod.
  get_comp_if_initial 'NISTA'       lv_qty_char cs_rehu_prod.
  get_comp_if_initial 'QTY'         lv_qty_char cs_rehu_prod.

  get_comp_if_initial 'ALTME'       lv_uom cs_rehu_prod.
  get_comp_if_initial 'ALTME_VERIF' lv_uom cs_rehu_prod.
  get_comp_if_initial 'UOM'         lv_uom cs_rehu_prod.

  get_comp_if_initial 'CHARG_VERIF' lv_batch cs_rehu_prod.
  get_comp_if_initial 'CHARG'       lv_batch cs_rehu_prod.
  get_comp_if_initial 'BATCH'       lv_batch cs_rehu_prod.

  get_comp_if_initial 'PMAT' lv_pmat cs_rehu_hu.
  get_comp_if_initial 'PMAT' lv_pmat cs_rehu_prod.

  IF lv_qty_char IS NOT INITIAL.
    lv_qty = lv_qty_char.
  ENDIF.

*--------------------------------------------------------------------*
* Validations
*--------------------------------------------------------------------*
  IF lv_pmat IS NOT INITIAL.
    MESSAGE e398(00) WITH 'Packaging material must be blank for Auto Pack' RAISING error.
  ENDIF.

  IF lv_lgnum IS INITIAL.
    MESSAGE e398(00) WITH 'Warehouse number is required' RAISING error.
  ENDIF.

  IF lv_docid IS INITIAL.
    MESSAGE e398(00) WITH 'Inbound delivery is required for Auto Pack' RAISING error.
  ENDIF.

  IF lv_prod IS INITIAL.
    MESSAGE e398(00) WITH 'Product does not exist (/SCWM/MD002)' RAISING error.
  ENDIF.

  IF lv_qty IS INITIAL.
    MESSAGE e398(00) WITH 'Entered quantity is required for Auto Pack' RAISING error.
  ENDIF.

  IF lv_uom IS INITIAL.
    MESSAGE e398(00) WITH 'Unit of measure is required for Auto Pack' RAISING error.
  ENDIF.

*--------------------------------------------------------------------*
* Get exact delivery item/batch for selected RF item
*--------------------------------------------------------------------*
  DATA: lv_batch_db    TYPE /scdl/dl_batchno,
        lv_prod_db     TYPE /scdl/dl_productno,
        lv_prod_int    TYPE /scdl/dl_productno,
        lv_entitled_db TYPE /scwm/de_entitled,
        lv_plant       TYPE c LENGTH 4,
        lv_xchpf       TYPE marc-xchpf,
        lv_xchpf_found TYPE abap_bool.

  lv_dlvno = gv_dlvno.

  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = lv_dlvno
    IMPORTING
      output = lv_dlvno.

  lv_prod_int = lv_prod.

  CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
    EXPORTING
      input  = lv_prod_int
    IMPORTING
      output = lv_prod_int.

*--------------------------------------------------------------------*
* Priority 1: use selected itemid from RF screen
*--------------------------------------------------------------------*
  IF lv_itemid IS NOT INITIAL.

    SELECT SINGLE docid, itemid, productno, batchno, entitled
      FROM /scdl/db_proci_i
      WHERE docid  = @lv_docid
        AND itemid = @lv_itemid
      INTO (@lv_docid, @lv_itemid, @lv_prod_db, @lv_batch_db, @lv_entitled_db).

  ENDIF.

*--------------------------------------------------------------------*
* Priority 2: if itemid not available, use product + batch from RF screen
*--------------------------------------------------------------------*
  IF sy-subrc <> 0 OR lv_itemid IS INITIAL.

    SELECT SINGLE docid, itemid, productno, batchno, entitled
      FROM /scdl/db_proci_i
      WHERE docid     = @lv_docid
        AND productno = @lv_prod_int
        AND batchno   = @lv_batch
      INTO (@lv_docid, @lv_itemid, @lv_prod_db, @lv_batch_db, @lv_entitled_db).

  ENDIF.

*--------------------------------------------------------------------*
* Priority 3: fallback using delivery number + product + batch
*--------------------------------------------------------------------*
  IF sy-subrc <> 0 OR lv_itemid IS INITIAL.

    SELECT SINGLE docid, itemid, productno, batchno, entitled
      FROM /scdl/db_proci_i
      WHERE docno     = @lv_dlvno
        AND productno = @lv_prod_int
        AND batchno   = @lv_batch
      INTO (@lv_docid, @lv_itemid, @lv_prod_db, @lv_batch_db, @lv_entitled_db).

  ENDIF.

  IF sy-subrc <> 0 OR lv_itemid IS INITIAL.
    MESSAGE e398(00)
      WITH 'Selected delivery item/batch was not found '
           'for Auto Pack.'
      RAISING error.
  ENDIF.

  IF lv_batch_db IS INITIAL.

    CLEAR: lv_plant, lv_xchpf, lv_xchpf_found.

    PERFORM frm_derive_plant_from_entitled
      USING    lv_entitled_db
      CHANGING lv_plant.

    IF lv_plant IS NOT INITIAL.
      SELECT SINGLE xchpf
        FROM marc
        INTO @lv_xchpf
        WHERE matnr = @lv_prod_db
          AND werks = @lv_plant.
      lv_xchpf_found = boolc( sy-subrc = 0 ).
    ENDIF.

    " Only skip the error when MARC positively confirms the material is
    " NOT batch-managed (XCHPF space). If the plant/MARC lookup can't be
    " resolved, keep the original strict behavior rather than silently
    " letting a possibly batch-managed material through unchecked.
    IF lv_xchpf_found = abap_false OR lv_xchpf = abap_true.
      MESSAGE e398(00)
        WITH 'Batch is not saved on selected inbound '
             'delivery item.'
        RAISING error.
    ENDIF.

  ENDIF.

  lv_batch = lv_batch_db.
  lv_prod  = lv_prod_db.

*--------------------------------------------------------------------*
* Init packing object
*--------------------------------------------------------------------*
  gv_docid  = lv_docid.
  gv_lgnum  = lv_lgnum.
  gv_itemid = lv_itemid.
  gv_batch  = lv_batch.

  lv_doccat    = lc_doccat_inb.
  lv_procedure = lc_procedure.

  APPEND VALUE /scwm/s_docid( docid = lv_docid ) TO lt_docid.

  CREATE OBJECT lo_pack.

  lo_pack->init(
    EXPORTING
      iv_lgnum         = lv_lgnum
      it_docid         = lt_docid
      iv_doccat        = lv_doccat
      iv_no_refresh    = abap_false
      iv_lock_dlv      = abap_true
    IMPORTING
      ev_foreign_lock  = lv_foreign
      ev_batch_initial = lv_batch_init
      ev_tw_items      = lv_tw_items
      ev_asr_brfw      = lv_asr_brfw
      ev_asr_mixed     = lv_asr_mixed ).

  IF lv_foreign IS NOT INITIAL.
    MESSAGE e398(00) WITH 'Inbound delivery is locked by another user' RAISING error.
  ENDIF.

  IF lv_batch_init IS NOT INITIAL.
    MESSAGE e398(00) WITH 'Batch is still initial in packing item hierarchy' RAISING error.
  ENDIF.

  IF lv_tw_items = abap_true.
    MESSAGE e398(00)
      WITH 'Inbound delivery contains transportation '
           'unit items'
      RAISING error.
  ENDIF.

  IF lv_asr_brfw = abap_true OR lv_asr_mixed = abap_true.
    MESSAGE e398(00)
      WITH 'Inbound delivery status is not valid for '
           'Auto Pack'
      RAISING error.
  ENDIF.

*--------------------------------------------------------------------*
* Build AutoPack item and determine PackSpec explicitly
*--------------------------------------------------------------------*
  CLEAR lv_guid_ps.

  PERFORM frm_build_autopack_items_rehu
    USING    lv_lgnum
             lv_docid
             lv_itemid
             lv_doccat
             lv_prod
             lv_batch
             lv_qty
             lv_uom
             cs_rehu
    CHANGING lt_items
             lv_guid_ps.

  IF lt_items IS INITIAL.
    MESSAGE e398(00) WITH 'No delivery item found for Auto Pack' RAISING error.
  ENDIF.

  IF lv_guid_ps IS INITIAL.
    MESSAGE e398(00)
      WITH 'No packaging specification found for the '
           'Material. Please maintain on /SCWM/PACKSPEC '
           'and try again.'
      RAISING error.
  ENDIF.

*--------------------------------------------------------------------*
* Execute AutoPack
*--------------------------------------------------------------------*
  GET TIME STAMP FIELD lv_valid_on.

  CALL FUNCTION '/SCWM/HU_AUTOPACK_IBDLV'
    EXPORTING
      it_items       = lt_items
      iv_procedure   = lv_procedure
      iv_valid_on    = lv_valid_on
      iv_read_refmat = abap_true
      io_pack        = lo_pack
    IMPORTING
      et_huhdr       = lt_huhdr
      et_huitm       = lt_huitm
      et_return      = lt_return
      ev_severity    = lv_severity.

*--------------------------------------------------------------------*
* Error handling
*--------------------------------------------------------------------*
  CLEAR ls_return.

  " /SCWM/HU_AUTOPACK_IBDLV returns this as a plain W-type message, and
  " the ID has been observed in lowercase ('/scwm/condtech_basic') at
  " runtime even though the message class is '/SCWM/CONDTECH_BASIC' -
  " READ TABLE ... WITH KEY is case-sensitive on character fields, so
  " match id case-insensitively instead of relying on WITH KEY for it.
  LOOP AT lt_return INTO ls_return WHERE number = '006'.
    IF to_upper( ls_return-id ) = '/SCWM/CONDTECH_BASIC'.
      EXIT.
    ENDIF.
    CLEAR ls_return.
  ENDLOOP.

  IF ls_return IS NOT INITIAL AND lt_huhdr IS INITIAL.
    MESSAGE e398(00)
      WITH 'No packaging specification found for the '
           'Material. Please maintain on /SCWM/PACKSPEC '
           'and try again.'
      RAISING error.
  ENDIF.

  CLEAR ls_return.
  READ TABLE lt_return INTO ls_return WITH KEY type = 'E'.

  IF sy-subrc = 0.

    " Best-effort classification by message text (the underlying FMs
    " don't expose a stable ID/number for these two cases the way the
    " PackSpec-not-found case does above) - breaks under a non-English
    " logon language; falls through to the generic message below.
    IF ls_return-message CS 'Min'
       OR ls_return-message CS 'min'
       OR ls_return-message CS 'minimum'.
      MESSAGE e398(00)
        WITH 'Min. quantity of packaging specification '
             'not met.'
        RAISING error.
    ENDIF.

    IF ls_return-message CS 'batch'
       OR ls_return-message CS 'Batch'
       OR ls_return-id = '/SCWM/RF_EN'
       OR ls_return-number = '395'.
      MESSAGE e398(00)
        WITH 'Batch creation failed; auto-pack cannot '
             'proceed.'
        RAISING error.
    ENDIF.

    MESSAGE e398(00)
      WITH ls_return-message(50)
           ls_return-message+50(50)
           ls_return-message+100(50)
           ls_return-message+150(50)
      RAISING error.

  ENDIF.

  IF lt_huhdr IS INITIAL OR lt_huitm IS INITIAL.
    MESSAGE e398(00) WITH 'AutoPack did not create HU item' RAISING error.
  ENDIF.

*--------------------------------------------------------------------*
* Save to PRDI
*--------------------------------------------------------------------*
  TRY.
      lo_pack->save( ).
    CATCH cx_root INTO DATA(lx_save).
      " lx_save->get_text( ) returns a dynamic-length STRING; slicing it
      " directly with fixed offsets dumps (CX_SY_RANGE_OUT_OF_BOUNDS) once
      " the text is shorter than the requested offset, which is the common
      " case. Copy into a fixed-length (space-padded) buffer first.
      lv_save_errtext = lx_save->get_text( ).
      MESSAGE e398(00)
        WITH lv_save_errtext(50)
             lv_save_errtext+50(50)
             lv_save_errtext+100(50)
             lv_save_errtext+150(50)
        RAISING error.
  ENDTRY.

  COMMIT WORK AND WAIT.

*--------------------------------------------------------------------*
* Prepare HU list for 9016
*--------------------------------------------------------------------*
  PERFORM frm_get_zapack_hist_id
    USING    gv_docid
             gv_itemid
             gv_batch
    CHANGING lv_hist_id.

  IMPORT gt_zapack_hu = gt_zapack_hu
    FROM DATABASE indx(zz)
    ID lv_hist_id.

  CLEAR: gt_zap_huhdr,
         gt_zap_huitm,
         gs_zapack_hu,
         gv_zapack_lines.

  APPEND LINES OF lt_huhdr TO gt_zap_huhdr.
  APPEND LINES OF lt_huitm TO gt_zap_huitm.

  PERFORM frm_prepare_zapack_hu.

  gv_zapack_idx   = 1.
  gv_zapack_lines = lines( gt_zapack_hu ).

  EXPORT gt_zapack_hu = gt_zapack_hu
    TO DATABASE indx(zz)
    ID lv_hist_id.

  MESSAGE s398(00) WITH 'AutoPack executed and saved successfully'.
  RETURN.

ENDFUNCTION.
