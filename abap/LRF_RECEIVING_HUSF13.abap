*----------------------------------------------------------------------*
***INCLUDE /SCWM/LRF_RECEIVING_HUSF13 .
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&      Form  pack_item_to_delivery
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      <--P_LV_QUANTITY  text
*      <--P_LS_ITEMS  text
*      <--P_CS_REHU_HU  text
*----------------------------------------------------------------------*
FORM pack_item_to_delivery USING    iv_lgnum        TYPE /scwm/lgnum
                                    iv_hu_matid     TYPE /scwm/de_matid
                                    iv_procs        TYPE /scwm/de_procs
                                    iv_prr_id       TYPE /scmb/de_prr
                                    is_packing_rule TYPE /scwm/s_upb_pack_rule
                                    is_levels       TYPE /scwm/s_ps_level_int
                                    is_item_packaged TYPE /scwm/s_ps_autopack
                                    it_huhdr_upb TYPE /scwm/if_packing_upb=>yt_huheader_result
                                    it_huitm_ubp TYPE /scwm/if_packing_upb=>yt_huitem_result
                                    it_huauxpmat_upb TYPE /scwm/if_packing_upb=>yt_huauxpmat_result
                                    it_hutree_upb TYPE /scwm/if_packing_upb=>yt_hutree_result
                           CHANGING cs_rehu_prod TYPE /scwm/s_rf_rehu_prod
                                    cs_rehu_hu   TYPE  /scwm/s_rf_rehu_hu
                                    ct_rehu_hu   TYPE  /scwm/tt_rf_rehu_hu
                                    cs_rehu      TYPE  /scwm/s_rf_admin_rehu.

  DATA: lv_lock           TYPE xfeld  ,                     "#EC NEEDED
        lt_return_code    TYPE /scdl/t_sp_return_code,      "#EC NEEDED
        lv_bbdat          TYPE /scwm/de_rf_sp_bbdat,
        lv_timezone       TYPE tznzone,
        lv_batch_crea     TYPE /scwm/dl_batchcrea,
        lv_badi_imp(30)   TYPE  c,
        ev_rejected       TYPE  boole_d,                    "#EC NEEDED
        lv_proccode_added TYPE boolean.


  DATA: ls_docid         TYPE /scwm/s_docid,
        ls_material      TYPE /scwm/s_pack_stock,
        ls_mat_global    TYPE  /scwm/s_material_global,
        ls_quantity      TYPE /scwm/s_quan,
        ls_huitm         TYPE /scwm/s_huitm_int,
        ls_huitm_out     TYPE /scwm/s_huitm_int,            "#EC NEEDED
        ls_huhdr         TYPE /scwm/s_huhdr_int,
        ls_docid_query   TYPE /scwm/dlv_docid_item_str,
        ls_read_options  TYPE /scwm/dlv_query_contr_str,
        ls_inrecords_bbd TYPE /scdl/s_sp_a_item_sapext_prdi,
        ls_message       TYPE /scdl/dm_message_str,
        ls_items         TYPE /scwm/dlv_item_out_prd_str,
        ls_items2        TYPE /scwm/dlv_item_out_prd_str,
        lv_entitled      TYPE /scwm/de_entitled,
        ls_k_item        TYPE  /scdl/s_sp_k_item,
        ls_free          TYPE /scwm/dlv_hu_prd_str,
        ls_changed       TYPE /scwm/s_changed.

  DATA: lt_docid           TYPE /scwm/tt_docid,
        lt_huitm           TYPE /scwm/tt_huitm_int,
        lt_inrecords       TYPE /scdl/t_sp_a_item_product,
        lt_inrecords_bbd   TYPE /scdl/t_sp_a_item_sapext_prdi,
        lt_outrecords_bbd  TYPE /scdl/t_sp_a_item_sapext_prdi, "#EC NEEDED
        lt_outrecords_item TYPE /scdl/t_sp_a_item_product,  "#EC NEEDED
        lt_message         TYPE /scdl/dm_message_tab,
        lt_docid_query     TYPE /scwm/dlv_docid_item_tab,
        lt_docid_tmp       TYPE /scwm/dlv_docid_item_tab,
        lt_items           TYPE /scwm/dlv_item_out_prd_tab,
        lt_k_item          TYPE  /scdl/t_sp_k_item,
        lt_huhdr_changed   TYPE /scwm/tt_changed.

  DATA: lo_pack      TYPE REF TO /scwm/cl_dlv_pack_ibdl,
        lo_dlv       TYPE REF TO /scdl/cl_sp_prd_inb,
        lo_query     TYPE REF TO /scwm/cl_dlv_management_prd,
        lo_badi_crea TYPE REF TO /scwm/ex_dlv_batch_crea,
        lo_message   TYPE REF TO  /scdl/cl_sp_message_box.

  DATA ls_inrecords_qty   TYPE /scdl/s_sp_a_item_quantity.
  DATA lt_inrecords_qty   TYPE /scdl/t_sp_a_item_quantity.
  DATA lt_outrecords_qty  TYPE /scdl/t_sp_a_item_quantity.
  DATA ls_inrecords_prod  TYPE /scdl/s_sp_a_item_product.
  DATA lt_inrecords_prod  TYPE /scdl/t_sp_a_item_product.
  DATA lt_outrecords_prod TYPE /scdl/t_sp_a_item_product.
  DATA ls_action          TYPE /scdl/s_sp_act_action.
  DATA ls_context         TYPE /scdl/s_sp_act_item_split.
  DATA lt_item_key        TYPE /scdl/t_sp_k_item.
  DATA ls_item_key        TYPE /scdl/s_sp_k_item.
  DATA lt_outrecords      TYPE /scdl/t_sp_a_item.
  DATA ls_outrecords      TYPE /scdl/s_sp_a_item.
  DATA lv_new_item_id     TYPE /scdl/dl_itemid.

  " Full qty, first-time attach: don't split into a new BSP subitem,
  " write batch/BBD directly onto the same item that's being packed.
  " Per FDS: "Full qty -> assign batch/BBD/vendor batch directly to
  " original IBD item, no split/subitem." Standard always split
  " unconditionally here regardless of quantity; this flag scopes that
  " down to the actual partial/tolerance-diff cases that genuinely
  " need a separate subitem to coexist with the remaining open item.
  DATA lv_no_split_full_qty TYPE abap_bool.

  DATA lo_batch   TYPE REF TO /scwm/cl_batch_appl.

  DATA lo_bo      TYPE REF TO /scdl/if_bo.
  DATA lo_item    TYPE REF TO /scdl/cl_dl_item_write.
  DATA lo_bom     TYPE REF TO /scdl/cl_bo_management.
  DATA ls_product TYPE        /scdl/dl_product_str.
  DATA ls_sapext  TYPE        /scdl/dl_sap_dr_item_str.

  DATA lv_quantity TYPE /lime/quantity.
  DATA lv_packed_qty TYPE /lime/quantity.
  DATA lv_round_qty  TYPE /scwm/de_quantity.

  DATA ls_item_qty_upd      TYPE /scdl/s_sp_a_item_quantity.
  DATA lt_item_qty_upd      TYPE /scdl/t_sp_a_item_quantity.
  DATA lt_item_qty_upd_out  TYPE /scdl/t_sp_a_item_quantity.
  DATA lv_update            TYPE xfeld.
  DATA ls_items_upd         TYPE /scwm/dlv_item_out_prd_str.
  DATA ls_item_parent       TYPE /scwm/dlv_item_out_prd_str.
  DATA lv_quan              TYPE /scdl/dl_quantity.
  DATA: lv_no_hu     TYPE i,
        ls_hu_create TYPE /scwm/s_huhdr_create_ext,
        lv_huident   TYPE /scwm/huident,
        lt_rehu_hu   TYPE /scwm/tt_rf_rehu_hu.

  DATA lo_ewl_manager      TYPE REF TO /scwm/if_api_lm_ewl_manager.
  DATA ls_addmeas    TYPE /scdl/dl_addmeas_str.
  DATA ls_delterm    TYPE /scdl/dl_delterm_str.
  DATA lv_max_qty    TYPE /scdl/dl_quantity.
  DATA lv_diff_qty   TYPE /scdl/dl_quantity.
  DATA ls_prcode     TYPE /scdl/s_sp_a_item_prcodes.
  DATA lt_prcode     TYPE /scdl/t_sp_a_item_prcodes.
  DATA lt_prc_out    TYPE /scdl/t_sp_a_item_prcodes.
  DATA ls_addmeas_oq        TYPE /scdl/dl_addmeas_str.
  DATA lt_free              TYPE /scwm/dlv_hu_prd_tab.
  DATA lv_quan_conv         TYPE /scwm/de_quantity.
  DATA lv_quan_orig         TYPE /scwm/de_quantity.
  DATA lo_item_pc           TYPE REF TO /scdl/cl_dl_item.
  DATA ls_item_extkey       TYPE /scdl/dl_itmtype_extkey_str.
  DATA lt_item_extkey       TYPE /scdl/dl_itmtype_extkey_tab.
  DATA ls_item_bc           TYPE /scdl/dl_itype_detail_str.
  DATA lt_item_bc           TYPE /scdl/dl_itype_detail_tab.
  DATA lt_profile           TYPE /scdl/t_k_profile.
  DATA ls_profile           TYPE /scdl/s_k_profile.
  DATA lt_prcode_bc         TYPE /scdl/t_prcode.
  DATA ls_prcode_bc         TYPE /scdl/s_prcode.
  DATA lo_saf               TYPE REF TO /scdl/cl_af_management.
  DATA lo_service_bc        TYPE REF TO /scdl/if_af_business_conf.
  DATA lo_service_pc        TYPE REF TO /scdl/if_af_prcode.
  DATA lo_message_pc        TYPE REF TO /scdl/cl_dm_message_extkey.
  DATA lt_message_ext       TYPE /scdl/dm_message_extkey_tab.
  DATA ls_message_ext       TYPE /scdl/dm_message_extkey_str.
  DATA ls_mat_lgnum         TYPE /scwm/s_material_lgnum.
  DATA lv_dbatch_rel        TYPE /scwm/dl_dbatch_rel.
  DATA lv_docu_batch        TYPE xfeld.
  DATA lt_keys_master       TYPE /scdl/t_sp_k_item.
  DATA ls_keys_master       TYPE /scdl/s_sp_k_item.
  DATA lt_item_core         TYPE /scdl/t_sp_a_item.

  DATA: ls_levels           TYPE /scwm/s_ps_level_int,
        ls_packspec_level   TYPE /scwm/s_ps_level_int,
        ls_data             TYPE /scwm/dlv_docid_item_str,
        ls_psp_hdr          TYPE /scwm/s_ps_header_int,
        lt_psp_content      TYPE /scwm/tt_packspec_nested,
        ls_psp_content      TYPE /scwm/s_packspec_nested,
        lt_packspec         TYPE /scwm/tt_guid_ps,
        lt_elementgroup     TYPE /scwm/tt_ps_elementgroup,
        lv_pspec            TYPE /scwm/de_matid,
        ls_packing_rule_upb TYPE /scwm/s_upb_pack_rule,
        ls_levels_upb       TYPE /scwm/s_ps_level_int,
        ls_item_packaged    TYPE /scwm/s_ps_autopack,
        lt_item_packaged    TYPE /scwm/tt_ps_autopack,
        lt_huhdr_upb_result TYPE /scwm/tt_huhdr_int,
        lt_huitm_upb_result TYPE /scwm/tt_huitm_int,
        lt_return_upb       TYPE bapirettab,
        lv_severity_upb     TYPE bapi_mtype,
        lt_huhdr_upb        TYPE /scwm/if_packing_upb=>yt_huheader_result,
        lt_huitm_ubp        TYPE /scwm/if_packing_upb=>yt_huitem_result,
        lt_huauxpmat_upb    TYPE /scwm/if_packing_upb=>yt_huauxpmat_result,
        lt_hutree_upb       TYPE /scwm/if_packing_upb=>yt_hutree_result.

  FIELD-SYMBOLS    <fs_item> TYPE /scwm/dlv_item_out_prd_str.
  FIELD-SYMBOLS    <fs_item_2> TYPE /scwm/dlv_item_out_prd_str.
  FIELD-SYMBOLS    <ls_parameter>   TYPE  any.
  FIELD-SYMBOLS    <fs_hierarchy> TYPE /scdl/dl_hierarchy_str.
  FIELD-SYMBOLS    <ls_free>        TYPE /scwm/dlv_hu_prd_str.

  CONSTANTS:
        wmelc_subitem_no TYPE i VALUE 1.                    "Number of subitems after item split

  DATA: ls_wrk_itms   TYPE /scwm/dlv_item_out_prd_str,
        lo_header_prd TYPE REF TO /scdl/cl_dl_header_prd,
        lt_transport  TYPE        /scdl/dl_transport_tab,
        ls_status     TYPE LINE OF /scdl/dl_status_tab,
        lv_is_allowed TYPE abap_boolean.

* set data for printing
  CALL FUNCTION '/SCWM/RF_PRINT_GLOBAL_DATA'.

  /scwm/cl_api_factory=>get_service( IMPORTING eo_api = lo_ewl_manager ).

  ls_docid_query-docid = cs_rehu_hu-docid.
  ls_docid_query-itemid = cs_rehu_hu-ritmid.
  ls_docid_query-doccat = cs_rehu_hu-rdoccat.
  APPEND ls_docid_query TO lt_docid_query.
  ls_read_options-mix_in_object_instances =  /scwm/if_dl_c=>sc_mix_in_load_instance.

  IF lo_query IS NOT BOUND.
    CREATE OBJECT lo_query.
  ENDIF.

  TRY.
      CALL METHOD lo_query->query
        EXPORTING
          it_docid        = lt_docid_query
          iv_whno         = iv_lgnum
          is_read_options = ls_read_options
        IMPORTING
          et_items        = lt_items.
    CATCH /scdl/cx_delivery .                           "#EC NO_HANDLER
      MESSAGE ID     sy-msgid
              TYPE   sy-msgty
              NUMBER sy-msgno
              WITH   sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDTRY.

  READ TABLE lt_items INTO ls_items INDEX 1.

  lo_bom = /scdl/cl_bo_management=>get_instance( ).
*
  lo_bo = lo_bom->get_bo_by_id( cs_rehu_hu-docid ).

  IF lo_dlv IS NOT BOUND.
    CREATE OBJECT lo_dlv.
  ENDIF.

* in an EWM Inbound Delivery, all items have always the same Entitled
  lv_entitled = ls_items-sapext-entitled.
* BBD rel?
  TRY.
      CALL FUNCTION '/SCWM/MATERIAL_READ_SINGLE'
        EXPORTING
          iv_matid      = cs_rehu_prod-matid
          iv_lgnum      = iv_lgnum
          iv_entitled   = lv_entitled
        IMPORTING
          es_mat_global = ls_mat_global
          es_mat_lgnum  = ls_mat_lgnum.
    CATCH /scwm/cx_md.
      MESSAGE ID     sy-msgid
              TYPE   sy-msgty
              NUMBER sy-msgno
              WITH   sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDTRY.

  cs_rehu_prod-batch_req = ls_mat_global-batch_req.

  IF ls_mat_lgnum-docbatch IS NOT INITIAL.
    TRY.
        CALL METHOD /scwm/cl_dlv_batch=>check_item_dbatch
          EXPORTING
            iv_itemtype   = ls_items-itemtype
            iv_doccat     = ls_items-doccat
          RECEIVING
            rv_dbatch_rel = lv_dbatch_rel.
      CATCH /scwm/cx_dlv_conf.
*    fatal error.
        MESSAGE x049(/scwm/ui_packing).
    ENDTRY.

    IF lv_dbatch_rel IS NOT INITIAL.
      lv_docu_batch = abap_true.
    ENDIF.
  ENDIF.


* check wether the batch is already exist
  IF cs_rehu_prod-batch_req IS NOT INITIAL.
** wrong place move to the begin!!
    DATA ls_batch_md            TYPE  /scwm/dlv_md_prod_batch_det.
    DATA lo_md_access TYPE REF TO /scwm/cl_dlv_md_access.
    DATA lv_batch TYPE /scdl/dl_batchno.
    DATA lv_new_batch TYPE xfeld.

    lv_batch =  cs_rehu_prod-charg.

    lo_md_access = /scwm/cl_dlv_md_access=>get_instance( ).
    TRY.
        ls_batch_md = lo_md_access->get_batch_detail(
          iv_productno         = ls_mat_global-matnr
          iv_batchno           = lv_batch
          iv_lgnum             = iv_lgnum
          iv_entitled          = ls_items-sapext-entitled
          iv_no_classification = abap_false ).
      CATCH /scwm/cx_dlv_batch .
*     batch is not yet existing -> possible to create
        lo_item ?= lo_bo->get_item( cs_rehu_hu-ritmid ).
        ls_sapext = /scwm/cl_dlv_batch_internal=>item_get_sapext( lo_item ).
        ls_product = lo_item->get_product( ).
        GET BADI lo_badi_crea
          FILTERS
            lgnum = iv_lgnum.

        CALL BADI lo_badi_crea->check_batch_create
          EXPORTING
            iv_lgnum      = iv_lgnum
            iv_doccat     = lo_item->mv_doccat
            iv_doc_type   = lo_item->mv_doctype
            iv_itemtype   = lo_item->mv_itemtype
            iv_itemcat    = lo_item->mv_itemcat
            iv_productid  = ls_product-productid
            iv_entitled   = ls_sapext-entitled
            iv_docid      = lo_item->mv_docid
            iv_itemid     = lo_item->mv_itemid
          IMPORTING
            ev_batch_crea = lv_batch_crea.

        IF lv_batch_crea = /scwm/if_dlv_batch_c=>sc_crea_no.
          lv_badi_imp = cl_abap_classdescr=>get_class_name( lo_badi_crea->imp ).
          IF lv_badi_imp CS '/SCWM/CL_EI_DLV_BATCH_DEF'.
*             SAP default implementation, table /SCWM/TDLVBATCH used
*             -> standard message
            MESSAGE e006(/scwm/dlv_batch) WITH lo_item->mv_itemtype lo_item->mv_doctype iv_lgnum.
          ELSE.
*            Customer implementation -> reason why creation id not allowed
*            is unknown -> generic message
            MESSAGE e007(/scwm/dlv_batch).
          ENDIF.
        ENDIF.

        lv_new_batch = 'X'.
        CALL FUNCTION '/SCWM/RF_REHU_CRBA'
          EXPORTING
            cv_matid    = cs_rehu_prod-matid
            cv_matnr    = cs_rehu_prod-matnr
            cv_batch    = cs_rehu_prod-charg
            iv_lgnum    = iv_lgnum
            iv_entitled = ls_items-sapext-entitled
          IMPORTING
            ev_batchid  = cs_rehu_prod-batchid
            eo_batch    = lo_batch.

        IF lo_batch IS NOT BOUND.
          MESSAGE e894(/scwm/rf_en) WITH cs_rehu_prod-charg cs_rehu_prod-matnr.
        ENDIF.
    ENDTRY.
  ENDIF.

* The PDI may be locked and batch creation triggered in the previous try, so after we retry the
* new item creation, the batch in the memory already.
  IF lv_new_batch IS INITIAL AND
     ls_batch_md-new_batch IS NOT INITIAL.
    lv_new_batch = 'X'.
    CALL FUNCTION '/SCWM/RF_REHU_CRBA'
      EXPORTING
        cv_matid    = cs_rehu_prod-matid
        cv_matnr    = cs_rehu_prod-matnr
        cv_batch    = cs_rehu_prod-charg
        iv_lgnum    = iv_lgnum
        iv_entitled = ls_items-sapext-entitled
      IMPORTING
        ev_batchid  = cs_rehu_prod-batchid
        eo_batch    = lo_batch.

    IF lo_batch IS NOT BOUND.
      MESSAGE e894(/scwm/rf_en) WITH cs_rehu_prod-charg cs_rehu_prod-matnr.
    ENDIF.
  ENDIF.

  IF gv_mass_hu_create = abap_true.
    lv_quantity = cs_rehu_hu-nohu * cs_rehu_prod-nista.
  ELSE.
    lv_quantity = cs_rehu_prod-nista.
  ENDIF.

  IF cs_rehu_prod-altme <> ls_items-qty-uom.
    PERFORM convert_quan
      USING
        cs_rehu_prod-matid
        cs_rehu_prod-altme
        ls_items-qty-uom
        cs_rehu_prod-batchid
      CHANGING
        lv_quantity.
  ENDIF.


* creating batch if batch does not exist in the delivery
  IF ( cs_rehu_prod-batchid   IS NOT INITIAL AND
       ls_items-product-batchno IS INITIAL ) OR
     lv_docu_batch = abap_true.

*   lock only the delivery item
    CLEAR lt_k_item.
    ls_k_item-docid = cs_rehu_hu-docid.
    ls_k_item-itemid = cs_rehu_hu-ritmid.
    APPEND ls_k_item TO lt_k_item.

    lo_dlv->lock(
      EXPORTING
        inkeys       = lt_k_item
        lockmode     = /scdl/if_sp1_locking=>sc_exclusive_lock
        aspect       = /scdl/if_sp_c=>sc_asp_item
      IMPORTING
        rejected     = ev_rejected
        return_codes = lt_return_code ).

    PERFORM raise_error_sp USING lo_dlv
                                 ev_rejected
                                 lt_return_code.

    lv_lock = 'X'.

*   we may have to add processcode to increase the main item to make room for the BSP item.
*   let's check it.
    CLEAR ls_docid_query.
    ls_docid_query-docid = cs_rehu_hu-docid.
    ls_docid_query-doccat = cs_rehu_hu-rdoccat.
    APPEND ls_docid_query TO lt_docid_tmp.
    ls_read_options-mix_in_object_instances =  /scwm/if_dl_c=>sc_mix_in_load_no_new_inst.
    ls_read_options-data_retrival_only = 'X'.

    TRY.
        CALL METHOD lo_query->query
          EXPORTING
            it_docid        = lt_docid_tmp
            iv_whno         = iv_lgnum
            is_read_options = ls_read_options
          IMPORTING
            et_items        = lt_items.
      CATCH /scdl/cx_delivery .                         "#EC NO_HANDLER
        MESSAGE ID     sy-msgid
                TYPE   sy-msgty
                NUMBER sy-msgno
                WITH   sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDTRY.

    DELETE lt_items WHERE product-productid <> cs_rehu_prod-matid.

*   calculate the open qty for the batch split.
*   check if the original item is a batch split main item
    READ TABLE ls_items-hierarchy WITH KEY hierarchy_level = '0'
                                 TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
*     if so collect data from the original item
      ls_free-prd_no     = ls_items-docno.
      ls_free-prd_id     = ls_items-docid.
      ls_free-doccat_prd = ls_items-doccat.
      ls_free-item_no    = ls_items-itemno.
      ls_free-item_id    = ls_items-itemid.
      ls_free-open_qty-qty = ls_items-qty-qty.
      ls_free-open_qty-uom = ls_items-qty-uom.

*     and search for already existing batch subitemms
      LOOP AT lt_items ASSIGNING <fs_item_2>
        WHERE product-productid = cs_rehu_prod-matid.

        READ TABLE <fs_item_2>-hierarchy WITH KEY parent_object = ls_items-itemid
                                 TRANSPORTING NO FIELDS.
        IF sy-subrc = 0.
*         reduce the calculated open quantity with the quantity of the subitems
          ls_free-open_qty-qty = ls_free-open_qty-qty - <fs_item_2>-qty-qty.
          lv_packed_qty = lv_packed_qty + <fs_item_2>-qty-qty.
        ENDIF.
      ENDLOOP.
    ENDIF.

*   no split occured yet.
    IF ls_free IS INITIAL.
      ls_free-open_qty-qty = ls_items-qty-qty.
      ls_free-open_qty-uom = ls_items-qty-uom.
    ENDIF.

*   Round Quantity
    lv_round_qty = ls_free-open_qty-qty - lv_quantity.
    IF /qos/cl_qty_aux=>round_qty(  lv_round_qty  ) = 0.
      lv_quantity = ls_free-open_qty-qty.
    ENDIF.

*   The packing qty is larger than open qty, need to validate the tolerance.
    IF lv_quantity > ls_free-open_qty-qty.
      IF ls_items-delterm-tol_overunltd IS NOT INITIAL.
*       unlimited tolerance => receiving should be possible =>
*       calculate the necessary difference
        lv_diff_qty = lv_quantity - ls_free-open_qty-qty.
        lv_max_qty = 9999999999999.
      ELSEIF ls_items-delterm-tol_overpct IS NOT INITIAL.
*       get the original item qty
        READ TABLE ls_items-addmeas INTO ls_addmeas_oq
          WITH KEY qty_role     = /scdl/if_dl_addmeas_c=>sc_qtyrole_oq
                   qty_category = /scdl/if_dl_addmeas_c=>sc_qtycat_request.

        IF ls_addmeas_oq-uom <> ls_free-open_qty-uom.
          TRY.
*           Convert quantity
              MOVE ls_addmeas_oq-qty TO lv_quan.
            CATCH cx_sy_conversion_overflow. "cx_sy_arithmetic_overflow.
              MESSAGE e605(/scwm/rf_en) WITH cs_rehu_prod-nista.
          ENDTRY.

          TRY .
              CALL FUNCTION '/SCWM/MATERIAL_QUAN_CONVERT'
                EXPORTING
                  iv_matid     = cs_rehu_prod-matid
                  iv_quan      = lv_quan
                  iv_unit_from = ls_addmeas_oq-uom
                  iv_unit_to   = ls_free-open_qty-uom
                  iv_batchid   = ls_free-stock-batchid
                IMPORTING
                  ev_quan      = lv_quan_orig.
            CATCH /scwm/cx_md_interface /scwm/cx_md_batch_required
                  /scwm/cx_md_internal_error
                  /scwm/cx_md_batch_not_required
                  /scwm/cx_md_material_exist.
          ENDTRY.
        ELSE.
          lv_quan_orig = ls_addmeas_oq-qty.
        ENDIF.

*       calculate the maximum possible quantity
*       original item qty + tolerance - packed qty
        lv_max_qty = lv_quan_orig +
                     ( lv_quan_orig * ls_items-delterm-tol_overpct / 100 ) -
                     lv_packed_qty.

        IF lv_max_qty GE lv_quantity.
*         item is suitalble for receiving =>
*         calculate the necessary difference
          lv_diff_qty = lv_quantity - ls_free-open_qty-qty.
        ELSE.
*         no further options, look for EGR/PO
          MESSAGE e491(/scwm/rf_en).
        ENDIF.
      ELSE.
*       no tolerance and qty does not fit for the open qty.
        MESSAGE e491(/scwm/rf_en).
      ENDIF.

    ELSE.
      lv_max_qty = ls_items-qty-qty. " it does not matter, we just need to set a larger qty than lv_quantity.
    ENDIF.

*   Full qty, first attach, no pre-existing split: write directly onto
*   the same item instead of creating a new BSP subitem. Per FDS:
*   "Full qty -> assign batch/BBD/vendor batch directly to original
*   IBD item, no split/subitem." This only applies when the item has
*   never been split before (ls_free came from the "no split occured
*   yet" branch, i.e. hierarchy_level '0' lookup failed) and the qty
*   being packed is the item's entire open quantity with no tolerance
*   overage - genuine partial/over-tolerance cases still need their
*   own subitem to coexist with the remaining open item.
    lv_no_split_full_qty = boolc( lv_quantity = ls_free-open_qty-qty
                              AND lv_diff_qty IS INITIAL
                              AND lv_packed_qty IS INITIAL ).

*  IF lv_new_batch IS NOT INITIAL.
*   if the quantity equal to the whole amount from
*   the delivery item tehn no batch split is necessary.
*******************
* -> CHANGE!
*    Let's force the batch split, because otherwise we cannot add new BSP.

*    IF lv_quantity LT lv_max_qty.

    IF cs_rehu_prod-batch_req IS NOT INITIAL OR
       lv_docu_batch = abap_true.

      CLEAR ls_docid_query.
      ls_docid_query-docid = cs_rehu_hu-docid.
      ls_docid_query-doccat = cs_rehu_hu-rdoccat.
      APPEND ls_docid_query TO lt_docid_tmp.
      ls_read_options-mix_in_object_instances =  /scwm/if_dl_c=>sc_mix_in_load_no_new_inst.
      ls_read_options-data_retrival_only = 'X'.

      TRY.
          CALL METHOD lo_query->query
            EXPORTING
              it_docid        = lt_docid_tmp
              iv_whno         = iv_lgnum
              is_read_options = ls_read_options
            IMPORTING
              et_items        = lt_items.
        CATCH /scdl/cx_delivery .                       "#EC NO_HANDLER
          MESSAGE ID     sy-msgid
                  TYPE   sy-msgty
                  NUMBER sy-msgno
                  WITH   sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ENDTRY.

*       search for already batch splitted items
      LOOP AT lt_items INTO ls_items_upd WHERE product-batchno = cs_rehu_prod-charg AND
                 product-productid = cs_rehu_prod-matid AND
                 manual = 'X'.
        READ TABLE ls_items_upd-hierarchy ASSIGNING <fs_hierarchy> WITH KEY hierarchy_type = 'BSP'  parent_object = cs_rehu_hu-ritmid.
        IF sy-subrc = 0.
          lv_update = 'X'.
          EXIT.
        ENDIF.
      ENDLOOP.

    ENDIF.

*******************************************************************************************************************
* The qty increase with a process code is tricky, we need to follow some rules. Especially if the dlv has tolerance
* 1. You cannot add process code to a match main item if the qty has reached
* NEW item
* -> we have qty on main item
*    add proccode to the main item and create new BSP with 0 qty and later you can increase the qty on the BSP item
* -> no open qty on main item
*    create the new BSP item with 0 qty and add process code to the new BSP item
*
* update existing BSP item
* -> we have qty on main item
*    add process code to the main item and later update the qty on the BSP item
* -> no open qty on the main item
*    add process code to the BSP item
*
* The diff qty contains that qty what we have to use for the process code, just pay attention to do the math
* correctly and add the proccode on the right level.
*******************************************************************************************************************


*     new BSP item will be created
    IF lv_update IS INITIAL.

      IF lv_no_split_full_qty = abap_true.
*       -----------------------------------------------------------
*       Full qty, no split: assign batch directly onto the SAME item
*       -----------------------------------------------------------
        lv_new_item_id = cs_rehu_hu-ritmid.

        lo_header_prd ?= lo_bo->get_header( ).
        lt_transport = lo_header_prd->get_transport( ).
        READ TABLE lt_transport TRANSPORTING NO FIELDS
          WITH KEY transpl_type = gc_transpl_type_advsr.
        IF sy-subrc EQ 0 AND lo_header_prd->mv_doccat = /scdl/if_dl_doc_c=>sc_doccat_inb_prd.
          DATA(lt_status_ns) = lo_header_prd->get_status( iv_status_type = /scwm/if_dl_c=>sc_t_transportation ).
          READ TABLE lt_status_ns INTO ls_status INDEX 1.
          IF sy-subrc = 0 AND ls_status-status_value = /scdl/if_dl_c=>sc_v_ready_warehousing.
            lv_is_allowed = abap_true.
          ENDIF.
          IF lv_is_allowed = abap_false.
            MESSAGE ID '/SCWM/DELIVERY' TYPE /scwm/cl_dm_message_no=>sc_msgty_error NUMBER '624'.
          ENDIF.
        ENDIF.

        "--------------------------------------------------------------------------"
        "              PPO segmentation Integration                                "
        "--------------------------------------------------------------------------"
        TRY.
            DATA: lv_warehousezone_ns TYPE tznzone.
            lo_item ?= lo_bo->get_item( lv_new_item_id ).
            IF cs_rehu_prod-bbdat IS NOT INITIAL AND lv_new_batch IS NOT INITIAL AND lo_item->get_refdoc( iv_refdoccat = 'PPO' ) IS NOT INITIAL.

              PERFORM get_warehouse_tzone USING iv_lgnum CHANGING lv_warehousezone_ns.
              CONVERT DATE cs_rehu_prod-bbdat INTO TIME STAMP DATA(lv_bbd_ns) TIME ZONE lv_warehousezone_ns.

              PERFORM upd_item_sapext_property USING lo_item 'TZONEBB' lv_warehousezone_ns.
              PERFORM upd_item_sapext_property USING lo_item 'TSTFRBB' lv_bbd_ns.
              PERFORM upd_item_sapext_property USING lo_item 'TSTTOBB' lv_bbd_ns.
              PERFORM upd_item_sapext_property USING lo_item 'STK_SEG_LONG' cs_rehu_prod-stk_seg.

              TRY.
                  IF lo_batch->mo_valuat_mng IS BOUND.
                    /scwm/cl_dlv_batch_internal=>item_batch_valuate(
                      iv_lgnum = iv_lgnum
                      io_item  = lo_item
                      io_batch = lo_batch ).
                  ENDIF.
                CATCH /scwm/cx_dlv_batch
                      /scwm/cx_dlv_chval.
                  MESSAGE e008(/scwm/batch).
              ENDTRY.

            ENDIF.
          CATCH cx_sy_move_cast_error .
            " ignore this error, which will be raised by next form raise_error_sp
        ENDTRY.
        "--------------------------------------------------------------------------"

*       update batch to delivery - directly on the same item, no split
        ls_inrecords_prod-docid          = ls_items-docid.
        ls_inrecords_prod-itemid         = cs_rehu_hu-ritmid.
        ls_inrecords_prod-productid      = ls_items-product-productid.
        ls_inrecords_prod-productno      = ls_items-product-productno.
        ls_inrecords_prod-productno_ext  = ls_items-product-productno_ext.
        ls_inrecords_prod-batchno        = cs_rehu_prod-charg.
        ls_inrecords_prod-productent     = ls_items-product-productent.
        ls_inrecords_prod-product_text   = ls_items-product-product_text.
        APPEND ls_inrecords_prod TO lt_inrecords_prod.

        CALL METHOD lo_dlv->/scdl/if_sp1_aspect~update
          EXPORTING
            aspect       = /scdl/if_sp_c=>sc_asp_item_product
            inrecords    = lt_inrecords_prod
          IMPORTING
            outrecords   = lt_outrecords_prod
            rejected     = ev_rejected
            return_codes = lt_return_code.

        PERFORM raise_error_sp USING lo_dlv
                                     ev_rejected
                                     lt_return_code.

*       redetermine the single item only - no BSP was created
        CLEAR lt_item_key.
        ls_item_key-docid  = cs_rehu_hu-docid.
        ls_item_key-itemid = cs_rehu_hu-ritmid.
        APPEND ls_item_key TO lt_item_key.

        ls_action-action_code        = /scdl/if_bo_action_c=>sc_validate.
        CLEAR ls_action-action_control.

        lo_dlv->execute(
          EXPORTING
            aspect       = /scdl/if_sp_c=>sc_asp_item
            inkeys       = lt_item_key
            inparam      = ls_action
            action       = /scdl/if_sp_c=>sc_act_execute_action
          IMPORTING
            outrecords   = lt_outrecords
            rejected     = ev_rejected
            return_codes = lt_return_code ).

        PERFORM raise_error_sp USING lo_dlv
                                     ev_rejected
                                     lt_return_code.

        lo_item ?= lo_bo->get_item( cs_rehu_hu-ritmid ).
        ls_product = lo_item->get_product( ).

      ELSE.
*       -----------------------------------------------------------
*       Partial / tolerance-overage qty: original split-into-BSP path
*       -----------------------------------------------------------

*       increase mainitem qty before we update the BSP item
        IF lv_diff_qty IS NOT INITIAL AND ls_free-open_qty-qty IS NOT INITIAL.
          lv_lock = 'X'.
          PERFORM add_proc_code_2_increase_qty USING    lv_diff_qty
                                                        ls_free-open_qty-uom
                                                        ls_items
                                               CHANGING ev_rejected.
          lv_proccode_added = abap_true.
          CLEAR lv_diff_qty.
        ENDIF.

        lo_header_prd ?= lo_bo->get_header( ).
        lt_transport = lo_header_prd->get_transport( ).
        READ TABLE lt_transport TRANSPORTING NO FIELDS
          WITH KEY transpl_type = gc_transpl_type_advsr.
        IF sy-subrc EQ 0 AND lo_header_prd->mv_doccat = /scdl/if_dl_doc_c=>sc_doccat_inb_prd.
          DATA(lt_status) = lo_header_prd->get_status( iv_status_type = /scwm/if_dl_c=>sc_t_transportation ).
          READ TABLE lt_status INTO ls_status INDEX 1.
          IF sy-subrc = 0 AND ls_status-status_value = /scdl/if_dl_c=>sc_v_ready_warehousing.
            lv_is_allowed = abap_true.
          ENDIF.
          IF lv_is_allowed = abap_false.
            MESSAGE ID '/SCWM/DELIVERY' TYPE /scwm/cl_dm_message_no=>sc_msgty_error NUMBER '624'.
          ENDIF.
        ENDIF.

*       item key
        CLEAR lt_item_key.
        ls_item_key-docid  = cs_rehu_hu-docid.
        ls_item_key-itemid = cs_rehu_hu-ritmid.
        APPEND ls_item_key TO lt_item_key.

*       create a new batch subitem
        ls_context-hierarchy_type    = /scdl/if_dl_hierarchy_c=>sc_type_charge.
        ls_context-number_subitems   = wmelc_subitem_no.
        ls_action-action_code        = /scdl/if_bo_action_c=>sc_split_item.

        CREATE DATA ls_action-action_control TYPE ('/SCDL/S_SP_ACT_ITEM_SPLIT').
        ASSIGN ls_action-action_control->* TO <ls_parameter>.
        MOVE-CORRESPONDING ls_context TO <ls_parameter>.

        lo_dlv->execute(
          EXPORTING
            aspect       = /scdl/if_sp_c=>sc_asp_item
            inkeys       = lt_item_key
            inparam      = ls_action
            action       = /scdl/if_sp_c=>sc_act_execute_action
          IMPORTING
            outrecords   = lt_outrecords
            rejected     = ev_rejected
            return_codes = lt_return_code ).

        PERFORM raise_error_sp USING lo_dlv
                                     ev_rejected
                                     lt_return_code.

*       find the new subitem
        DELETE lt_outrecords WHERE itemid = ls_item_key-itemid.
        READ TABLE lt_outrecords INTO ls_outrecords WITH KEY docid = ls_items-docid.
        lv_new_item_id = ls_outrecords-itemid.
        cs_rehu_prod-ritmid = lv_new_item_id.
        cs_rehu_hu-ritmid   = lv_new_item_id.

*       update quantity
        ls_inrecords_qty-docid  = ls_items-docid.
        ls_inrecords_qty-itemid = lv_new_item_id.
*       increase main item qty before we update the BSP item
        IF ls_free-open_qty-qty IS NOT INITIAL OR
           lv_proccode_added IS NOT INITIAL.
          ls_inrecords_qty-qty    = lv_quantity.
        ELSE.
          ls_inrecords_qty-qty    = 0.
        ENDIF.
        ls_inrecords_qty-uom    =  ls_items-qty-uom.
        APPEND ls_inrecords_qty TO lt_inrecords_qty.

        CALL METHOD lo_dlv->/scdl/if_sp1_aspect~update
          EXPORTING
            aspect       = /scdl/if_sp_c=>sc_asp_item_quantity
            inrecords    = lt_inrecords_qty
          IMPORTING
            outrecords   = lt_outrecords_qty
            rejected     = ev_rejected
            return_codes = lt_return_code.

        PERFORM raise_error_sp USING lo_dlv
                                     ev_rejected
                                     lt_return_code.

*       increase subitem qty before we update the BSP item
        IF lv_diff_qty IS NOT INITIAL.
          lv_lock = 'X'.
          ls_items-itemid = lv_new_item_id.
          PERFORM add_proc_code_2_increase_qty USING    lv_diff_qty
                                                        ls_free-open_qty-uom
                                                        ls_items
                                               CHANGING ev_rejected.
        ENDIF.

        "--------------------------------------------------------------------------"
        "              PPO segmentation Integration                                "
        "--------------------------------------------------------------------------"
        " Update the bbd & ss of item for item which refers to Production Order, as the segmentation is validated while update the product
        " the segmentation validataion for PPO relevant ITEM is wrote on method UPD_ITEM_PRODUCT of class /SCDL/CL_SP
        TRY.
            DATA: lv_warehousezone TYPE tznzone.
            lo_item ?= lo_bo->get_item( lv_new_item_id ).
            " only update the property of sapext when the item refers to PPO
            IF cs_rehu_prod-bbdat IS NOT INITIAL AND lv_new_batch IS NOT INITIAL AND lo_item->get_refdoc( iv_refdoccat = 'PPO' ) IS NOT INITIAL.

              PERFORM get_warehouse_tzone USING iv_lgnum CHANGING lv_warehousezone.
              CONVERT DATE cs_rehu_prod-bbdat INTO TIME STAMP DATA(lv_bbd) TIME ZONE lv_warehousezone.

              PERFORM upd_item_sapext_property USING lo_item 'TZONEBB' lv_warehousezone.
              PERFORM upd_item_sapext_property USING lo_item 'TSTFRBB' lv_bbd.
              PERFORM upd_item_sapext_property USING lo_item 'TSTTOBB' lv_bbd.
              PERFORM upd_item_sapext_property USING lo_item 'STK_SEG_LONG' cs_rehu_prod-stk_seg.

              " update BATCH's characteristics here, therefore the next action doesn't raise exception
              TRY.
                  IF lo_batch->mo_valuat_mng IS BOUND.
                    /scwm/cl_dlv_batch_internal=>item_batch_valuate(
                      iv_lgnum = iv_lgnum
                      io_item  = lo_item
                      io_batch = lo_batch ).
                  ENDIF.
                CATCH /scwm/cx_dlv_batch
                      /scwm/cx_dlv_chval.
                  MESSAGE e008(/scwm/batch).
              ENDTRY.

            ENDIF.
          CATCH cx_sy_move_cast_error .
            " ignore this error, which will be raised by next form raise_error_sp
        ENDTRY.
        "--------------------------------------------------------------------------"
        "              PPO segmentation Integration                                "
        "--------------------------------------------------------------------------"

*       update batch to delivery
        ls_inrecords_prod-docid          = ls_items-docid.
        ls_inrecords_prod-itemid         = cs_rehu_hu-ritmid.
        ls_inrecords_prod-productid      = ls_items-product-productid.
        ls_inrecords_prod-productno      = ls_items-product-productno.
        ls_inrecords_prod-productno_ext  = ls_items-product-productno_ext.
        ls_inrecords_prod-batchno        = cs_rehu_prod-charg.
        ls_inrecords_prod-productent     = ls_items-product-productent.
        ls_inrecords_prod-product_text   = ls_items-product-product_text.
        APPEND ls_inrecords_prod TO lt_inrecords_prod.

        CALL METHOD lo_dlv->/scdl/if_sp1_aspect~update
          EXPORTING
            aspect       = /scdl/if_sp_c=>sc_asp_item_product
            inrecords    = lt_inrecords_prod
          IMPORTING
            outrecords   = lt_outrecords_prod
            rejected     = ev_rejected
            return_codes = lt_return_code.

        PERFORM raise_error_sp USING lo_dlv
                                     ev_rejected
                                     lt_return_code.


*       redetermine main item and BSP, to get rid of the blocked status, because there was no BSP yet.
        CLEAR lt_item_key.
        ls_item_key-docid  = ls_items-docid.
        ls_item_key-itemid = ls_items-itemid.
        APPEND ls_item_key TO lt_item_key.

        ls_item_key-docid  = cs_rehu_hu-docid.
        ls_item_key-itemid = cs_rehu_hu-ritmid.
        APPEND ls_item_key TO lt_item_key.

        ls_action-action_code        = /scdl/if_bo_action_c=>sc_validate.
        CLEAR ls_action-action_control.

        lo_dlv->execute(
          EXPORTING
            aspect       = /scdl/if_sp_c=>sc_asp_item
            inkeys       = lt_item_key
            inparam      = ls_action
            action       = /scdl/if_sp_c=>sc_act_execute_action
          IMPORTING
            outrecords   = lt_outrecords
            rejected     = ev_rejected
            return_codes = lt_return_code ).


        PERFORM raise_error_sp USING lo_dlv
                                     ev_rejected
                                     lt_return_code.


        lo_item ?= lo_bo->get_item( lv_new_item_id ).
        ls_product = lo_item->get_product( ).

      ENDIF.

    ELSE.
*       update existing BSP item
      ls_items = ls_items_upd.

      IF lv_diff_qty IS NOT INITIAL.
        ls_items2 = ls_items.
        IF ls_free-open_qty-qty IS NOT INITIAL.
*           increase main item qty before we update the BSP item
          READ TABLE lt_items INTO ls_items2 WITH KEY docid  = ls_free-prd_id
                                                      itemid = ls_free-item_id.
        ENDIF.
        lv_lock = 'X'.
        PERFORM add_proc_code_2_increase_qty USING    lv_diff_qty
                                                      ls_free-open_qty-uom
                                                      ls_items2
                                             CHANGING ev_rejected.
        lv_proccode_added = abap_true.
      ENDIF.

      cs_rehu_prod-ritmid = ls_items-itemid.
      cs_rehu_hu-ritmid   = ls_items-itemid.

      IF ls_free-open_qty-qty IS NOT INITIAL.
        lv_quan = lv_quantity. "it is calculated earlier, must take into accoundt the mulHU!

        CLEAR: ls_item_qty_upd, lt_item_qty_upd.
        ls_item_qty_upd-docid = ls_items-docid.
        ls_item_qty_upd-itemid = ls_items-itemid.
        ls_item_qty_upd-qty = ls_items-qty-qty + lv_quan.
        ls_item_qty_upd-uom = ls_items-qty-uom.
        APPEND ls_item_qty_upd TO lt_item_qty_upd.

        CALL METHOD lo_dlv->/scdl/if_sp1_aspect~update
          EXPORTING
            aspect       = /scdl/if_sp_c=>sc_asp_item_quantity
            inrecords    = lt_item_qty_upd
          IMPORTING
            outrecords   = lt_item_qty_upd_out
            rejected     = ev_rejected
            return_codes = lt_return_code.

        PERFORM raise_error_sp USING lo_dlv
                                     ev_rejected
                                     lt_return_code.
      ENDIF.

      lo_item ?= lo_bo->get_item( ls_items-itemid ).
      ls_product = lo_item->get_product( ).

    ENDIF.

*    ELSE.
*
*      lo_item ?= lo_bo->get_item( cs_rehu_hu-ritmid  ).
*      ls_product = lo_item->get_product( ).
*
*    ENDIF.

    ls_sapext = /scwm/cl_dlv_batch_internal=>item_get_sapext( lo_item ).

* It is required to do the determinations not just with existing batch but for new batches too.
    CLEAR lt_item_key.
    ls_item_key-docid  = cs_rehu_hu-docid.
    ls_item_key-itemid = cs_rehu_hu-ritmid.
    APPEND ls_item_key TO lt_item_key.

    ls_action-action_code        = /scdl/if_bo_action_c=>sc_determine.
    CLEAR ls_action-action_control.

    lo_dlv->execute(
      EXPORTING
        aspect       = /scdl/if_sp_c=>sc_asp_item
        inkeys       = lt_item_key
        inparam      = ls_action
        action       = /scdl/if_sp_c=>sc_act_execute_action
      IMPORTING
        outrecords   = lt_outrecords
        rejected     = ev_rejected
        return_codes = lt_return_code ).

    PERFORM raise_error_sp USING lo_dlv
                                 ev_rejected
                                 lt_return_code.

*   update delivery for BBD if on the screen we added the BBD
    IF cs_rehu_prod-bbdat IS NOT INITIAL AND lv_new_batch IS NOT INITIAL.

      CALL FUNCTION '/SCWM/LGNUM_TZONE_READ'
        EXPORTING
          iv_lgnum        = iv_lgnum
        IMPORTING
          ev_tzone        = lv_timezone
        EXCEPTIONS
          interface_error = 1
          data_not_found  = 2
          OTHERS          = 3.
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ENDIF.

      CONVERT TIME STAMP ls_items-sapext-tsttobb TIME ZONE lv_timezone INTO DATE lv_bbdat.

      IF cs_rehu_prod-bbdat NE ls_batch_md-sled_bbd AND
         ls_batch_md-sled_bbd IS NOT INITIAL.
        cs_rehu_prod-bbdat = ls_batch_md-sled_bbd.
      ENDIF.

      IF cs_rehu_prod-bbdat IS NOT INITIAL  AND
         lv_bbdat IS NOT INITIAL AND
         cs_rehu_prod-bbdat <> lv_bbdat.
        MESSAGE e436(/scwm/rf_en) WITH cs_rehu_prod-bbdat.
      ENDIF.

*     update the batch to the delivery in case of new batch
      IF cs_rehu_prod-batch_req IS NOT INITIAL.

        MOVE-CORRESPONDING ls_items-sapext TO  ls_inrecords_bbd.

        ls_inrecords_bbd-docid   = cs_rehu_hu-docid.
        ls_inrecords_bbd-itemid  = cs_rehu_hu-ritmid.
        CONVERT DATE cs_rehu_prod-bbdat
              INTO TIME STAMP ls_inrecords_bbd-tstfrbb
              TIME ZONE lv_timezone.
        ls_inrecords_bbd-tsttobb = ls_inrecords_bbd-tstfrbb.
        ls_inrecords_bbd-tzonebb = lv_timezone.
        " Stock Segment
        ls_inrecords_bbd-stk_seg_long = cs_rehu_prod-stk_seg.

        APPEND ls_inrecords_bbd TO lt_inrecords_bbd.

*     update the BBD to the delivery item
        CALL METHOD lo_dlv->/scdl/if_sp1_aspect~update
          EXPORTING
            aspect       = /scdl/if_sp_c=>sc_asp_item_sapext_prdi
            inrecords    = lt_inrecords_bbd
          IMPORTING
            outrecords   = lt_outrecords_bbd
            rejected     = ev_rejected
            return_codes = lt_return_code.

        PERFORM raise_error_sp USING lo_dlv
                                     ev_rejected
                                     lt_return_code.
      ENDIF.

    ENDIF.


    IF lv_new_batch IS NOT INITIAL.
*   update the valuation data
      TRY.
          IF lo_batch->mo_valuat_mng IS BOUND.
            /scwm/cl_dlv_batch_internal=>item_batch_valuate(
              iv_lgnum = iv_lgnum
              io_item  = lo_item
              io_batch = lo_batch ).
          ENDIF.
        CATCH /scwm/cx_dlv_batch
              /scwm/cx_dlv_chval.
          MESSAGE e008(/scwm/batch).
      ENDTRY.

*   save the batch
      TRY.
          lo_batch->before_save( ).

        CATCH /scwm/cx_batch_management.
          MESSAGE ID     sy-msgid
                  TYPE   sy-msgty
                  NUMBER sy-msgno
                  WITH   sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.

      ENDTRY.

      /scwm/cl_batch_appl=>save( ).
    ENDIF.

  ELSE.

    IF ls_mat_global-batch_req IS NOT INITIAL.

*   update delivery for BBD if on the screen we added the BBD
      IF cs_rehu_prod-bbdat  IS NOT INITIAL.

        CALL FUNCTION '/SCWM/LGNUM_TZONE_READ'
          EXPORTING
            iv_lgnum        = iv_lgnum
          IMPORTING
            ev_tzone        = lv_timezone
          EXCEPTIONS
            interface_error = 1
            data_not_found  = 2
            OTHERS          = 3.
        IF sy-subrc <> 0.
          MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                  WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
        ENDIF.

        CONVERT TIME STAMP ls_items-sapext-tsttobb TIME ZONE lv_timezone INTO DATE lv_bbdat.

        IF cs_rehu_prod-bbdat IS NOT INITIAL  AND
           lv_bbdat IS NOT INITIAL AND
           cs_rehu_prod-bbdat <> lv_bbdat.
          MESSAGE e436(/scwm/rf_en) WITH cs_rehu_prod-bbdat.
        ENDIF.

*     lock only the delivery item
        CLEAR lt_k_item.
        ls_k_item-docid = cs_rehu_hu-docid.
        ls_k_item-itemid = cs_rehu_hu-ritmid.
        APPEND ls_k_item TO lt_k_item.

        lo_dlv->lock(
          EXPORTING
            inkeys       = lt_k_item
            lockmode     = /scdl/if_sp1_locking=>sc_exclusive_lock
            aspect       = /scdl/if_sp_c=>sc_asp_item
          IMPORTING
            rejected     = ev_rejected
            return_codes = lt_return_code ).

        PERFORM raise_error_sp USING lo_dlv
                                     ev_rejected
                                     lt_return_code.

        lv_lock = 'X'.

        MOVE-CORRESPONDING ls_items-sapext TO  ls_inrecords_bbd.

        ls_inrecords_bbd-docid   = cs_rehu_hu-docid.
        ls_inrecords_bbd-itemid  = cs_rehu_hu-ritmid.
        CONVERT DATE cs_rehu_prod-bbdat
              INTO TIME STAMP ls_inrecords_bbd-tstfrbb
              TIME ZONE lv_timezone.
        ls_inrecords_bbd-tsttobb = ls_inrecords_bbd-tstfrbb.
        APPEND ls_inrecords_bbd TO lt_inrecords_bbd.

*       update the BBD to the delivery item
        CALL METHOD lo_dlv->/scdl/if_sp1_aspect~update
          EXPORTING
            aspect       = /scdl/if_sp_c=>sc_asp_item_sapext_prdi
            inrecords    = lt_inrecords_bbd
          IMPORTING
            outrecords   = lt_outrecords_bbd
            rejected     = ev_rejected
            return_codes = lt_return_code.

        PERFORM raise_error_sp USING lo_dlv
                                     ev_rejected
                                     lt_return_code.
      ENDIF.

    ENDIF.

  ENDIF.

* to receive the quantity we need to increase item quantity
* to do it we need to know the actual open quantity
  IF lo_pack IS NOT BOUND.
    CREATE OBJECT lo_pack.
  ENDIF.
**************************START: Mixed HU*****************************
*******check if it is mixed hu case ( pack product into existing HU instead of create empty HU)
  DATA: ls_huhdr_exist TYPE /scwm/s_huhdr_int.
  CALL METHOD lo_pack->get_hu
    EXPORTING
      iv_huident = cs_rehu_hu-huident
      iv_lock    = abap_true
    IMPORTING
      es_huhdr   = ls_huhdr_exist
    EXCEPTIONS
      not_found  = 1
      OTHERS     = 2.
  IF sy-subrc = 0.
    DATA(lf_hu_exist) = abap_true.
  ENDIF.
**************************END: Mixed HU*******************************
  CLEAR lt_docid_query.
  CLEAR ls_docid_query.
  ls_docid_query-docid = cs_rehu_hu-docid.
  ls_docid_query-itemid = cs_rehu_hu-ritmid.
  ls_docid_query-doccat = cs_rehu_hu-rdoccat.
  APPEND ls_docid_query TO lt_docid_query.

  CALL METHOD lo_pack->init_rf
    EXPORTING
      iv_lgnum  = iv_lgnum
      it_docid  = lt_docid_query
      iv_doccat = wmegc_doccat_pdi.

  CALL METHOD lo_pack->get_free
    IMPORTING
      et_free = lt_free.

* filter for the different material in the delivery
  DELETE lt_free WHERE stock-matid NE cs_rehu_prod-matid.
* filter for the different material in the delivery
  IF ls_mat_global-batch_req IS NOT INITIAL.
    DELETE lt_free WHERE stock-batchid NE cs_rehu_prod-batchid.
  ENDIF.
  READ TABLE lt_free ASSIGNING <ls_free> INDEX 1.

  IF gv_mass_hu_create = abap_true.
    lv_quantity = cs_rehu_hu-nohu * cs_rehu_prod-nista.
  ELSE.
    lv_quantity = cs_rehu_prod-nista.
  ENDIF.

* check if the field symbol is assigned to avoid short dump
* this is an unexpected case and we don't know the root cause yet (not reproducible)
  IF <ls_free> IS NOT ASSIGNED.
    MESSAGE e290(/scwm/rf_en).
  ENDIF.

* UoM conversion if the Delivery UoM <> selected UoM
  IF <ls_free>-open_qty-uom <> cs_rehu_prod-altme.

    TRY .
*     Convert quantity
        MOVE lv_quantity TO lv_quan.
      CATCH cx_sy_conversion_overflow. "cx_sy_arithmetic_overflow.
        MESSAGE e605(/scwm/rf_en) WITH cs_rehu_prod-nista.
    ENDTRY.

    TRY .
        CALL FUNCTION '/SCWM/MATERIAL_QUAN_CONVERT'
          EXPORTING
            iv_matid     = cs_rehu_prod-matid
            iv_quan      = lv_quan
            iv_unit_from = cs_rehu_prod-altme
            iv_unit_to   = <ls_free>-open_qty-uom
            iv_batchid   = <ls_free>-stock-batchid
          IMPORTING
            ev_quan      = lv_quan_conv.
      CATCH /scwm/cx_md_interface /scwm/cx_md_batch_required
            /scwm/cx_md_internal_error
            /scwm/cx_md_batch_not_required
            /scwm/cx_md_material_exist.
    ENDTRY.
  ELSE.
    lv_quan_conv = lv_quantity.
  ENDIF.

  CLEAR lv_diff_qty.

* Round Quantity
  lv_round_qty = <ls_free>-open_qty-qty - lv_quan_conv.
  IF /qos/cl_qty_aux=>round_qty(  lv_round_qty  ) = 0.
    lv_quan_conv = <ls_free>-open_qty-qty.
  ENDIF.

* check if the delivery item has enough quantity alone
  IF <ls_free>-open_qty-qty GE lv_quan_conv.
*   we have enough open quantity, continue the process

  ELSE.
*   check if the delivery item has enough quantity with tolerance
    IF ls_items-delterm-tol_overunltd IS NOT INITIAL.
*     unlimited tolerance => receiving should be possible =>
*     calculate the necessary difference
      lv_diff_qty = lv_quan_conv - <ls_free>-open_qty-qty.

    ELSEIF ls_items-delterm-tol_overpct IS NOT INITIAL.
*     get the original item qty
      READ TABLE ls_items-addmeas INTO ls_addmeas_oq
        WITH KEY qty_role     = /scdl/if_dl_addmeas_c=>sc_qtyrole_oq
                 qty_category = /scdl/if_dl_addmeas_c=>sc_qtycat_request.

      IF ls_addmeas_oq-uom <> <ls_free>-open_qty-uom.
        TRY.
*         Convert quantity
            MOVE ls_addmeas_oq-qty TO lv_quan.
          CATCH cx_sy_conversion_overflow. "cx_sy_arithmetic_overflow.
            MESSAGE e605(/scwm/rf_en) WITH cs_rehu_prod-nista.
        ENDTRY.

        TRY .
            CALL FUNCTION '/SCWM/MATERIAL_QUAN_CONVERT'
              EXPORTING
                iv_matid     = cs_rehu_prod-matid
                iv_quan      = lv_quan
                iv_unit_from = ls_addmeas_oq-uom
                iv_unit_to   = <ls_free>-open_qty-uom
                iv_batchid   = <ls_free>-stock-batchid
              IMPORTING
                ev_quan      = lv_quan_orig.
          CATCH /scwm/cx_md_interface /scwm/cx_md_batch_required
                /scwm/cx_md_internal_error
                /scwm/cx_md_batch_not_required
                /scwm/cx_md_material_exist.
        ENDTRY.
      ELSE.
        lv_quan_orig = ls_addmeas_oq-qty.
      ENDIF.

*     calculate the maximum possible quantity
*     original item qty + tolerance - packed qty
      lv_max_qty = lv_quan_orig +
                   ( lv_quan_orig * ls_items-delterm-tol_overpct / 100 ) -
                   <ls_free>-packed_qty-qty.

      IF lv_max_qty GE lv_quan_conv.
*       item is suitalble for receiving =>
*       calculate the necessary difference
        lv_diff_qty = lv_quan_conv - <ls_free>-open_qty-qty.
      ELSE.
*       no further options, look for EGR/PO
        RETURN.
      ENDIF.
    ENDIF.

*   add process code
    IF lv_diff_qty IS NOT INITIAL.
      lv_lock = 'X'.
      PERFORM add_proc_code_2_increase_qty USING    lv_diff_qty
                                                    <ls_free>-open_qty-uom
                                                    ls_items
                                           CHANGING ev_rejected.
    ENDIF.
  ENDIF.

* if new item was created, inbound delivery must be saved as well
  IF ls_items-objchg = /scdl/if_dl_c=>sc_objchg_create.
    lv_lock = 'X'.
  ENDIF.

* in case of any update in the delivery
  IF lo_dlv IS BOUND AND lv_lock IS NOT INITIAL.

    CLEAR: ev_rejected, lt_return_code.
*   necessary checks before saving
    CALL METHOD lo_dlv->/scdl/if_sp1_transaction~before_save
      IMPORTING
        rejected = ev_rejected.

    PERFORM raise_error_sp USING lo_dlv
                                 ev_rejected
                                 lt_return_code.

*   save the delivery
    CALL METHOD lo_dlv->/scdl/if_sp1_transaction~save
      IMPORTING
        rejected = ev_rejected.

    PERFORM raise_error_sp USING lo_dlv
                                 ev_rejected
                                 lt_return_code.

    COMMIT WORK AND WAIT.

    CALL METHOD /scwm/cl_tm=>cleanup( ).

  ENDIF.

* PACKING
  CALL METHOD /scwm/cl_tm=>cleanup( ).

  IF lo_pack IS NOT BOUND.
    CREATE OBJECT lo_pack.
  ENDIF.

  CLEAR lt_docid_query.
  CLEAR ls_docid_query.
  ls_docid_query-docid = cs_rehu_hu-docid.
  ls_docid_query-itemid = cs_rehu_hu-ritmid.
  ls_docid_query-doccat = cs_rehu_hu-rdoccat.
  APPEND ls_docid_query TO lt_docid_query.

* might happen on concurrent packing there is a lock on the same
* item. So let's try to lock a bit later.
  DO 5 TIMES.
    CALL METHOD lo_pack->init_rf
      EXPORTING
        iv_lgnum        = iv_lgnum
        it_docid        = lt_docid_query
        iv_doccat       = cs_rehu_hu-rdoccat
        iv_lock_dlv     = 'X'
      IMPORTING
        ev_foreign_lock = lv_lock.

*   Check the lock
    IF lv_lock IS INITIAL.
      EXIT.
    ENDIF.

    WAIT UP TO 1 SECONDS.
  ENDDO.

* create multipe hu in mass hu create case
  IF cs_rehu_hu-nohu IS NOT INITIAL.
    lv_no_hu = cs_rehu_hu-nohu.
    CLEAR lv_huident.
  ELSE.
    lv_no_hu = 1.
    lv_huident = cs_rehu_hu-huident.
  ENDIF.


  IF ( is_item_packaged IS NOT INITIAL AND it_huhdr_upb IS NOT INITIAL AND it_huitm_ubp IS NOT INITIAL ).
    ls_item_packaged = is_item_packaged.
    lt_huhdr_upb = it_huhdr_upb.
    lt_huitm_ubp = it_huitm_ubp.
    lt_hutree_upb = it_hutree_upb.
    lt_huauxpmat_upb = it_huauxpmat_upb.
  ELSEIF ( gs_item_packaged IS NOT INITIAL AND gt_huhdr_upb IS NOT INITIAL AND gt_huitm_ubp IS NOT INITIAL ).
    ls_item_packaged = gs_item_packaged.
    lt_huhdr_upb = gt_huhdr_upb.
    lt_huitm_ubp = gt_huitm_ubp.
    lt_hutree_upb = gt_hutree_upb.
    lt_huauxpmat_upb = gt_huauxpmat_upb.
  ENDIF.
*--------------------------------------------------------------------------------------------
* Customer Connect: 280996 - Possibility to create one HU with UPB in RF
* Special logic for creation of a single multi level HU with UPB
  IF gv_multi_hu_upb IS NOT INITIAL AND lt_huhdr_upb IS NOT INITIAL AND lt_huitm_ubp IS NOT INITIAL.

    "Update ItemID again in case a new batch subitem was created.
    "Update BatchID in case a new batch was created
    ls_item_packaged-stock-qitmid = cs_rehu_hu-ritmid.
    ls_item_packaged-stock-batchid = cs_rehu_prod-batchid.
    LOOP AT lt_huitm_ubp ASSIGNING FIELD-SYMBOL(<ls_hutitm_upb>).
      <ls_hutitm_upb>-batchid = cs_rehu_prod-batchid.
      <ls_hutitm_upb>-qitmid = cs_rehu_hu-ritmid.
    ENDLOOP.

    lo_pack->create_hu_pack_stock_upb(
      EXPORTING
        is_item_packaged = ls_item_packaged
        it_huhdr_upb     = lt_huhdr_upb
        it_huitm_ubp     = lt_huitm_ubp
        it_huauxpmat_upb = lt_huauxpmat_upb
        it_hutree_upb    = lt_hutree_upb
        it_huident_top   = VALUE #( ( cs_rehu_hu-huident ) )
     IMPORTING
        et_huhdr         = lt_huhdr_upb_result
        et_huitm         = lt_huitm_upb_result
        et_return        = lt_return_upb
        ev_severity      = lv_severity_upb
    ).
    IF lv_severity_upb CA wmegc_severity_eax.
      LOOP AT lt_return_upb ASSIGNING FIELD-SYMBOL(<ls_return_upb>)
      WHERE type CA wmegc_severity_eax.
        MESSAGE ID     <ls_return_upb>-id
                TYPE   <ls_return_upb>-type
                NUMBER <ls_return_upb>-number
                WITH   <ls_return_upb>-message_v1 <ls_return_upb>-message_v2
                       <ls_return_upb>-message_v3 <ls_return_upb>-message_v4.
        RETURN.
      ENDLOOP.
    ENDIF.

    READ TABLE lt_huhdr_upb_result WITH KEY top = abap_true INTO ls_huhdr.

* Fill Best Before Date
    IF cs_rehu_prod-bbdat IS NOT INITIAL.
      LOOP AT lt_huitm_upb_result INTO ls_huitm.

        ls_huitm-vfdat = cs_rehu_prod-bbdat.

        TRY.
            CALL METHOD lo_pack->/scwm/if_pack_bas~change_huitm
              EXPORTING
                is_huitm = ls_huitm
              IMPORTING
                es_huitm = ls_huitm_out.
          CATCH /scwm/cx_basics .
        ENDTRY.
      ENDLOOP.
    ENDIF.

    cs_rehu_hu-huident = ls_huhdr-huident.
    cs_rehu_hu-guid_hu = ls_huhdr-guid_hu.
    IF cs_rehu_hu-new_packmat IS NOT INITIAL.
      cs_rehu_hu-pmat = cs_rehu_hu-new_packmat.
    ENDIF.
    APPEND cs_rehu_hu TO lt_rehu_hu.

* End Customer Connect: 280996
*--------------------------------------------------------------------------------------------
  ELSE.
********************START: Mixed HU***************************
    "in case HU already exist, (pack into mixed HU case), no need to create HU
    " determine pack spec only when creating new HU
    IF lf_hu_exist = abap_false.
********************END: Mixed HU*****************************
      IF ( is_packing_rule IS NOT INITIAL AND is_levels IS NOT INITIAL ).
        ls_levels_upb = is_levels.
        ls_packing_rule_upb = is_packing_rule.
      ELSEIF ( gs_packing_rule_upb IS NOT INITIAL AND gs_levels_upb IS NOT INITIAL ).
        ls_levels_upb = gs_levels_upb.
        ls_packing_rule_upb = gs_packing_rule_upb.
      ENDIF.
      ls_hu_create-hutyp = cs_rehu_hu-hutyp.

      IF ( ls_levels_upb IS INITIAL AND ls_packing_rule_upb IS INITIAL ).
* Fill packaging specification relevant info in case it is present for material.
        IF gv_pspec IS NOT INITIAL.
          CALL FUNCTION '/SCWM/PS_PACKSPEC_GET'
            EXPORTING
              iv_guid_ps          = gv_pspec
              iv_read_elements    = 'X'
            IMPORTING
              es_packspec_header  = ls_psp_hdr
              et_packspec_content = lt_psp_content
              et_elementgroup     = lt_elementgroup
              es_packspec_level   = ls_packspec_level
            EXCEPTIONS
              error               = 1
              OTHERS              = 2.

          IF sy-subrc <> 0.
            MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                 WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
          ENDIF.

          READ TABLE lt_psp_content INTO ls_psp_content INDEX 1.

          IF sy-subrc <> 0.
            MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                 WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
          ENDIF.

          READ TABLE ls_psp_content-levels INTO ls_levels
            WITH KEY hu_create = abap_true.
          IF sy-subrc IS INITIAL.
            IF ls_levels-hu_create = abap_true.
              ls_hu_create-tare_var = ls_levels-tare_var.
              ls_hu_create-closed_package = ls_levels-closed_package.
              IF ls_levels-flag_weight = abap_true.
                ls_hu_create-unit_gw = ls_levels-unit_gw.
                ls_hu_create-t_weight = ls_levels-t_weight.
                ls_hu_create-unit_tw = ls_levels-unit_tw.
              ENDIF.
              IF ls_levels-flag_vol = abap_true.
                ls_hu_create-unit_gv = ls_levels-unit_gv.
                ls_hu_create-t_volume = ls_levels-t_volume.
                ls_hu_create-unit_tv = ls_levels-unit_tv.
              ENDIF.
              IF ls_levels-flag_dim = abap_true.
                ls_hu_create-length = ls_levels-length.
                ls_hu_create-width = ls_levels-width.
                ls_hu_create-height = ls_levels-height.
                ls_hu_create-unit_lwh = ls_levels-unit_lwh.
                ls_hu_create-max_length = ls_levels-max_length.
                ls_hu_create-max_width = ls_levels-max_width.
                ls_hu_create-max_height = ls_levels-max_height.
                ls_hu_create-unit_max_lwh = ls_levels-unit_max_lwh.
              ENDIF.
              IF ls_levels-flag_capa = abap_true.
                ls_hu_create-t_capa = ls_levels-t_capa.
                ls_hu_create-max_capa = ls_levels-max_capa.
                ls_hu_create-tolc = ls_levels-tolc.
              ENDIF.
            ENDIF.
          ENDIF.
        ENDIF.
      ELSE.
        MOVE-CORRESPONDING ls_levels_upb TO ls_hu_create.
      ENDIF.
    ENDIF.
********START:incident 2380084856****
    IF lf_hu_exist = abap_true.
      lv_no_hu = 1.
    ENDIF.
********END: incident 2380084856*****
    DO lv_no_hu TIMES.
* create empty HU withe the given huident
*****************START: Mixed HU case****************************
      "use existing HU in pack mixed hu case   -> New Scenario
      IF lf_hu_exist = abap_true.
        ls_huhdr = ls_huhdr_exist.
      ELSE.
        "otherwise, create new HU                -> Old Scenario
        CALL METHOD lo_pack->/scwm/if_pack_bas~create_hu
          EXPORTING
            iv_pmat      = iv_hu_matid
            iv_huident   = lv_huident
            is_hu_create = ls_hu_create
          RECEIVING
            es_huhdr     = ls_huhdr
          EXCEPTIONS
            error        = 1
            OTHERS       = 2.

        IF sy-subrc <> 0.
          MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                     WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
        ENDIF.
      ENDIF.
*****************END: Mixed HU case****************************
      ls_material-qdoccat = cs_rehu_hu-rdoccat.
      ls_material-qdocid  = cs_rehu_hu-docid.
      ls_material-qitmid  = cs_rehu_hu-ritmid.
*   Round Quantity
      lv_round_qty = <ls_free>-open_qty-qty - cs_rehu_prod-nista.
      IF /qos/cl_qty_aux=>round_qty(  lv_round_qty  ) = 0.
        ls_quantity-quan = <ls_free>-open_qty-qty.
      ELSE.
        ls_quantity-quan = cs_rehu_prod-nista.
      ENDIF.
      ls_quantity-unit = cs_rehu_prod-altme.

* pack the stock to the empty HU     (after adding Mixed HU case, ls_huhdr-guid_hu could be existing one: line1327)
      CALL METHOD lo_pack->/scwm/if_pack_bas~pack_stock
        EXPORTING
          iv_dest_hu  = ls_huhdr-guid_hu
          is_material = ls_material
          is_quantity = ls_quantity
        EXCEPTIONS
          error       = 1
          OTHERS      = 2.
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                   WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ENDIF.

* update the BBD to the HU
      IF cs_rehu_prod-bbdat IS NOT INITIAL.

        CLEAR lt_huitm.
        CALL METHOD lo_pack->/scwm/if_pack_bas~get_hu_item
          EXPORTING
            iv_guid_hu = ls_huhdr-guid_hu
          IMPORTING
            et_huitm   = lt_huitm
          EXCEPTIONS
            not_found  = 1
            OTHERS     = 2.
        IF sy-subrc <> 0.
          MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                     WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
        ENDIF.

        READ TABLE lt_huitm INTO ls_huitm INDEX 1.
        ls_huitm-vfdat = cs_rehu_prod-bbdat.

        TRY.
            CALL METHOD lo_pack->/scwm/if_pack_bas~change_huitm
              EXPORTING
                is_huitm = ls_huitm
              IMPORTING
                es_huitm = ls_huitm_out.
          CATCH /scwm/cx_basics .                       "#EC NO_HANDLER
            MESSAGE ID     sy-msgid
            TYPE   sy-msgty
            NUMBER sy-msgno
            WITH   sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.

        ENDTRY.

      ENDIF.


      IF ( ls_packing_rule_upb IS NOT INITIAL AND ls_levels_upb IS NOT INITIAL ).

        CASE ls_packing_rule_upb-packing_engine.
          WHEN /scmb/if_pb_profile=>c_pb_engine-ps.

            lt_huhdr_changed = VALUE #( ( fieldname = 'PB_ENGINE'    value_c = ls_packing_rule_upb-packing_engine )
                                        ( fieldname = 'PS_GUID'      value_c = ls_packing_rule_upb-guid_ps )
                                        ( fieldname = 'PS_LEVEL_SEQ' value_c = ls_packing_rule_upb-ps_level_seq ) ).

          WHEN /scmb/if_pb_profile=>c_pb_engine-pi.
            lt_huhdr_changed = VALUE #( ( fieldname = 'PB_ENGINE' value_c = ls_packing_rule_upb-packing_engine )
                                        ( fieldname = 'PI_GUID'   value_c = ls_packing_rule_upb-guid_pi ) ).
          WHEN OTHERS.
            lt_huhdr_changed = VALUE #( ( fieldname = 'PB_ENGINE' value_c = ls_packing_rule_upb-packing_engine ) ).
        ENDCASE.

      ELSEIF gv_pspec IS NOT INITIAL.
        lt_huhdr_changed = VALUE #( ( fieldname = 'PS_GUID' value_c = gv_pspec )
                                    ( fieldname = 'PS_LEVEL_SEQ' value_c = ls_levels-level_seq ) ).
      ENDIF.

      IF lt_huhdr_changed IS NOT INITIAL.
        TRY.
            CALL FUNCTION '/SCWM/HUHDR_ATTR_CHANGE'
              EXPORTING
                iv_guid_hu = ls_huhdr-guid_hu
                it_changed = lt_huhdr_changed.
          CATCH /scwm/cx_basics.
            MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                       WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
        ENDTRY.
      ENDIF.

      cs_rehu_hu-huident = ls_huhdr-huident.
      cs_rehu_hu-guid_hu = ls_huhdr-guid_hu.
      IF cs_rehu_hu-new_packmat IS NOT INITIAL.
        cs_rehu_hu-pmat = cs_rehu_hu-new_packmat.
      ENDIF.
      APPEND cs_rehu_hu TO lt_rehu_hu.
    ENDDO.

  ENDIF.

* set data for printing
  CALL FUNCTION '/SCWM/RF_PRINT_GLOBAL_DATA'.

  CALL METHOD lo_pack->/scwm/if_pack_bas~save
    EXPORTING
      iv_commit = ' '
      iv_wait   = ' '
    EXCEPTIONS
      error     = 1
      OTHERS    = 2.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
               WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.



  "Try to save open EWL
  IF lo_ewl_manager->is_standard_skipped( ) = abap_false AND
     iv_procs IS NOT INITIAL AND
     iv_prr_id IS NOT INITIAL.
    lo_ewl_manager->save( ).
  ENDIF.
  " ------

  COMMIT WORK AND WAIT.

  CALL METHOD /scwm/cl_tm=>cleanup( ).

  "EWL cleanup
  IF lo_ewl_manager->is_standard_skipped( ) = abap_false AND
     iv_procs IS NOT INITIAL AND
     iv_prr_id IS NOT INITIAL.
    lo_ewl_manager->cleanup( ).
  ENDIF.
  "----

  IF gv_mass_hu_create = abap_true.
    " DELETE ct_rehu_hu INDEX 1.
    CLEAR: ct_rehu_hu.
    APPEND LINES OF lt_rehu_hu TO ct_rehu_hu.
  ENDIF.

  IF lv_new_item_id IS NOT INITIAL.
    CLEAR lt_docid_query.
    ls_docid_query-docid  = cs_rehu_hu-docid.
    ls_docid_query-itemid = lv_new_item_id.
    ls_docid_query-doccat = cs_rehu_hu-rdoccat.
    APPEND ls_docid_query TO lt_docid_query.
    ls_read_options-mix_in_object_instances =  /scwm/if_dl_c=>sc_mix_in_load_instance.

    TRY.
        CALL METHOD lo_query->query
          EXPORTING
            it_docid        = lt_docid_query
            iv_whno         = iv_lgnum
            is_read_options = ls_read_options
          IMPORTING
            et_items        = lt_items.
      CATCH /scdl/cx_delivery .                         "#EC NO_HANDLER
        MESSAGE ID     sy-msgid
                TYPE   sy-msgty
                NUMBER sy-msgno
                WITH   sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDTRY.

    READ TABLE lt_items INTO ls_items INDEX 1.
    IF sy-subrc IS INITIAL.
      MOVE-CORRESPONDING ls_items TO ls_wrk_itms.
      INSERT ls_wrk_itms INTO TABLE cs_rehu-itms.
    ENDIF.
  ENDIF.

  CLEAR gv_pspec.

ENDFORM.                    " pack_item_to_delivery

*&---------------------------------------------------------------------*
*&    Form  handle_error_sp
*&---------------------------------------------------------------------*
*     handle_error_sp
*     Filters Relevant Message from Service Provider
*----------------------------------------------------------------------*
*     -->IO_DLV
*     -->IV_REJECT
*     -->IT_RETURN
*     <--CS_MESSAGE
*----------------------------------------------------------------------*
FORM handle_error_sp USING io_dlv          TYPE REF TO /scdl/cl_sp_prd_inb
                           iv_rejected     TYPE boole_d
                           it_return_codes TYPE /scdl/t_sp_return_code
                     CHANGING cs_message   TYPE bapiret2.

  DATA:
    lt_message     TYPE /scdl/dm_message_tab,
    lo_message_box TYPE REF TO /scdl/cl_sp_message_box.

  FIELD-SYMBOLS:
    <ls_message>           TYPE /scdl/dm_message_str.

  CLEAR cs_message.
  IF it_return_codes IS INITIAL AND
     iv_rejected IS INITIAL.
    RETURN.
  ENDIF.

  READ TABLE it_return_codes TRANSPORTING NO FIELDS
    WITH KEY failed = abap_true.
  IF sy-subrc IS INITIAL OR iv_rejected EQ abap_true.

    lo_message_box = io_dlv->get_message_box( ).
    lt_message = lo_message_box->get_messages( ).

    LOOP AT lt_message ASSIGNING <ls_message> WHERE msgty = 'E'.
*     The last error message in the table is the first
*     which has been thrown. This is the root of the
*     problem.
    ENDLOOP.
    IF sy-subrc IS INITIAL.
      cs_message-type       = <ls_message>-msgty.
      cs_message-id         = <ls_message>-msgid.
      cs_message-number     = <ls_message>-msgno.
      cs_message-message_v1 = <ls_message>-msgv1 .
      cs_message-message_v2 = <ls_message>-msgv2 .
      cs_message-message_v3 = <ls_message>-msgv3 .
      cs_message-message_v4 = <ls_message>-msgv4 .
    ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&    Form  handle_error_sp
*&---------------------------------------------------------------------*
*     raise_error_sp
*     Raise Message from Service Provider
*----------------------------------------------------------------------*
*     -->IO_DLV
*     -->IV_REJECT
*     -->IT_RETURN
*----------------------------------------------------------------------*
FORM raise_error_sp USING io_dlv          TYPE REF TO /scdl/cl_sp_prd_inb
                          iv_rejected     TYPE boole_d
                          it_return_codes TYPE /scdl/t_sp_return_code.

  DATA: ls_message        TYPE bapiret2.

  PERFORM handle_error_sp USING io_dlv
                                iv_rejected
                                it_return_codes
                          CHANGING ls_message.

  IF ls_message IS NOT INITIAL.
    IF ls_message-type CA wmegc_severity_ea.
      ROLLBACK WORK.
      CALL METHOD /scwm/cl_tm=>cleanup( ).
    ENDIF.
    MESSAGE ID ls_message-id TYPE ls_message-type NUMBER ls_message-number
            WITH ls_message-message_v1 ls_message-message_v2
                 ls_message-message_v3 ls_message-message_v4.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&    Form  CONVERT_QUAN
*&---------------------------------------------------------------------*
*     Convert the quantity between alternative unit of measure and
*     base unit of measure
*----------------------------------------------------------------------*
*     -->IV_MATID
*     -->IV_UNIT_FROM
*     -->IV_UNIT_TO
*     -->IV_BATCHID
*     <--CV_QUAN
*----------------------------------------------------------------------*
FORM convert_quan
     USING    iv_matid     TYPE /scwm/de_matid
              iv_unit_from TYPE /scwm/de_unit
              iv_unit_to   TYPE /scwm/de_unit
              iv_batchid   TYPE /scwm/de_batchid
     CHANGING cv_quan      TYPE /scwm/de_quantity.

  DATA: lv_quan   TYPE /scwm/de_quantity.

  TRY.
      CALL FUNCTION '/SCWM/MATERIAL_QUAN_CONVERT'
        EXPORTING
          iv_matid     = iv_matid
          iv_quan      = cv_quan
          iv_unit_from = iv_unit_from
          iv_unit_to   = iv_unit_to
          iv_batchid   = iv_batchid
        IMPORTING
          ev_quan      = lv_quan.
    CATCH /scwm/cx_md_interface
          /scwm/cx_md_batch_required
          /scwm/cx_md_internal_error
          /scwm/cx_md_batch_not_required
          /scwm/cx_md_material_exist.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                 WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDTRY.

  MOVE lv_quan TO cv_quan.

ENDFORM.                    " convert_quan


FORM add_proc_code_2_increase_qty USING    iv_diff_qty     TYPE /scdl/dl_quantity
                                           iv_uom          TYPE /scdl/dl_uom
                                           is_item         TYPE /scwm/dlv_item_out_prd_str
                                  CHANGING ev_rejected     TYPE boole_d.

  DATA:
    ls_k_item      TYPE  /scdl/s_sp_k_item,
    ls_item_extkey TYPE /scdl/dl_itmtype_extkey_str,
    ls_item_bc     TYPE /scdl/dl_itype_detail_str,
    ls_profile     TYPE /scdl/s_k_profile,
    ls_prcode_bc   TYPE /scdl/s_prcode,
    ls_prcode      TYPE /scdl/s_sp_a_item_prcodes,
    ls_keys_master TYPE /scdl/s_sp_k_item,
    ls_action      TYPE /scdl/s_sp_act_action,

    lt_item_extkey TYPE /scdl/dl_itmtype_extkey_tab,
    lt_item_bc     TYPE /scdl/dl_itype_detail_tab,
    lt_profile     TYPE /scdl/t_k_profile,
    lt_prcode_bc   TYPE /scdl/t_prcode,
    lt_prcode      TYPE /scdl/t_sp_a_item_prcodes,
    lt_keys_master TYPE /scdl/t_sp_k_item,
    lt_k_item      TYPE /scdl/t_sp_k_item,
    lt_return_code TYPE /scdl/t_sp_return_code,
    lt_item_core   TYPE /scdl/t_sp_a_item,

    lo_bo          TYPE REF TO /scdl/if_bo,
    lo_item        TYPE REF TO /scdl/cl_dl_item_write,
    lo_bom         TYPE REF TO /scdl/cl_bo_management,
    lo_saf         TYPE REF TO /scdl/cl_af_management,
    lo_dlv         TYPE REF TO /scdl/cl_sp_prd_inb,
    lo_service_bc  TYPE REF TO /scdl/if_af_business_conf,
    lo_service_pc  TYPE REF TO /scdl/if_af_prcode,
    lo_item_pc     TYPE REF TO /scdl/cl_dl_item,
    lo_message_pc  TYPE REF TO /scdl/cl_dm_message_extkey.


  FIELD-SYMBOLS: <ls_parameter>       TYPE  any.


* lock only the delivery item
  CLEAR lt_k_item.
  ls_k_item-docid  = is_item-docid.
  ls_k_item-itemid = is_item-itemid.
  APPEND ls_k_item TO lt_k_item.

  CREATE OBJECT lo_dlv.

  lo_dlv->lock(
    EXPORTING
      inkeys       = lt_k_item
      lockmode     = /scdl/if_sp1_locking=>sc_exclusive_lock
      aspect       = /scdl/if_sp_c=>sc_asp_item
    IMPORTING
      rejected     = ev_rejected
      return_codes = lt_return_code ).

  PERFORM raise_error_sp USING lo_dlv
                               ev_rejected
                               lt_return_code.

* get business objects
  lo_bom = /scdl/cl_bo_management=>get_instance( ).
  lo_bo = lo_bom->get_bo_by_id( iv_docid = is_item-docid ).
  lo_item_pc = lo_bo->get_item( iv_itemid = is_item-itemid ).
  lo_saf = /scdl/cl_af_management=>get_instance( ).

  TRY.
      lo_service_bc ?= lo_saf->get_service(
        /scdl/if_af_management_c=>sc_business_conf ).
      lo_service_pc ?= lo_saf->get_service(
        /scdl/if_af_management_c=>sc_prcode ).
    CATCH /scdl/cx_af_management.
      MESSAGE e319(/scwm/rf_en).
  ENDTRY.

  CLEAR: ls_item_extkey.
  ls_item_extkey-category = lo_item_pc->mv_doccat.
  ls_item_extkey-item_type = lo_item_pc->mv_itemtype.
  APPEND ls_item_extkey TO lt_item_extkey.

* Determine process code
  lo_service_bc->get_item_bc_by_type_multi(
    EXPORTING
      it_item_extkey = lt_item_extkey
    IMPORTING
      et_itype       = lt_item_bc
      eo_message     = lo_message_pc ).

  LOOP AT lt_item_bc INTO ls_item_bc.
    ls_profile-profile    = ls_item_bc-prcode_prof.
    ls_profile-profiletyp = ls_item_bc-prcode_prftyp.
    APPEND ls_profile TO lt_profile.
  ENDLOOP.

  lo_service_pc->get_prcode_by_profile(
    EXPORTING
      it_profile = lt_profile
    IMPORTING
      et_prcodes = lt_prcode_bc
      eo_message = lo_message_pc ).

  READ TABLE lt_item_bc INTO ls_item_bc
      WITH KEY  category = lo_item_pc->mv_doccat
               item_type = lo_item_pc->mv_itemtype.
  READ TABLE lt_prcode_bc INTO ls_prcode_bc                 "#EC ENHOK
      WITH KEY prcode_prof  = ls_item_bc-prcode_prof
               default_code = abap_true.

* set up the input record
  ls_prcode-docid  = is_item-docid.
  ls_prcode-itemid = is_item-itemid.
  ls_prcode-prcode = ls_prcode_bc-prcode.
  ls_prcode-qty    = iv_diff_qty.
  ls_prcode-uom    = iv_uom.
  APPEND ls_prcode TO lt_prcode.

  MOVE-CORRESPONDING ls_prcode TO ls_keys_master.
  APPEND ls_keys_master TO lt_keys_master.

  CLEAR ls_action.
  ls_action-action_code = /scwm/if_dl_c=>sc_ac_prcode_add.
  CREATE DATA ls_action-action_control TYPE /scwm/dlv_prcode_add_str.
  ASSIGN ls_action-action_control->* TO <ls_parameter>.
  MOVE-CORRESPONDING ls_prcode TO <ls_parameter>.

* add the process code to the delivery item
  CALL METHOD lo_dlv->/scdl/if_sp1_action~execute
    EXPORTING
      aspect       = /scdl/if_sp_c=>sc_asp_item
      inkeys       = lt_keys_master
      inparam      = ls_action
      action       = /scdl/if_sp_c=>sc_act_execute_action
    IMPORTING
      outrecords   = lt_item_core
      rejected     = ev_rejected
      return_codes = lt_return_code.

  PERFORM raise_error_sp USING lo_dlv
                               ev_rejected
                               lt_return_code.

ENDFORM.

FORM upd_item_sapext_property
                        USING io_item TYPE REF TO /scdl/cl_dl_item_write
                              iv_fieldname TYPE string
                              iv_fieldval TYPE any
                              .
  DATA: lo_item TYPE REF TO /scdl/cl_dl_item_prd.

  TRY.
      lo_item ?= io_item.
      lo_item->/scdl/if_dl_item_prd_readonly~get_sapext(
        IMPORTING
          es_sapext_i = DATA(ls_sapext_i)
      ).

      ASSIGN COMPONENT iv_fieldname OF STRUCTURE ls_sapext_i TO FIELD-SYMBOL(<fs_fieldval>).
      IF sy-subrc = 0 AND <fs_fieldval> IS ASSIGNED AND <fs_fieldval> <> iv_fieldval.
        <fs_fieldval> = iv_fieldval.

        lo_item->set_sapext( is_sapext_i = ls_sapext_i ).
      ENDIF.
    CATCH cx_sy_move_cast_error .

  ENDTRY.

ENDFORM.

FORM get_warehouse_tzone
                    USING iv_warehouse TYPE /scwm/lgnum
                 CHANGING ev_timezone TYPE tznzone.

  CALL FUNCTION '/SCWM/LGNUM_TZONE_READ'
    EXPORTING
      iv_lgnum        = iv_warehouse
    IMPORTING
      ev_tzone        = ev_timezone
    EXCEPTIONS
      interface_error = 1
      data_not_found  = 2
      OTHERS          = 3.
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

ENDFORM.
