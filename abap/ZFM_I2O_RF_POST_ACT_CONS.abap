FUNCTION zfm_i2o_rf_post_act_cons.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(IS_STATIC_DATA) TYPE  /SCWM/S_RF_MFG_CON_STATIC_DATA
*"     REFERENCE(IS_SCREEN_DATA) TYPE  /SCWM/S_RF_MFG_CON_SCREEN_DATA
*"  CHANGING
*"     REFERENCE(CS_CHG_DATA) TYPE  /SCWM/S_RF_MFG_CON_CHG_DATA
*"  EXCEPTIONS
*"      ERROR
*"----------------------------------------------------------------------

  CONSTANTS:
    lc_over TYPE /scwm/de_reason VALUE 'OVER',
    lc_shrt TYPE /scwm/de_reason VALUE 'SHRT'.

  DATA:
    lv_lgnum      TYPE /scwm/lgnum,
    lv_reason     TYPE /scwm/de_reason,
    lv_pi_reason  TYPE /lime/pi_reason,
    lv_actual_qty TYPE /scwm/de_quantity,
    lv_plan_qty   TYPE /scwm/de_quantity,
    lv_diff_qty   TYPE /scwm/de_quantity,
    lv_abs_diff   TYPE /scwm/de_quantity,
    lv_tol_pct    TYPE decfloat34,
    lv_tol_qty    TYPE /scwm/de_quantity,
    lv_proc_type  TYPE /lime/pi_process_type,
    lv_doc_type   TYPE /lime/pi_document_type,
    lv_pi_area    TYPE /lime/pi_de_pi_aread,
    lv_pval02     TYPE ztxca_config-pval02,
    lv_severity   TYPE bapi_mtype,
    lv_huident    TYPE /scwm/de_huident,
    lv_matnr      TYPE /scwm/de_matnr,
    lv_charg      TYPE /scwm/de_charg,
    lv_matid      TYPE /scwm/de_matid,
    lv_batchid    TYPE /scwm/de_batchid,
    lv_lgpla      TYPE /scwm/lgpla,
    lv_lgtyp      TYPE /scwm/lgtyp,
    lv_match      TYPE abap_bool,
    lv_recount    TYPE abap_bool.

  " Identifies the exact quant this transaction resolved via
  " /SCWM/SELECT_STOCK, so the Diff Analyzer step below can be scoped
  " to just this stock item instead of every outstanding difference
  " for the material (see GUID_STOCK usage further down).
  DATA:
    lv_guid_stock TYPE x LENGTH 16.

  " Order/component material that this consumption step is bound to.
  " Used to validate the material resolved from the scanned HU is
  " actually the BOM component of the Process Order (FDS error
  " condition: "Material identified is not included in the BOM of
  " the Process Order").
  DATA:
    lv_order_matid TYPE /scwm/de_matid.

  DATA:
    ls_head_create TYPE /lime/pi_head_create,
    lt_item_create TYPE /lime/pi_t_item_create,
    ls_item_create TYPE /lime/pi_item_create,
    ls_head_count  TYPE /lime/pi_head,
    lt_item_count  TYPE /lime/pi_t_item_count,
    ls_item_count  TYPE /lime/pi_item_count,
    lt_pi_doc      TYPE /lime/pi_t_item_read,
    ls_pi_doc      TYPE /lime/pi_item_read,
    lt_bapiret     TYPE bapiret2_t,
    ls_bapiret     TYPE bapiret2,
    lv_count_ts    TYPE /lime/pi_count_date.

  DATA:
    lt_reason TYPE ztt_i2o_brf_reason_code,
    lt_tol    TYPE ztt_i2o_brf_con_tolerance,
    ls_tol    TYPE zsi2o_brf_con_tolerance.

  DATA:
    lt_item_post TYPE /lime/pi_t_item_post,
    ls_item_post TYPE /lime/pi_item_post.

  DATA:
    lt_huitm TYPE /scwm/tt_stock_select,
    lt_huhdr TYPE /scwm/tt_huhdr.

  DATA:
    lt_r_huident TYPE rseloption,
    ls_r_huident TYPE rsdsselopt.

  DATA:
    ls_head_read  TYPE /lime/pi_head_attributes,
    lt_item_query TYPE /lime/pi_t_item_read,
    ls_item_query TYPE /lime/pi_item_read,
    lt_item_read  TYPE /lime/pi_t_item_read_getsingle.

*--------------------------------------------------------------------*
* Follow-up document lookup (RECOUNT chain)
*--------------------------------------------------------------------*
  TYPES: BEGIN OF ty_ref_cand,
           doc_number TYPE /lime/pi_doc_number,
           doc_year   TYPE /lime/pi_doc_year,
           item_no    TYPE /lime/line_item_id,
         END OF ty_ref_cand.

  DATA: ls_doc_ref_q   TYPE /lime/pi_doc_ref,
        ls_item_read_q TYPE /lime/pi_item_read,
        lt_item_read_q TYPE /lime/pi_t_item_read,
        lt_item_read_s TYPE /lime/pi_t_item_read_getsingle,
        ls_pi_doc_new  TYPE /lime/pi_item_read,
        lv_found_new   TYPE abap_bool,
        lt_ref_cand    TYPE STANDARD TABLE OF ty_ref_cand WITH EMPTY KEY,
        ls_ref_cand    TYPE ty_ref_cand,
        lv_ref_id      TYPE c LENGTH 70,
        lv_len         TYPE i,
        lv_off_docno   TYPE i,
        lv_off_item    TYPE i.

  FIELD-SYMBOLS:
    <ls_item_read_s> TYPE LINE OF /lime/pi_t_item_read_getsingle,
    <ls_logitem_any> TYPE any,
    <lt_logitem>     TYPE ANY TABLE,
    <lv_ref_doc_id>  TYPE any.

  FIELD-SYMBOLS:
    <ls_item_read> TYPE LINE OF /lime/pi_t_item_read_getsingle,
    <ls_cnt_res>   TYPE any,
    <lt_cnt_quan>  TYPE ANY TABLE,
    <ls_cnt_quan>  TYPE any.

  FIELD-SYMBOLS:
    <ls_read_data> TYPE any,
    <ls_cnt_data>  TYPE any.

  FIELD-SYMBOLS:
    <lv_comp>       TYPE any,
    <lv_src>        TYPE any,
    <ls_data>       TYPE any,
    <ls_stock>      TYPE any,
    <ls_hu>         TYPE any,
    <ls_loc>        TYPE any,
    <ls_loc_parent> TYPE any,
    <ls_huitm>      TYPE any,
    <ls_huhdr>      TYPE any,
    <lt_result>     TYPE ANY TABLE,
    <ls_result>     TYPE any,
    <ls_res_data>   TYPE any,
    <ls_res_stock>  TYPE any.

  FIELD-SYMBOLS:
    <lv_status>     TYPE any.

  DEFINE set_comp.
    ASSIGN COMPONENT &1 OF STRUCTURE &2 TO <lv_comp>.
    IF sy-subrc = 0.
      <lv_comp> = &3.
    ENDIF.
  END-OF-DEFINITION.

  DEFINE copy_comp.
    ASSIGN COMPONENT &1 OF STRUCTURE &2 TO <lv_src>.
    IF sy-subrc = 0 AND <lv_src> IS NOT INITIAL.
      ASSIGN COMPONENT &3 OF STRUCTURE &4 TO <lv_comp>.
      IF sy-subrc = 0.
        <lv_comp> = <lv_src>.
      ENDIF.
    ENDIF.
  END-OF-DEFINITION.

  lv_lgnum      = is_static_data-lgnum.
  lv_reason     = is_screen_data-zzreason_code.
  lv_actual_qty = cs_chg_data-consumed_qty.

  IF lv_actual_qty IS INITIAL OR lv_actual_qty <= 0.
    MESSAGE e058(zmsg_i2o_rf) WITH 'ActQ' RAISING error.
  ENDIF.

  IF lv_reason IS INITIAL.
    MESSAGE e056(zmsg_i2o_rf) RAISING error.
  ENDIF.

*--------------------------------------------------------------------*
* Planned quantity
*--------------------------------------------------------------------*
  IF is_screen_data-consumed_qty IS NOT INITIAL.
    lv_plan_qty = is_screen_data-consumed_qty.
  ELSEIF cs_chg_data-qty_int IS NOT INITIAL.
    " ConsQ is mandatorily blank whenever ActQ is used (mutual
    " exclusion enforced in ZFM_I2O_RF_MICOTR_MIQUSL_PAI), so this is
    " the normal path: qty_int carries the system-suggested/nominal
    " component quantity forward from PBO independently of the
    " ConsQ screen field the user cleared.
    lv_plan_qty = cs_chg_data-qty_int.
  ENDIF.

  IF lv_plan_qty IS INITIAL OR lv_plan_qty <= 0.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

*--------------------------------------------------------------------*
* Reason validation
*--------------------------------------------------------------------*
  DATA(lv_pres_prf) = /scwm/cl_rf_bll_srvc=>get_pres_prf( ).
  DATA(lv_prsn_prf) = /scwm/cl_rf_bll_srvc=>get_prsn_prf( ).

  zcl_brfplus_data=>get_reason_code(
    EXPORTING
      iv_pres_prf = lv_pres_prf
      iv_prsn_prf = lv_prsn_prf
    IMPORTING
      et_result   = lt_reason ).

  READ TABLE lt_reason TRANSPORTING NO FIELDS WITH KEY reason = lv_reason.
  IF sy-subrc <> 0 OR
     ( lv_reason <> lc_over AND lv_reason <> lc_shrt ).
    MESSAGE e052(zmsg_i2o_rf) RAISING error.
  ENDIF.

*--------------------------------------------------------------------*
* Get tolerance from BRF+ (one row per warehouse - ZDT_CON_TOLERANCE)
*--------------------------------------------------------------------*
  CLEAR: lt_tol, ls_tol.

  zcl_brfplus_data=>get_con_tolerance(
    EXPORTING
      iv_lgnum  = lv_lgnum
    IMPORTING
      et_result = lt_tol ).

  " zsi2o_brf_con_tolerance has no LGNUM component - get_con_tolerance
  " already scopes the result to iv_lgnum, so the first (and expected
  " only) row is the tolerance row for this warehouse.
  READ TABLE lt_tol INTO ls_tol INDEX 1.
  IF sy-subrc <> 0.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

  IF lv_reason = lc_over.
    lv_tol_pct = ls_tol-zover_pct.
  ELSEIF lv_reason = lc_shrt.
    lv_tol_pct = ls_tol-zundr_pct.
  ENDIF.

*--------------------------------------------------------------------*
* Difference / tolerance validation
*--------------------------------------------------------------------*
  CLEAR: lv_diff_qty, lv_abs_diff, lv_tol_qty.

  lv_diff_qty = lv_actual_qty - lv_plan_qty.

  IF lv_diff_qty = 0.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

  IF lv_reason = lc_over.
    "Error condition: quantity is short-fill but reason is OVER
    IF lv_actual_qty <= lv_plan_qty.
      MESSAGE e054(zmsg_i2o_rf) RAISING error.
    ENDIF.

    lv_abs_diff = lv_actual_qty - lv_plan_qty.

  ELSEIF lv_reason = lc_shrt.
    "Error condition: quantity is over-fill but reason is SHRT
    IF lv_actual_qty >= lv_plan_qty.
      MESSAGE e054(zmsg_i2o_rf) RAISING error.
    ENDIF.

    lv_abs_diff = lv_plan_qty - lv_actual_qty.

  ELSE.
    MESSAGE e052(zmsg_i2o_rf) RAISING error.
  ENDIF.

  IF lv_tol_pct IS INITIAL OR lv_tol_pct <= 0.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

  lv_tol_qty  = lv_plan_qty * lv_tol_pct / 100.
  lv_abs_diff = round( val = lv_abs_diff dec = 3 ).
  lv_tol_qty  = round( val = lv_tol_qty  dec = 3 ).

  IF lv_abs_diff > lv_tol_qty.
    "Error condition: quantity entered exceeds allowed tolerance
    MESSAGE e053(zmsg_i2o_rf) RAISING error.
  ENDIF.

*--------------------------------------------------------------------*
* PI config
*--------------------------------------------------------------------*
  CLEAR lv_pval02.
  SELECT SINGLE pval02
    FROM ztxca_config
    INTO @lv_pval02
   WHERE kdef01 = 'ZFM_I2O_RF'
     AND kdef02 = 'PI_PROCESS_TYPE'
     AND kval01 = @lv_lgnum.

  lv_proc_type = lv_pval02.

  IF lv_proc_type IS INITIAL.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

  CLEAR lv_pval02.
  SELECT SINGLE pval02
    FROM ztxca_config
    INTO @lv_pval02
   WHERE kdef01 = 'ZFM_I2O_RF'
     AND kdef02 = 'PI_DOC_TYPE'
     AND kval01 = @lv_lgnum.

  lv_doc_type = lv_pval02.

  IF lv_doc_type IS INITIAL.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

  CLEAR lv_pval02.
  SELECT SINGLE pval02
    FROM ztxca_config
    INTO @lv_pval02
   WHERE kdef01 = 'ZFM_I2O_RF'
     AND kdef02 = 'PI_AREA'
     AND kval01 = @lv_lgnum.

  lv_pi_area = lv_pval02.

  IF lv_pi_area IS INITIAL.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

  SELECT SINGLE pval02
    FROM ztxca_config
    INTO @lv_pi_reason
   WHERE kdef01 = 'ZFM_I2O_RF'
     AND kdef02 = 'PI_REASON'
     AND kval01 = @lv_lgnum
     AND kval02 = @lv_reason.

  IF sy-subrc <> 0 OR lv_pi_reason IS INITIAL.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

*--------------------------------------------------------------------*
* Get HU
*--------------------------------------------------------------------*
  ASSIGN COMPONENT 'HUIDENT' OF STRUCTURE cs_chg_data TO <lv_src>.
  IF sy-subrc = 0 AND <lv_src> IS NOT INITIAL.
    lv_huident = <lv_src>.
  ENDIF.

  IF lv_huident IS INITIAL.
    ASSIGN COMPONENT 'HUIDENT' OF STRUCTURE is_static_data TO <lv_src>.
    IF sy-subrc = 0 AND <lv_src> IS NOT INITIAL.
      lv_huident = <lv_src>.
    ENDIF.
  ENDIF.

  IF lv_huident IS INITIAL.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

  lv_matnr = is_screen_data-matnr_ean.
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = lv_matnr
    IMPORTING
      output = lv_matnr.

  lv_charg = is_screen_data-batch.

  ls_r_huident-sign   = 'I'.
  ls_r_huident-option = 'EQ'.
  ls_r_huident-low    = lv_huident.
  APPEND ls_r_huident TO lt_r_huident.

  CALL FUNCTION '/SCWM/SELECT_STOCK'
    EXPORTING
      iv_lgnum    = lv_lgnum
      ir_huident  = lt_r_huident
      iv_tolerant = abap_true
    IMPORTING
      et_huitm    = lt_huitm
      et_huhdr    = lt_huhdr
    EXCEPTIONS
      error       = 1
      OTHERS      = 2.

  IF sy-subrc <> 0 OR lt_huitm IS INITIAL.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

*--------------------------------------------------------------------*
* Resolve the order's component material (used both to pick the
* right item on a mixed HU and to run the BOM check below).
*--------------------------------------------------------------------*
  ASSIGN COMPONENT 'MATID' OF STRUCTURE is_static_data TO <lv_src>.
  IF sy-subrc = 0 AND <lv_src> IS NOT INITIAL.
    lv_order_matid = <lv_src>.
  ENDIF.

  " batch-matid is used elsewhere in the existing code
  " (ZFM_I2O_RF_MICOTR_MIQUSL_PAI's /SCWM/MATERIAL_QUAN_CONVERT call),
  " so it is a known-safe static component - unlike mat_global-matid,
  " which was never proven to exist and was dropped after LGNUM turned
  " out to be a guess that didn't compile.
  IF lv_order_matid IS INITIAL AND cs_chg_data-batch-matid IS NOT INITIAL.
    lv_order_matid = cs_chg_data-batch-matid.
  ENDIF.

  UNASSIGN <ls_huitm>.

  " Match the HU item on BOTH material and batch - matching on batch
  " alone (as before) could silently pick a different material's
  " stock item on a mixed HU.
  LOOP AT lt_huitm ASSIGNING <ls_huitm>.
    lv_match = abap_true.

    IF lv_order_matid IS NOT INITIAL.
      ASSIGN COMPONENT 'MATID' OF STRUCTURE <ls_huitm> TO <lv_src>.
      IF sy-subrc = 0 AND <lv_src> IS NOT INITIAL AND <lv_src> <> lv_order_matid.
        lv_match = abap_false.
      ENDIF.
    ENDIF.

    IF lv_match = abap_true AND lv_charg IS NOT INITIAL.
      ASSIGN COMPONENT 'CHARG' OF STRUCTURE <ls_huitm> TO <lv_src>.
      IF sy-subrc = 0 AND <lv_src> IS NOT INITIAL AND <lv_src> <> lv_charg.
        lv_match = abap_false.
      ENDIF.
    ENDIF.

    IF lv_match = abap_true.
      EXIT.
    ENDIF.
  ENDLOOP.

  IF <ls_huitm> IS NOT ASSIGNED.
    " No item on the HU matches the order's component/batch at all -
    " this is the FDS error "Material identified is not included in
    " the BOM of the Process Order" for the case where the scanned HU
    " does not contain the expected component.
    MESSAGE e051(zmsg_i2o_rf) RAISING error.
  ENDIF.

  CLEAR: lv_matid, lv_batchid, lv_guid_stock.

  ASSIGN COMPONENT 'MATID' OF STRUCTURE <ls_huitm> TO <lv_src>.
  IF sy-subrc = 0.
    lv_matid = <lv_src>.
  ENDIF.

  ASSIGN COMPONENT 'BATCHID' OF STRUCTURE <ls_huitm> TO <lv_src>.
  IF sy-subrc = 0.
    lv_batchid = <lv_src>.
  ENDIF.

  ASSIGN COMPONENT 'GUID_STOCK' OF STRUCTURE <ls_huitm> TO <lv_src>.
  IF sy-subrc = 0.
    lv_guid_stock = <lv_src>.
  ENDIF.

  IF lv_matid IS INITIAL.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

*--------------------------------------------------------------------*
* BOM validation - the resolved material must be the component
* bound to this order's reservation
*--------------------------------------------------------------------*
  IF lv_order_matid IS NOT INITIAL AND lv_order_matid <> lv_matid.
    MESSAGE e051(zmsg_i2o_rf) RAISING error.
  ENDIF.

  READ TABLE lt_huhdr ASSIGNING <ls_huhdr> INDEX 1.

*--------------------------------------------------------------------*
* Determine storage bin
*--------------------------------------------------------------------*
  CLEAR lv_lgpla.

  ASSIGN COMPONENT 'LGPLA' OF STRUCTURE <ls_huitm> TO <lv_src>.
  IF sy-subrc = 0 AND <lv_src> IS NOT INITIAL.
    lv_lgpla = <lv_src>.
  ENDIF.

  IF lv_lgpla IS INITIAL AND <ls_huhdr> IS ASSIGNED.
    ASSIGN COMPONENT 'LGPLA' OF STRUCTURE <ls_huhdr> TO <lv_src>.
    IF sy-subrc = 0 AND <lv_src> IS NOT INITIAL.
      lv_lgpla = <lv_src>.
    ENDIF.
  ENDIF.

  IF lv_lgpla IS INITIAL.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

*--------------------------------------------------------------------*
* Determine storage type
*--------------------------------------------------------------------*
  CLEAR lv_lgtyp.

  ASSIGN COMPONENT 'LGTYP' OF STRUCTURE <ls_huitm> TO <lv_src>.
  IF sy-subrc = 0 AND <lv_src> IS NOT INITIAL.
    lv_lgtyp = <lv_src>.
  ENDIF.

  IF lv_lgtyp IS INITIAL.
    SELECT SINGLE lgtyp
      FROM /scwm/lagp
      INTO @lv_lgtyp
     WHERE lgnum = @lv_lgnum
       AND lgpla = @lv_lgpla.
  ENDIF.

  IF lv_lgtyp IS INITIAL.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

  DATA: ls_lagp TYPE /scwm/lagp.

*--------------------------------------------------------------------*
* PI CREATE header
*--------------------------------------------------------------------*
  CLEAR ls_head_create.

  set_comp 'LGNUM'        ls_head_create lv_lgnum.
  set_comp 'PROCESS_TYPE' ls_head_create lv_proc_type.
  set_comp 'DOC_TYPE'     ls_head_create lv_doc_type.
  set_comp 'ACTIVE'       ls_head_create limpi_doc_active.

*--------------------------------------------------------------------*
* PI CREATE item
*--------------------------------------------------------------------*
  CLEAR ls_item_create.

  ASSIGN COMPONENT 'DATA' OF STRUCTURE ls_item_create TO <ls_data>.
  IF sy-subrc <> 0.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

  MOVE-CORRESPONDING <ls_huitm> TO <ls_data>.

  set_comp 'ITEM_NO'      <ls_data> '000001'.
  set_comp 'PROCESS_TYPE' <ls_data> lv_proc_type.
  set_comp 'DOC_TYPE'     <ls_data> lv_doc_type.
  set_comp 'PI_AREA_UI'   <ls_data> lv_pi_area.
  set_comp 'REASON'       <ls_data> lv_pi_reason.
  set_comp 'COUNT_DATE'   <ls_data> sy-datum.
  set_comp 'ACTIVE'       <ls_data> limpi_doc_active.

  ASSIGN COMPONENT 'STOCK_ITEM' OF STRUCTURE <ls_data> TO <ls_stock>.
  IF sy-subrc <> 0.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

  MOVE-CORRESPONDING <ls_huitm> TO <ls_stock>.

  copy_comp 'MATID'         <ls_huitm> 'MATID'         <ls_stock>.
  copy_comp 'BATCHID'       <ls_huitm> 'BATCHID'       <ls_stock>.
  copy_comp 'MATNR'         <ls_huitm> 'MATNR'         <ls_stock>.
  copy_comp 'CHARG'         <ls_huitm> 'CHARG'         <ls_stock>.
  copy_comp 'CAT'           <ls_huitm> 'CAT'           <ls_stock>.
  copy_comp 'OWNER'         <ls_huitm> 'OWNER'         <ls_stock>.
  copy_comp 'OWNER_ROLE'    <ls_huitm> 'OWNER_ROLE'    <ls_stock>.
  copy_comp 'ENTITLED'      <ls_huitm> 'ENTITLED'      <ls_stock>.
  copy_comp 'ENTITLED_ROLE' <ls_huitm> 'ENTITLED_ROLE' <ls_stock>.
  copy_comp 'STOCK_USAGE'   <ls_huitm> 'STOCK_USAGE'   <ls_stock>.
  copy_comp 'STOCK_DOCCAT'  <ls_huitm> 'STOCK_DOCCAT'  <ls_stock>.
  copy_comp 'STOCK_DOCNO'   <ls_huitm> 'STOCK_DOCNO'   <ls_stock>.
  copy_comp 'STOCK_ITMNO'   <ls_huitm> 'STOCK_ITMNO'   <ls_stock>.
  copy_comp 'VFDAT'         <ls_huitm> 'VFDAT'         <ls_stock>.
  copy_comp 'WDATU'         <ls_huitm> 'WDATU'         <ls_stock>.
  copy_comp 'COO'           <ls_huitm> 'COO'           <ls_stock>.

  set_comp 'LGNUM_STOCK'    <ls_stock> lv_lgnum.

*--------------------------------------------------------------------*
* Mandatory HU item
*--------------------------------------------------------------------*
  ASSIGN COMPONENT 'HU_ITEM' OF STRUCTURE <ls_data> TO <ls_hu>.
  IF sy-subrc = 0.
    MOVE-CORRESPONDING <ls_huitm> TO <ls_hu>.
    set_comp 'HUIDENT' <ls_hu> lv_huident.
  ENDIF.

*--------------------------------------------------------------------*
* Mandatory location parent
*--------------------------------------------------------------------*
  ASSIGN COMPONENT 'LOC_PARENT' OF STRUCTURE <ls_data> TO <ls_loc_parent>.
  IF sy-subrc = 0.
    set_comp 'LGNUM' <ls_loc_parent> lv_lgnum.
    set_comp 'LGPLA' <ls_loc_parent> lv_lgpla.
  ENDIF.

*--------------------------------------------------------------------*
* Also fill direct location fields if available
*--------------------------------------------------------------------*
  set_comp 'LOC_PARENT_LGNUM' <ls_data> lv_lgnum.
  set_comp 'LOC_PARENT_LGPLA' <ls_data> lv_lgpla.
  set_comp 'LGNUM'            <ls_data> lv_lgnum.
  set_comp 'LGPLA'            <ls_data> lv_lgpla.
  set_comp 'PI_AREA_UI'       <ls_data> lv_pi_area.

  APPEND ls_item_create TO lt_item_create.

*--------------------------------------------------------------------*
* PI CREATE
*--------------------------------------------------------------------*
  CLEAR: lt_pi_doc, lt_bapiret, lv_severity.

  CALL FUNCTION '/SCWM/PI_CALL_DOCUMENT_CREATE'
    EXPORTING
      is_head       = ls_head_create
      it_item       = lt_item_create
      iv_save_pack  = abap_true
    IMPORTING
      et_pi_doc     = lt_pi_doc
      et_bapiret    = lt_bapiret
      e_rc_severity = lv_severity.

  IF lv_severity CA wmegc_severity_eax.
    READ TABLE lt_bapiret INTO ls_bapiret WITH KEY type = 'E'.
    IF sy-subrc = 0.
      MESSAGE ID ls_bapiret-id TYPE 'E' NUMBER ls_bapiret-number
        WITH ls_bapiret-message_v1 ls_bapiret-message_v2
             ls_bapiret-message_v3 ls_bapiret-message_v4
        RAISING error.
    ENDIF.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

  READ TABLE lt_pi_doc INTO ls_pi_doc INDEX 1.
  IF sy-subrc <> 0.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

*--------------------------------------------------------------------*
* PI COUNT
* NOTE: the commit below is required, not optional bookkeeping - the
* recount follow-up document created by /SCWM/PI_CALL_DOCUMENT_COUNT
* is only visible to /SCWM/PI_CALL_DOCUMENT_READ_SI once the count
* has actually been committed (SAP processes the recount creation in
* the update task). Every step below still raises `error` on failure,
* so a failure here stops the flow before the caller ever posts the
* standard 261 consumption.
*--------------------------------------------------------------------*
  COMMIT WORK AND WAIT.

  GET TIME STAMP FIELD lv_count_ts.

  CLEAR: ls_head_count, ls_item_count, lt_item_count.

  ls_head_count-lgnum        = lv_lgnum.
  ls_head_count-process_type = lv_proc_type.

  ls_item_count-doc_number   = ls_pi_doc-doc_number.
  ls_item_count-doc_year     = ls_pi_doc-doc_year.
  ls_item_count-item_no      = ls_pi_doc-item_no.
  ls_item_count-process_type = lv_proc_type.
  ls_item_count-lgnum        = lv_lgnum.
  ls_item_count-doc_type     = lv_doc_type.
  ls_item_count-count_date   = lv_count_ts.
  ls_item_count-count_user   = sy-uname.
  ls_item_count-reason       = lv_pi_reason.

  CLEAR:
    ls_item_count-ind_item_checked,
    ls_item_count-post_item,
    ls_item_count-t_item_result.

  APPEND INITIAL LINE TO ls_item_count-t_item_result
    ASSIGNING <ls_cnt_res>.

  ASSIGN COMPONENT 'DATA' OF STRUCTURE <ls_cnt_res> TO <ls_res_data>.
  IF sy-subrc <> 0.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

  CLEAR <ls_res_data>.

  set_comp 'DOC_NUMBER'   <ls_res_data> ls_pi_doc-doc_number.
  set_comp 'DOC_YEAR'     <ls_res_data> ls_pi_doc-doc_year.
  set_comp 'ITEM_NO'      <ls_res_data> ls_pi_doc-item_no.
  set_comp 'PROCESS_TYPE' <ls_res_data> lv_proc_type.
  set_comp 'LGNUM'        <ls_res_data> lv_lgnum.
  set_comp 'DOC_TYPE'     <ls_res_data> lv_doc_type.
  set_comp 'PI_AREA_UI'   <ls_res_data> lv_pi_area.
  set_comp 'REASON'       <ls_res_data> lv_pi_reason.
  set_comp 'COUNT_DATE'   <ls_res_data> lv_count_ts.

  set_comp 'LVL'          <ls_res_data> 1.
  set_comp 'LINE_IDX'     <ls_res_data> 1.
  set_comp 'TYPE_PARENT'  <ls_res_data> 'L'.
  set_comp 'TYPE_ITEM'    <ls_res_data> 'S'.

  ASSIGN COMPONENT 'LOC_PARENT' OF STRUCTURE <ls_res_data> TO <ls_loc_parent>.
  IF sy-subrc = 0.
    CLEAR <ls_loc_parent>.
    set_comp 'LGNUM' <ls_loc_parent> lv_lgnum.
    set_comp 'LGTYP' <ls_loc_parent> lv_lgtyp.
    set_comp 'LGPLA' <ls_loc_parent> lv_lgpla.
  ENDIF.

  ASSIGN COMPONENT 'STOCK_ITEM' OF STRUCTURE <ls_res_data> TO <ls_res_stock>.
  IF sy-subrc <> 0.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

  CLEAR <ls_res_stock>.
  MOVE-CORRESPONDING <ls_stock> TO <ls_res_stock>.

  set_comp 'MATID'         <ls_res_stock> lv_matid.
  set_comp 'BATCHID'       <ls_res_stock> lv_batchid.
  set_comp 'MATNR'         <ls_res_stock> lv_matnr.
  set_comp 'CHARG'         <ls_res_stock> lv_charg.
  set_comp 'LGNUM_STOCK'   <ls_res_stock> lv_lgnum.
  copy_comp 'CAT'           <ls_stock> 'CAT'           <ls_res_stock>.
  copy_comp 'OWNER'         <ls_stock> 'OWNER'         <ls_res_stock>.
  copy_comp 'OWNER_ROLE'    <ls_stock> 'OWNER_ROLE'    <ls_res_stock>.
  copy_comp 'ENTITLED'      <ls_stock> 'ENTITLED'      <ls_res_stock>.
  copy_comp 'ENTITLED_ROLE' <ls_stock> 'ENTITLED_ROLE' <ls_res_stock>.
  copy_comp 'STOCK_USAGE'   <ls_stock> 'STOCK_USAGE'   <ls_res_stock>.

  ASSIGN COMPONENT 'HU_ITEM' OF STRUCTURE <ls_res_data> TO <ls_hu>.
  IF sy-subrc = 0.
    CLEAR <ls_hu>.
  ENDIF.

  ASSIGN COMPONENT 'HU_PARENT' OF STRUCTURE <ls_res_data> TO <ls_hu>.
  IF sy-subrc = 0.
    CLEAR <ls_hu>.
  ENDIF.

  ASSIGN COMPONENT 'T_QUAN' OF STRUCTURE <ls_cnt_res> TO <lt_cnt_quan>.
  IF sy-subrc <> 0.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

  CLEAR <lt_cnt_quan>.

  INSERT INITIAL LINE INTO TABLE <lt_cnt_quan> ASSIGNING <ls_cnt_quan>.

  IF sy-subrc <> 0.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

  set_comp 'QAN_STATUS'       <ls_cnt_quan> 'M'.
  set_comp 'ENTERED_QUANTITY' <ls_cnt_quan> lv_actual_qty.
  set_comp 'ENTERED_UNIT'     <ls_cnt_quan> is_screen_data-consumed_uom.

  APPEND ls_item_count TO lt_item_count.

  CLEAR: lt_pi_doc, lt_bapiret, lv_severity.

  CALL FUNCTION '/SCWM/PI_CALL_DOCUMENT_COUNT'
    EXPORTING
      is_head       = ls_head_count
      it_item       = lt_item_count
      i_sim_mode    = space
      iv_save_pack  = space
    IMPORTING
      et_pi_doc     = lt_pi_doc
      et_bapiret    = lt_bapiret
      e_rc_severity = lv_severity.

  IF lv_severity CA wmegc_severity_eax.
    READ TABLE lt_bapiret INTO ls_bapiret WITH KEY type = 'E'.
    IF sy-subrc = 0.
      MESSAGE ID ls_bapiret-id TYPE 'E' NUMBER ls_bapiret-number
        WITH ls_bapiret-message_v1 ls_bapiret-message_v2
             ls_bapiret-message_v3 ls_bapiret-message_v4
        RAISING error.
    ENDIF.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

  COMMIT WORK AND WAIT.

*--------------------------------------------------------------------*
* Find the auto-created new document
*--------------------------------------------------------------------*
  CLEAR: ls_doc_ref_q, lt_item_read_q, lt_item_read_s,
         ls_pi_doc_new, lv_found_new, lt_ref_cand.

  ls_doc_ref_q-doc_number = ls_pi_doc-doc_number.
  ls_doc_ref_q-doc_year   = ls_pi_doc-doc_year.
  ls_doc_ref_q-item_no    = ls_pi_doc-item_no.

  ls_item_read_q-doc_ref = ls_doc_ref_q.
  APPEND ls_item_read_q TO lt_item_read_q.

  CALL FUNCTION '/SCWM/PI_CALL_DOCUMENT_READ_SI'
    EXPORTING
      is_head      = ls_head_count
      it_item      = lt_item_read_q
      iv_it_head_o = 'X'
    IMPORTING
      et_item_read = lt_item_read_s.

  READ TABLE lt_item_read_s ASSIGNING <ls_item_read_s>
    WITH KEY data-doc_number = ls_pi_doc-doc_number
             data-doc_year   = ls_pi_doc-doc_year
             data-item_no    = ls_pi_doc-item_no.

  IF sy-subrc = 0.
    ASSIGN <ls_item_read_s>-t_logitem TO <lt_logitem>.
    IF sy-subrc = 0.
      LOOP AT <lt_logitem> ASSIGNING <ls_logitem_any>.
        ASSIGN COMPONENT 'REF_DOC_ID' OF STRUCTURE <ls_logitem_any> TO <lv_ref_doc_id>.
        CHECK sy-subrc = 0 AND <lv_ref_doc_id> IS NOT INITIAL.

        lv_ref_id = <lv_ref_doc_id>.
        lv_len    = strlen( lv_ref_id ).
        CHECK lv_len >= 16.

        lv_off_docno = lv_len - 16.
        lv_off_item  = lv_len - 6.

        CLEAR ls_ref_cand.
        ls_ref_cand-doc_year   = lv_ref_id+4(4).
        ls_ref_cand-doc_number = lv_ref_id+lv_off_docno(10).
        ls_ref_cand-item_no    = lv_ref_id+lv_off_item(6).

        CHECK ls_ref_cand-doc_number CO '0123456789 '
          AND ls_ref_cand-doc_number IS NOT INITIAL
          AND ls_ref_cand-doc_number <> ls_pi_doc-doc_number.

        APPEND ls_ref_cand TO lt_ref_cand.
      ENDLOOP.
    ENDIF.
  ENDIF.

  SORT lt_ref_cand BY doc_number DESCENDING.
  READ TABLE lt_ref_cand INTO ls_ref_cand INDEX 1.
  IF sy-subrc = 0.
    ls_pi_doc_new-doc_number = ls_ref_cand-doc_number.
    ls_pi_doc_new-doc_year   = ls_ref_cand-doc_year.
    ls_pi_doc_new-item_no    = ls_ref_cand-item_no.
    lv_found_new = abap_true.
  ENDIF.

  IF lv_found_new = abap_true.
    ls_pi_doc = ls_pi_doc_new.

*--------------------------------------------------------------------*
* Count the follow-up document
*--------------------------------------------------------------------*
    ASSIGN COMPONENT 'DATA' OF STRUCTURE ls_item_count-t_item_result[ 1 ]
      TO <ls_res_data>.
    IF sy-subrc = 0.
      set_comp 'DOC_NUMBER' <ls_res_data> ls_pi_doc-doc_number.
      set_comp 'DOC_YEAR'   <ls_res_data> ls_pi_doc-doc_year.
      set_comp 'ITEM_NO'    <ls_res_data> ls_pi_doc-item_no.
    ENDIF.

    ls_item_count-doc_number = ls_pi_doc-doc_number.
    ls_item_count-doc_year   = ls_pi_doc-doc_year.
    ls_item_count-item_no    = ls_pi_doc-item_no.

    lt_item_count[ 1 ] = ls_item_count.

    CLEAR: lt_pi_doc, lt_bapiret, lv_severity.

    CALL FUNCTION '/SCWM/PI_CALL_DOCUMENT_COUNT'
      EXPORTING
        is_head       = ls_head_count
        it_item       = lt_item_count
        i_sim_mode    = space
        iv_save_pack  = space
      IMPORTING
        et_pi_doc     = lt_pi_doc
        et_bapiret    = lt_bapiret
        e_rc_severity = lv_severity.

    IF lv_severity CA wmegc_severity_eax.
      READ TABLE lt_bapiret INTO ls_bapiret WITH KEY type = 'E'.
      IF sy-subrc = 0.
        MESSAGE ID ls_bapiret-id TYPE 'E' NUMBER ls_bapiret-number
          WITH ls_bapiret-message_v1 ls_bapiret-message_v2
               ls_bapiret-message_v3 ls_bapiret-message_v4
          RAISING error.
      ENDIF.
      MESSAGE e057(zmsg_i2o_rf) RAISING error.
    ENDIF.

    COMMIT WORK AND WAIT.
  ENDIF.

*--------------------------------------------------------------------*
* PI POST
*--------------------------------------------------------------------*
  CLEAR: lt_item_post, ls_item_post, lt_pi_doc, lt_bapiret, lv_severity.

  ls_item_post-doc_number = ls_pi_doc-doc_number.
  ls_item_post-doc_year   = ls_pi_doc-doc_year.
  ls_item_post-item_no    = ls_pi_doc-item_no.

  DATA lv_post_ts TYPE /lime/pi_count_date.
  GET TIME STAMP FIELD lv_post_ts.
  ls_item_post-post_date = lv_post_ts.

  APPEND ls_item_post TO lt_item_post.

  CALL FUNCTION '/SCWM/PI_CALL_DOCUMENT_POST'
    EXPORTING
      is_head       = ls_head_count
      it_item       = lt_item_post
      iv_save_pack  = abap_true
    IMPORTING
      et_pi_doc     = lt_pi_doc
      et_bapiret    = lt_bapiret
      e_rc_severity = lv_severity.

  IF lv_severity CA wmegc_severity_eax.
    READ TABLE lt_bapiret INTO ls_bapiret WITH KEY type = 'E'.
    IF sy-subrc = 0.
      MESSAGE ID ls_bapiret-id TYPE 'E' NUMBER ls_bapiret-number
        WITH ls_bapiret-message_v1 ls_bapiret-message_v2
             ls_bapiret-message_v3 ls_bapiret-message_v4
        RAISING error.
    ENDIF.
    MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDIF.

  COMMIT WORK AND WAIT.

  " Diagnostic only: a manual post via /SCWM/DIFF_ANALYZER done a few
  " seconds after this same PI POST step succeeds cleanly, while
  " calling POST() immediately in-line here rejects with
  " /SCWM/GM 014 - testing whether a short delay changes the outcome
  " before pursuing a more invasive fix (e.g. decoupling this call
  " into its own session/LUW).
  WAIT UP TO 2 SECONDS.

*--------------------------------------------------------------------*
* Diff Analyzer - automatically post remaining stock
* differences to reconcile EWM stock with actual consumed qty.
*
* Every branch that used to silently skip (instance not bound, no
* differences found, no posting data prepared, post rejected, or an
* unexpected exception) now raises `error` instead. The caller only
* posts the standard 261 consumption once this has genuinely
* succeeded - otherwise EWM stock and the Process Order consumption
* could end up inconsistent with no trace of why.
*--------------------------------------------------------------------*
  DATA: lo_diff_analyzer     TYPE REF TO /scwm/if_diff_analyzer,
        lt_asp_od_itm        TYPE /scwm/tt_asp_diff_od_itm,
        lt_asp_od_itm_scoped TYPE /scwm/tt_asp_diff_od_itm,
        lt_asp_oi_cum        TYPE /scwm/tt_asp_diff_oi_cum,
        lt_diff_post         TYPE /scwm/tt_diff_post,
        lt_diff_bapiret      TYPE bapirettab,
        ls_diff_bapiret      LIKE LINE OF lt_diff_bapiret,
        lt_matid_diff        TYPE /scwm/tt_matid,
        lv_diff_rejected     TYPE xfeld.

  FIELD-SYMBOLS:
    <ls_od_itm>         TYPE any,
    <lv_od_guid_stock>  TYPE any,
    <lv_od_guid_stock0> TYPE any.

  TRY.
      CALL FUNCTION '/SCWM/DIFF_ANALYZER_GET_INST'
        IMPORTING
          eo_diff_analyzer = lo_diff_analyzer.

      IF lo_diff_analyzer IS NOT BOUND.
        MESSAGE e057(zmsg_i2o_rf) RAISING error.
      ENDIF.

      CLEAR lt_matid_diff.
      APPEND lv_matid TO lt_matid_diff.

      CLEAR: lt_asp_od_itm, lt_asp_oi_cum.

      lo_diff_analyzer->get_differences(
        EXPORTING
          iv_lgnum      = lv_lgnum
          iv_diff_pi    = abap_true
          iv_lock       = abap_false
          it_matid      = lt_matid_diff
        IMPORTING
          et_asp_od_itm = lt_asp_od_itm
          et_asp_oi_cum = lt_asp_oi_cum ).

      IF lt_asp_od_itm IS INITIAL.
        MESSAGE e057(zmsg_i2o_rf) RAISING error.
      ENDIF.

*--------------------------------------------------------------------*
* Scope down to only the differences tied to the exact original quant
* this transaction resolved earlier via /SCWM/SELECT_STOCK
* (lv_guid_stock). GET_DIFFERENCES returns every outstanding PI
* difference for the material across the whole warehouse, and POST()
* rejects the entire batch if even one unrelated item fails (e.g. a
* stuck/unresolved difference left behind on a different HU) - which
* would otherwise block this transaction's own valid difference from
* ever posting.
*
* A single PI count naturally produces a *pair* of od_itm rows
* sharing one GUID_STOCK0 (the original quant): one row *against the
* original quant itself* (GUID_STOCK = GUID_STOCK0) and one *against
* the new quant created by the count* (GUID_STOCK <> GUID_STOCK0).
* Both rows are kept - a manual isolated test confirmed that posting
* only one half of the pair does not reliably avoid the
* /SCWM/GM 014 "no negative quantities" rejection seen during earlier
* testing; posting both together *can* succeed (confirmed via a
* separate manual test in /SCWM/DIFF_ANALYZER done shortly after this
* transaction's PI POST step), which points to a timing/settling
* issue between our PI POST commit and this Diff Analyzer call rather
* than these two rows being genuinely incompatible. See the timing
* note below.
*
* LT_ASP_OI_CUM is left untouched: it aggregates at a coarser level
* shared across all items for this material and does not need to
* mirror this item-level filter.
*--------------------------------------------------------------------*
      IF lv_guid_stock IS NOT INITIAL.
        CLEAR lt_asp_od_itm_scoped.

        LOOP AT lt_asp_od_itm ASSIGNING <ls_od_itm>.
          UNASSIGN <lv_od_guid_stock0>.

          ASSIGN COMPONENT 'GUID_STOCK0' OF STRUCTURE <ls_od_itm> TO <lv_od_guid_stock0>.

          IF <lv_od_guid_stock0> IS ASSIGNED
             AND <lv_od_guid_stock0> = lv_guid_stock.
            APPEND <ls_od_itm> TO lt_asp_od_itm_scoped.
          ENDIF.
        ENDLOOP.

        IF lt_asp_od_itm_scoped IS NOT INITIAL.
          lt_asp_od_itm = lt_asp_od_itm_scoped.
        ENDIF.
      ENDIF.

      IF lt_asp_od_itm IS INITIAL.
        MESSAGE e057(zmsg_i2o_rf) RAISING error.
      ENDIF.

      CLEAR lt_diff_post.

      lo_diff_analyzer->prepare_posting_data(
        EXPORTING
          iv_lgnum      = lv_lgnum
          it_asp_od_itm = lt_asp_od_itm
          it_asp_oi_cum = lt_asp_oi_cum
        IMPORTING
          et_diff_post  = lt_diff_post ).

      IF lt_diff_post IS INITIAL.
        MESSAGE e057(zmsg_i2o_rf) RAISING error.
      ENDIF.

      CLEAR: lt_diff_bapiret, lv_diff_rejected.

      lv_diff_rejected = lo_diff_analyzer->post(
                            EXPORTING
                              it_post    = lt_diff_post
                            IMPORTING
                              et_bapiret = lt_diff_bapiret ).

      IF lv_diff_rejected = abap_true.
        READ TABLE lt_diff_bapiret INTO ls_diff_bapiret WITH KEY type = 'E'.
        IF sy-subrc = 0.
          MESSAGE ID ls_diff_bapiret-id TYPE 'E' NUMBER ls_diff_bapiret-number
            WITH ls_diff_bapiret-message_v1 ls_diff_bapiret-message_v2
                 ls_diff_bapiret-message_v3 ls_diff_bapiret-message_v4
            RAISING error.
        ENDIF.
        MESSAGE e057(zmsg_i2o_rf) RAISING error.
      ENDIF.

      COMMIT WORK AND WAIT.

    CATCH cx_root.
      MESSAGE e057(zmsg_i2o_rf) RAISING error.
  ENDTRY.

*--------------------------------------------------------------------*
* Hand back consumed qty/uom for the caller's 261
*--------------------------------------------------------------------*
  cs_chg_data-consumed_qty = lv_actual_qty.
  cs_chg_data-consumed_uom = is_screen_data-consumed_uom.

ENDFUNCTION.
