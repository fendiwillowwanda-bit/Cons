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
    MESSAGE e031(zmsg_i2o_rf) RAISING error.
  ENDIF.

  IF lv_lgnum IS INITIAL.
    MESSAGE e022(zmsg_i2o_rf) RAISING error.
  ENDIF.

  IF lv_docid IS INITIAL.
    MESSAGE e040(zmsg_i2o_rf) RAISING error.
  ENDIF.

  IF lv_prod IS INITIAL.
    MESSAGE e022(zmsg_i2o_rf) RAISING error.
  ENDIF.

  IF lv_qty IS INITIAL.
    MESSAGE e023(zmsg_i2o_rf) RAISING error.
  ENDIF.

  IF lv_uom IS INITIAL.
    MESSAGE e033(zmsg_i2o_rf) RAISING error.
  ENDIF.

*--------------------------------------------------------------------*
* Get exact delivery item/batch for selected RF item
*--------------------------------------------------------------------*
  DATA: lv_batch_db      TYPE /scdl/dl_batchno,
        lv_prod_db       TYPE /scdl/dl_productno,
        lv_prod_int      TYPE /scdl/dl_productno,
        lv_entitled_db   TYPE /scwm/de_entitled,
        lv_plant         TYPE c LENGTH 4,
        lv_xchpf         TYPE marc-xchpf,
        lv_xchpf_found   TYPE abap_bool,
        lv_matnr_for_batch TYPE matnr,
        lv_batch_rejected  TYPE abap_bool.

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
    MESSAGE e030(zmsg_i2o_rf) RAISING error.
  ENDIF.

  " The persisted delivery item's batch (lv_batch_db) can still be blank
  " even after the user enters/creates a batch via the RF screen's own
  " F3 Batch step (lv_batch, read earlier from CHARG_VERIF/CHARG/BATCH),
  " if that entry hasn't been committed to /scdl/db_proci_i yet. Per the
  " FDS ("Or just click the Batch"), a screen-entered batch is valid on
  " its own - fall back to it instead of discarding it and erroring out.
  IF lv_batch_db IS INITIAL AND lv_batch IS NOT INITIAL.
    lv_batch_db = lv_batch.
  ENDIF.

  IF lv_batch_db IS INITIAL.

    CLEAR: lv_plant, lv_xchpf, lv_xchpf_found.

    PERFORM frm_derive_plant_from_entitled
      USING    lv_entitled_db
      CHANGING lv_plant.

    IF lv_plant IS NOT INITIAL.
      SELECT SINGLE xchpf ##WARN_OK
        FROM marc
        INTO @lv_xchpf
        WHERE matnr = @lv_prod_db
          AND werks = @lv_plant.
      lv_xchpf_found = boolc( sy-subrc = 0 ).
    ENDIF.

    " If the plant/MARC lookup can't be resolved, keep the original
    " strict behavior rather than silently letting a possibly
    " batch-managed material through unchecked.
    IF lv_xchpf_found = abap_false.
      MESSAGE e059(zmsg_i2o_rf) RAISING error.
    ENDIF.

    IF lv_xchpf = abap_true.
      " Batch-managed and no batch persisted yet: create/assign it
      " ourselves as Auto Pack's first priority action (FDS: "Batch
      " creation is done on first priority upon auto pack"), instead
      " of requiring F3 Batch to have already been pressed and saved.
      lv_matnr_for_batch = lv_prod_db.

      CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
        EXPORTING
          input  = lv_matnr_for_batch
        IMPORTING
          output = lv_matnr_for_batch.

      CLEAR lv_batch_rejected.

      PERFORM frm_ensure_batch_rehu
        USING    lv_lgnum
                 lv_docid
                 lv_itemid
                 lv_matnr_for_batch
                 lv_plant
        CHANGING lv_batch_db
                 lv_batch_rejected.

      IF lv_batch_rejected = abap_true OR lv_batch_db IS INITIAL.
        MESSAGE e029(zmsg_i2o_rf) RAISING error.
      ENDIF.

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

  " From here on, lo_pack->init( iv_lock_dlv = abap_true ) has already
  " locked the delivery. Every RAISING error below must release that
  " lock first (same CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK' +
  " /scwm/cl_tm=>cleanup( ) pattern the Process Order flow already
  " uses on all its error paths) - otherwise the lock is left stale
  " across RF transaction steps, causing later attempts (e.g. F3
  " Batch's own lo_dlv->lock() call) to fail with "item lock rejected".
  IF lv_foreign IS NOT INITIAL.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e028(zmsg_i2o_rf) RAISING error.
  ENDIF.

  IF lv_batch_init IS NOT INITIAL.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e060(zmsg_i2o_rf) RAISING error.
  ENDIF.

  IF lv_tw_items = abap_true.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e061(zmsg_i2o_rf) RAISING error.
  ENDIF.

  IF lv_asr_brfw = abap_true OR lv_asr_mixed = abap_true.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e062(zmsg_i2o_rf) RAISING error.
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
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e030(zmsg_i2o_rf) RAISING error.
  ENDIF.

  IF lv_guid_ps IS INITIAL.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e026(zmsg_i2o_rf) RAISING error.
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
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e026(zmsg_i2o_rf) RAISING error.
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
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      /scwm/cl_tm=>cleanup( ).
      MESSAGE e027(zmsg_i2o_rf) RAISING error.
    ENDIF.

    IF ls_return-message CS 'batch'
       OR ls_return-message CS 'Batch'
       OR ls_return-id = '/SCWM/RF_EN'
       OR ls_return-number = '395'.
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      /scwm/cl_tm=>cleanup( ).
      MESSAGE e029(zmsg_i2o_rf) RAISING error.
    ENDIF.

    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e063(zmsg_i2o_rf)
      WITH ls_return-message(50)
           ls_return-message+50(50)
           ls_return-message+100(50)
           ls_return-message+150(50)
      RAISING error.

  ENDIF.

  IF lt_huhdr IS INITIAL OR lt_huitm IS INITIAL.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    /scwm/cl_tm=>cleanup( ).
    MESSAGE e064(zmsg_i2o_rf) RAISING error.
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
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      /scwm/cl_tm=>cleanup( ).
      MESSAGE e063(zmsg_i2o_rf)
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

  MESSAGE s032(zmsg_i2o_rf).
  RETURN.

ENDFUNCTION.
