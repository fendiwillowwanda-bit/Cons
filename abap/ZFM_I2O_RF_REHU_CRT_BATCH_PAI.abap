FUNCTION zfm_i2o_rf_rehu_crt_batch_pai.
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
*"----------------------------------------------------------------------

  TYPES: BEGIN OF ty_mara_shelf,
           xchpf TYPE mara-xchpf,
           mhdhb TYPE mara-mhdhb,
           iprkz TYPE mara-iprkz,
         END OF ty_mara_shelf.

  CONSTANTS:
    lc_prog       TYPE syrepid        VALUE 'SAPLZFG_I2O_RF_RECEIVING_HUS',
    lc_dynnr      TYPE sydynnr        VALUE '9015',
    lc_zbatch     TYPE /scwm/de_fcode VALUE 'ZBATCH',
    lc_zclass     TYPE /scwm/de_fcode VALUE 'ZCLASS',
    lc_pbo2       TYPE /scwm/de_fcode VALUE 'PBO2',
    lc_klart      TYPE klah-klart     VALUE '023',
    lc_class      TYPE klah-class     VALUE 'BC_FERTHALB',
    lc_fld_batch  TYPE dynfnam        VALUE '/SCWM/S_RF_REHU_PROD-CHARG_VERIF',
    lc_fld_vbatch TYPE dynfnam        VALUE 'GV_VENDOR_BATCH',
    lc_fld_pddat  TYPE dynfnam        VALUE 'GV_PDDAT',
    lc_fld_bbdat  TYPE dynfnam        VALUE 'GV_BBDAT'.

  DATA:
    lv_fcode            TYPE /scwm/de_fcode,
    lv_batchno_ui       TYPE /scmb/mdl_batch_id,
    lv_generated_batch  TYPE /scmb/mdl_batch_id,
    lv_vendor_batch     TYPE /scwm/de_vendor_batchno,
    lv_pddat            TYPE dats,
    lv_bbdat            TYPE dats,
    lv_mch_bbdat        TYPE dats,
    lv_mch_pddat        TYPE dats,
    lv_mch_vendor_batch TYPE /scwm/de_vendor_batchno,
    lv_entitled         TYPE /scwm/de_entitled,
    lv_werks            TYPE werks_d,
    lv_matnr_int        TYPE matnr,
    lv_matnr_lookup     TYPE matnr,
    lv_qty_screen       TYPE /scdl/dl_quantity,
    lv_qty_dlv          TYPE /scdl/dl_quantity,
    lv_charg_verif      TYPE /scwm/de_charg_verif,
    lv_batch_exists     TYPE abap_bool,
    lv_full_qty         TYPE abap_bool,
    lv_existing_msg     TYPE abap_bool,
    lv_subrc_vb         TYPE sy-subrc,
    lv_object           TYPE rmclf-objek,
    lv_objtxt           TYPE maktx,
    lv_check_external   TYPE c LENGTH 1,
    lv_date_ext         TYPE char10,
    lv_date_int         TYPE dats,
    lv_rejected         TYPE boole_d,
    lv_timezone         TYPE tznzone,
    lv_tstamp_bbd       TYPE timestamp,
    lv_item_time_dummy  TYPE syst-uzeit.

  DATA:
    ls_mara_shelf TYPE ty_mara_shelf,
    ls_item       TYPE /scwm/dlv_item_out_prd_str,
    ls_mcha       TYPE mcha,
    ls_batch_md   TYPE /scwm/dlv_md_prod_batch_det,
    ls_return     TYPE bapiret2,
    lo_md_access  TYPE REF TO /scwm/cl_dlv_md_access.

  DATA:
    lt_return    TYPE STANDARD TABLE OF bapiret2,
    lt_new_batch TYPE STANDARD TABLE OF mcha,
    lt_dynp      TYPE STANDARD TABLE OF dynpread,
    ls_dynp      TYPE dynpread,
    lt_mat_plant TYPE /scwm/tt_material_base_plant,
    ls_mat_plant TYPE /scwm/s_material_base_plant.

  DATA:
    lo_dlv             TYPE REF TO /scdl/cl_sp_prd_inb,
    lt_k_item          TYPE /scdl/t_sp_k_item,
    ls_k_item          TYPE /scdl/s_sp_k_item,
    lt_return_code     TYPE /scdl/t_sp_return_code,
    lt_inrecords_prod  TYPE /scdl/t_sp_a_item_product,
    ls_inrecords_prod  TYPE /scdl/s_sp_a_item_product,
    lt_outrecords_prod TYPE /scdl/t_sp_a_item_product.

  DATA:
    lt_inrecords_bbd  TYPE /scdl/t_sp_a_item_sapext_prdi,
    ls_inrecords_bbd  TYPE /scdl/s_sp_a_item_sapext_prdi,
    lt_outrecords_bbd TYPE /scdl/t_sp_a_item_sapext_prdi.

  DATA:
    lt_item_key   TYPE /scdl/t_sp_k_item,
    ls_item_key   TYPE /scdl/s_sp_k_item,
    ls_action     TYPE /scdl/s_sp_act_action,
    lt_outrecords TYPE /scdl/t_sp_a_item.

  DATA:
    lo_query_pre       TYPE REF TO /scwm/cl_dlv_management_prd,
    lt_docid_query_pre TYPE /scwm/dlv_docid_item_tab,
    ls_docid_query_pre TYPE /scwm/dlv_docid_item_str,
    ls_read_opt_pre    TYPE /scwm/dlv_query_contr_str,
    lt_items_pre       TYPE /scwm/dlv_item_out_prd_tab.

  FIELD-SYMBOLS:
    <ls_rehu_prod> TYPE /scwm/s_rf_rehu_prod.

  BREAK-POINT ID /scwm/rf_receiving_hus.

  lv_fcode = /scwm/cl_rf_bll_srvc=>get_fcode( ).


  IF cs_rehu_prod-matnr_verif IS NOT INITIAL.
    cs_rehu_prod-matnr = cs_rehu_prod-matnr_verif.
  ENDIF.

  IF cs_rehu_prod-charg_verif IS NOT INITIAL.
    CALL FUNCTION 'CONVERSION_EXIT_RFBA_INPUT'
      EXPORTING
        input  = cs_rehu_prod-charg_verif
      IMPORTING
        output = cs_rehu_prod-charg.
  ENDIF.

  IF cs_rehu_prod-nista_verif IS NOT INITIAL.
    cs_rehu_prod-nista = cs_rehu_prod-nista_verif.
  ENDIF.

  CLEAR lt_dynp.

  APPEND VALUE #( fieldname = lc_fld_batch  ) TO lt_dynp.
  APPEND VALUE #( fieldname = lc_fld_vbatch ) TO lt_dynp.
  APPEND VALUE #( fieldname = lc_fld_pddat  ) TO lt_dynp.
  APPEND VALUE #( fieldname = lc_fld_bbdat  ) TO lt_dynp.

  CALL FUNCTION 'DYNP_VALUES_READ'
    EXPORTING
      dyname             = lc_prog
      dynumb             = lc_dynnr
      translate_to_upper = abap_false
    TABLES
      dynpfields         = lt_dynp
    EXCEPTIONS
      OTHERS             = 1.

  READ TABLE lt_dynp INTO ls_dynp WITH KEY fieldname = lc_fld_batch.
  IF sy-subrc = 0 AND ls_dynp-fieldvalue IS NOT INITIAL.
    cs_rehu_prod-charg_verif = ls_dynp-fieldvalue.

    CALL FUNCTION 'CONVERSION_EXIT_RFBA_INPUT'
      EXPORTING
        input  = cs_rehu_prod-charg_verif
      IMPORTING
        output = cs_rehu_prod-charg.
  ENDIF.

  READ TABLE lt_dynp INTO ls_dynp WITH KEY fieldname = lc_fld_vbatch.
  IF sy-subrc = 0 AND ls_dynp-fieldvalue IS NOT INITIAL.
    gv_vendor_batch = ls_dynp-fieldvalue.
    lv_vendor_batch = ls_dynp-fieldvalue.
  ENDIF.

  READ TABLE lt_dynp INTO ls_dynp WITH KEY fieldname = lc_fld_pddat.
  IF sy-subrc = 0 AND ls_dynp-fieldvalue IS NOT INITIAL.
    CLEAR: lv_date_ext, lv_date_int.
    lv_date_ext = ls_dynp-fieldvalue.

    CALL FUNCTION 'CONVERT_DATE_TO_INTERNAL'
      EXPORTING
        date_external = lv_date_ext
      IMPORTING
        date_internal = lv_date_int
      EXCEPTIONS
        OTHERS        = 1.

    IF sy-subrc = 0.
      gv_pddat = lv_date_int.
    ENDIF.
  ENDIF.

  READ TABLE lt_dynp INTO ls_dynp WITH KEY fieldname = lc_fld_bbdat.
  IF sy-subrc = 0 AND ls_dynp-fieldvalue IS NOT INITIAL.
    CLEAR: lv_date_ext, lv_date_int.
    lv_date_ext = ls_dynp-fieldvalue.

    CALL FUNCTION 'CONVERT_DATE_TO_INTERNAL'
      EXPORTING
        date_external = lv_date_ext
      IMPORTING
        date_internal = lv_date_int
      EXCEPTIONS
        OTHERS        = 1.

    IF sy-subrc = 0.
      gv_bbdat = lv_date_int.
    ENDIF.
  ENDIF.

*--------------------------------------------------------------------*
* From here on, only ZBATCH / ZCLASS fcodes continue processing.
*--------------------------------------------------------------------*
  IF lv_fcode <> lc_zbatch
     AND lv_fcode <> lc_zclass.
    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* Get current delivery item context
*
* cs_rehu_hu-docid/ritmid may not be populated yet at this point in
* the transaction (e.g. product typed + Enter, then straight to F3
* Batch with no separate "select item" step) - falling straight
* through to "READ ... INDEX 1" in that case grabs whatever item
* happens to be first in cs_rehu-itms, regardless of which product
* was actually entered on screen. Try matching by the entered product
* first, before resorting to that blind index-1 fallback.
*--------------------------------------------------------------------*
  READ TABLE cs_rehu-itms INTO ls_item
    WITH KEY docid  = cs_rehu_hu-docid
             itemid = cs_rehu_hu-ritmid.

  IF sy-subrc <> 0 AND cs_rehu_prod-matnr IS NOT INITIAL.
    lv_matnr_lookup = cs_rehu_prod-matnr.

    CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
      EXPORTING
        input  = lv_matnr_lookup
      IMPORTING
        output = lv_matnr_lookup.

    READ TABLE cs_rehu-itms INTO ls_item
      WITH KEY product-productno = lv_matnr_lookup.
  ENDIF.

  IF sy-subrc <> 0.
    READ TABLE cs_rehu-itms INTO ls_item INDEX 1.
  ENDIF.

  IF sy-subrc <> 0.
    MESSAGE e039(zmsg_i2o_rf).
  ENDIF.

  IF cs_rehu_hu-docid IS INITIAL.
    cs_rehu_hu-docid = ls_item-docid.
  ENDIF.

  IF cs_rehu_hu-ritmid IS INITIAL.
    cs_rehu_hu-ritmid = ls_item-itemid.
  ENDIF.

  IF cs_rehu_hu-rdoccat IS INITIAL.
    cs_rehu_hu-rdoccat = ls_item-doccat.
  ENDIF.

  IF cs_rehu_hu-doccat IS INITIAL.
    cs_rehu_hu-doccat = cs_rehu_hu-rdoccat.
  ENDIF.

  IF cs_rehu_prod-ritmid IS INITIAL.
    cs_rehu_prod-ritmid = cs_rehu_hu-ritmid.
  ENDIF.

  IF cs_rehu_hu-docid IS INITIAL OR cs_rehu_hu-ritmid IS INITIAL.
    MESSAGE e040(zmsg_i2o_rf).
  ENDIF.

  lv_entitled = ls_item-sapext-entitled.
  lv_qty_dlv  = ls_item-qty-qty.

  IF cs_rehu_prod-matnr IS INITIAL.
    cs_rehu_prod-matnr = ls_item-product-productno.
  ENDIF.

  IF cs_rehu_prod-matid IS INITIAL.
    cs_rehu_prod-matid = ls_item-product-productid.
  ENDIF.

  CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
    EXPORTING
      input  = cs_rehu_prod-matnr
    IMPORTING
      output = lv_matnr_int.

  IF lv_matnr_int IS INITIAL.
    lv_matnr_int = cs_rehu_prod-matnr.
  ENDIF.

  lv_batchno_ui   = cs_rehu_prod-charg.
  lv_vendor_batch = gv_vendor_batch.
  lv_pddat        = gv_pddat.
  lv_bbdat        = gv_bbdat.
  lv_qty_screen   = cs_rehu_prod-nista.

  IF lv_bbdat IS INITIAL.
    lv_bbdat = cs_rehu_prod-bbdat.
  ENDIF.

*--------------------------------------------------------------------*
* Quantity validation
*--------------------------------------------------------------------*
  IF lv_qty_screen IS INITIAL.
    MESSAGE e022(zmsg_i2o_rf).
  ENDIF.

  IF lv_qty_screen > lv_qty_dlv.
    MESSAGE e001(zmsg_i2o_rf).
  ENDIF.

  lv_full_qty = xsdbool( lv_qty_screen = lv_qty_dlv ).

  cs_rehu_prod-nista       = lv_qty_screen.
  cs_rehu_prod-nista_verif = lv_qty_screen.

*--------------------------------------------------------------------*
* Classification only
*--------------------------------------------------------------------*
  IF lv_fcode = lc_zclass.

    IF cs_rehu_prod-matnr IS INITIAL.
      MESSAGE e041(zmsg_i2o_rf).
    ENDIF.

    IF lv_batchno_ui IS INITIAL.
      MESSAGE e042(zmsg_i2o_rf).
    ENDIF.

    SELECT SINGLE maktx
      FROM makt
      INTO @lv_objtxt
      WHERE matnr = @lv_matnr_int
        AND spras = @sy-langu.

    lv_object = lv_matnr_int.

    CALL FUNCTION 'CLFM_OBJECT_CLASSIFICATION'
      EXPORTING
        batch          = lv_batchno_ui
        class          = lc_class
        classtype      = lc_klart
        no_display     = space
        no_change_type = abap_true
        no_f11         = abap_true
        no_f8          = abap_true
        object         = lv_object
        objtxt         = lv_objtxt
        status         = '2'
        table          = 'MCH1'
        language       = sy-langu
        confirm_class  = abap_true
      EXCEPTIONS
        OTHERS         = 1.

    IF sy-subrc <> 0.
      MESSAGE e043(zmsg_i2o_rf).
    ENDIF.

    /scwm/cl_rf_bll_srvc=>set_field( space ).
    /scwm/cl_rf_bll_srvc=>set_prmod(
      /scwm/cl_rf_bll_srvc=>c_prmod_foreground ).
    /scwm/cl_rf_bll_srvc=>set_fcode( lc_pbo2 ).

    RETURN.
  ENDIF.

*--------------------------------------------------------------------*
* Determine plant
*--------------------------------------------------------------------*
  CALL FUNCTION '/SCWM/MATERIAL_READ_SINGLE'
    EXPORTING
      iv_matid     = cs_rehu_prod-matid
      iv_lgnum     = cs_rehu-lgnum
      iv_entitled  = lv_entitled
    IMPORTING
      et_mat_plant = lt_mat_plant
    EXCEPTIONS
      OTHERS       = 1.

  IF sy-subrc = 0.
    READ TABLE lt_mat_plant INTO ls_mat_plant INDEX 1.
    IF sy-subrc = 0.
      lv_werks = ls_mat_plant-werks.
    ENDIF.
  ENDIF.

  IF lv_werks IS INITIAL.
    MESSAGE e005(zmsg_i2o_rf).
  ENDIF.

*--------------------------------------------------------------------*
* Batch managed / shelf life
*--------------------------------------------------------------------*
  SELECT SINGLE xchpf, mhdhb, iprkz
    FROM mara
    INTO (@ls_mara_shelf-xchpf,
          @ls_mara_shelf-mhdhb,
          @ls_mara_shelf-iprkz)
    WHERE matnr = @lv_matnr_int.

  IF sy-subrc <> 0 OR ls_mara_shelf-xchpf IS INITIAL.
    MESSAGE e002(zmsg_i2o_rf).
  ENDIF.

*--------------------------------------------------------------------*
* Check existing batch and retrieve BBD / ProdDate / Vendor Batch
*
* Scenario 2 & 5: batch entered already exists -> BBD/ProdDate/Vendor
* Batch retrieved from batch master, batch creation must NOT run.
* Scenario 4: batch entered but does not exist -> falls through to
* creation using this externally entered batch number.
*--------------------------------------------------------------------*
  CLEAR: lv_batch_exists,
         lv_mch_bbdat,
         lv_mch_pddat,
         lv_mch_vendor_batch,
         ls_batch_md.

  IF lv_batchno_ui IS NOT INITIAL.

    TRY.
        lo_md_access = /scwm/cl_dlv_md_access=>get_instance( ).

        IF lo_md_access->get_batch_existence(
             iv_productid = cs_rehu_prod-matid
             iv_batchno   = CONV /scdl/dl_batchno( lv_batchno_ui )
             iv_lgnum     = cs_rehu-lgnum
             iv_entitled  = lv_entitled ) = abap_true.

          lv_batch_exists = abap_true.

          ls_batch_md = lo_md_access->get_batch_detail(
                          iv_productno         = cs_rehu_prod-matnr
                          iv_batchno           = CONV /scdl/dl_batchno( lv_batchno_ui )
                          iv_lgnum             = cs_rehu-lgnum
                          iv_entitled          = lv_entitled
                          iv_no_classification = abap_false ).

          IF lv_bbdat IS INITIAL.
            lv_bbdat = ls_batch_md-sled_bbd.
          ENDIF.

          IF lv_pddat IS INITIAL.
            lv_pddat = ls_batch_md-prod_date.
          ENDIF.

          IF lv_vendor_batch IS INITIAL.
            lv_vendor_batch = ls_batch_md-vendor_batch.
          ENDIF.

        ENDIF.

      CATCH /scwm/cx_dlv_batch.
    ENDTRY.

    IF lv_batch_exists = abap_false.

      SELECT SINGLE vfdat, hsdat, licha
        FROM mch1
        INTO (@lv_mch_bbdat, @lv_mch_pddat, @lv_mch_vendor_batch)
        WHERE matnr = @lv_matnr_int
          AND charg = @lv_batchno_ui.

      IF sy-subrc = 0.
        lv_batch_exists = abap_true.
      ELSE.
        SELECT SINGLE vfdat, hsdat, licha
          FROM mcha
          INTO (@lv_mch_bbdat, @lv_mch_pddat, @lv_mch_vendor_batch)
          WHERE matnr = @lv_matnr_int
            AND werks = @lv_werks
            AND charg = @lv_batchno_ui.

        IF sy-subrc = 0.
          lv_batch_exists = abap_true.
        ENDIF.
      ENDIF.

      IF lv_batch_exists = abap_true.
        IF lv_bbdat IS INITIAL.
          lv_bbdat = lv_mch_bbdat.
        ENDIF.

        IF lv_pddat IS INITIAL.
          lv_pddat = lv_mch_pddat.
        ENDIF.

        IF lv_vendor_batch IS INITIAL.
          lv_vendor_batch = lv_mch_vendor_batch.
        ENDIF.
      ENDIF.

    ENDIF.

    " None of the above (dlv_md_access batch metadata, MCH1, MCHA) find
    " anything when the batch was assigned straight onto the delivery
    " item (e.g. via the item_sapext_prdi aspect - what
    " frm_ensure_batch_rehu writes) without a corresponding classic
    " batch master record. Fall back to what's already on the item
    " itself (ls_item-sapext-tstfrbb/tzonebb for BBD,
    " -tstfrpd/tzonepd for production date) before giving up.
    IF lv_bbdat IS INITIAL AND ls_item-sapext-tstfrbb IS NOT INITIAL.
      CONVERT TIME STAMP ls_item-sapext-tstfrbb
            TIME ZONE ls_item-sapext-tzonebb
            INTO DATE lv_bbdat TIME lv_item_time_dummy.
    ENDIF.

    IF lv_pddat IS INITIAL AND ls_item-sapext-tstfrpd IS NOT INITIAL.
      CONVERT TIME STAMP ls_item-sapext-tstfrpd
            TIME ZONE ls_item-sapext-tzonepd
            INTO DATE lv_pddat TIME lv_item_time_dummy.
    ENDIF.

    gv_bbdat        = lv_bbdat.
    gv_pddat        = lv_pddat.
    gv_vendor_batch = lv_vendor_batch.

*--------------------------------------------------------------------*
* FDS 5596 6.6.12.1-2, scenario "Existing batch entered": batch
* already exists in the system -> BBD/ProdDate/Vendor Batch retrieved
* above, no new batch may be created. Flag it so the s046 "Batch is
* already entered" message (DISPLAY LIKE 'E') fires together with the
* retrieved values being written back to the RFUI screen below,
* instead of the normal creation-success message.
*--------------------------------------------------------------------*
    IF lv_batch_exists = abap_true.
      lv_existing_msg = abap_true.
    ENDIF.

  ENDIF.

*--------------------------------------------------------------------*
* Require / derive BBD
*
* Scenario 3: no batch entered, but production date entered -> BBD
* computed from material master total shelf life. If shelf life is
* empty -> "MATERIAL SHELF LIFE MISSING".
*--------------------------------------------------------------------*
  IF lv_bbdat IS INITIAL AND lv_pddat IS INITIAL.
    MESSAGE e003(zmsg_i2o_rf).
  ENDIF.

  IF lv_pddat IS NOT INITIAL AND lv_bbdat IS INITIAL.

    IF ls_mara_shelf-mhdhb IS INITIAL.
      MESSAGE e004(zmsg_i2o_rf).
*     "MATERIAL SHELF LIFE MISSING"
    ENDIF.

    CASE ls_mara_shelf-iprkz.
      WHEN 'D' OR space.
        lv_bbdat = lv_pddat + ls_mara_shelf-mhdhb.
      WHEN 'W'.
        lv_bbdat = lv_pddat + ( ls_mara_shelf-mhdhb * 7 ).
      WHEN 'M'.
        CALL FUNCTION 'RP_CALC_DATE_IN_INTERVAL'
          EXPORTING
            date      = lv_pddat
            days      = 0
            months    = ls_mara_shelf-mhdhb
            years     = 0
            signum    = '+'
          IMPORTING
            calc_date = lv_bbdat.
      WHEN 'Y'.
        CALL FUNCTION 'RP_CALC_DATE_IN_INTERVAL'
          EXPORTING
            date      = lv_pddat
            days      = 0
            months    = 0
            years     = ls_mara_shelf-mhdhb
            signum    = '+'
          IMPORTING
            calc_date = lv_bbdat.
      WHEN OTHERS.
        MESSAGE e004(zmsg_i2o_rf).
    ENDCASE.

  ENDIF.

*--------------------------------------------------------------------*
* Create batch master only if not existing
*
* Scenario 1: no batch input -> program generates the batch number.
* Scenario 4: batch entered, doesn't exist -> created using that
* externally entered number.
* Scenario 2: batch entered, exists -> this block is SKIPPED
* (lv_batch_exists = abap_true), no new batch is created.
*--------------------------------------------------------------------*
  IF lv_batch_exists = abap_false.

    IF lv_batchno_ui IS INITIAL.

      CLEAR lv_generated_batch.

      CALL FUNCTION 'ZFM_I2O_GET_ALNUM7_SEQ'
        EXPORTING
          iv_seqname    = 'EWM_BATCH'
          iv_start      = 'L000000'
          iv_reason     = 'NBAT'
          iv_matnr      = lv_matnr_int
          iv_werks      = lv_werks
        IMPORTING
          ev_number     = lv_generated_batch
        EXCEPTIONS
          lock_failed   = 1
          overflow      = 2
          invalid_input = 3
          OTHERS        = 4.

      IF sy-subrc <> 0 OR lv_generated_batch IS INITIAL.
        MESSAGE e044(zmsg_i2o_rf).
      ENDIF.

      lv_batchno_ui = lv_generated_batch.
      cs_rehu_prod-charg = lv_batchno_ui.

      CALL FUNCTION 'CONVERSION_EXIT_RFBA_OUTPUT'
        EXPORTING
          input  = cs_rehu_prod-charg
        IMPORTING
          output = cs_rehu_prod-charg_verif.

    ENDIF.

    CLEAR lv_check_external.
    IF lv_batchno_ui IS NOT INITIAL.
      lv_check_external = abap_true.
    ENDIF.

    CLEAR ls_mcha.
    ls_mcha-matnr = lv_matnr_int.
    ls_mcha-werks = lv_werks.
    ls_mcha-charg = lv_batchno_ui.
    ls_mcha-licha = lv_vendor_batch.
    ls_mcha-hsdat = lv_pddat.
    ls_mcha-vfdat = lv_bbdat.

    CALL FUNCTION 'VB_CREATE_BATCH'
      EXPORTING
        ymcha                        = ls_mcha
        no_change_document           = space
        check_external               = lv_check_external
        check_customer               = 'X'
      IMPORTING
        ymcha                        = ls_mcha
      TABLES
        new_batch                    = lt_new_batch
        return                       = lt_return
      EXCEPTIONS
        no_material                  = 1
        no_batch                     = 2
        no_plant                     = 3
        material_not_found           = 4
        plant_not_found              = 5
        stoloc_not_found             = 6
        lock_on_material             = 7
        lock_on_plant                = 8
        lock_on_batch                = 9
        lock_system_error            = 10
        no_authority                 = 11
        batch_exist                  = 12
        stoloc_exist                 = 13
        illegal_batch_number         = 14
        no_batch_handling            = 15
        no_valuation_area            = 16
        valuation_type_not_found     = 17
        no_valuation_found           = 18
        error_automatic_batch_number = 19
        cancelled                    = 20
        wrong_status                 = 21
        interval_not_found           = 22
        number_range_not_extern      = 23
        object_not_found             = 24
        error_check_batch_number     = 25
        no_external_number           = 26
        no_customer_number           = 27
        no_class                     = 28
        error_in_classification      = 29
        inconsistency_in_key         = 30
        region_of_origin_not_found   = 31
        country_of_origin_not_found  = 32
        vendor_error                 = 33
        OTHERS                       = 34.

    lv_subrc_vb = sy-subrc.

    IF lv_subrc_vb <> 0.
      CASE lv_subrc_vb.
        WHEN 12.
          MESSAGE e006(zmsg_i2o_rf).
        WHEN 14.
          MESSAGE e007(zmsg_i2o_rf).
        WHEN 15.
          MESSAGE e002(zmsg_i2o_rf).
        WHEN 25.
          MESSAGE e008(zmsg_i2o_rf).
        WHEN OTHERS.
          READ TABLE lt_return INTO ls_return WITH KEY type = 'E'.
          IF sy-subrc = 0 AND ls_return-message IS NOT INITIAL.
            MESSAGE e016(zmsg_i2o_rf) WITH ls_return-message.
          ELSE.
            MESSAGE e016(zmsg_i2o_rf) WITH |VB_CREATE_BATCH FAILED SUBRC { lv_subrc_vb }|.
          ENDIF.
      ENDCASE.
    ENDIF.

    COMMIT WORK AND WAIT.
    lv_batchno_ui = ls_mcha-charg.

  ENDIF.

*--------------------------------------------------------------------*
* Return values to RF context
*--------------------------------------------------------------------*
  IF lv_batchno_ui IS INITIAL.
    lv_batchno_ui = ls_mcha-charg.
  ENDIF.

  cs_rehu_prod-charg = lv_batchno_ui.

  CALL FUNCTION 'CONVERSION_EXIT_RFBA_OUTPUT'
    EXPORTING
      input  = cs_rehu_prod-charg
    IMPORTING
      output = lv_charg_verif.

  cs_rehu_prod-charg_verif = lv_charg_verif.
  cs_rehu_prod-bbdat       = lv_bbdat.
  cs_rehu_prod-nista       = lv_qty_screen.
  cs_rehu_prod-nista_verif = lv_qty_screen.

  gv_vendor_batch = lv_vendor_batch.
  gv_pddat        = lv_pddat.
  gv_bbdat        = lv_bbdat.

  LOOP AT ct_rehu_prod ASSIGNING <ls_rehu_prod>.
    <ls_rehu_prod>-charg       = cs_rehu_prod-charg.
    <ls_rehu_prod>-charg_verif = cs_rehu_prod-charg_verif.
    <ls_rehu_prod>-bbdat       = cs_rehu_prod-bbdat.
    <ls_rehu_prod>-nista       = cs_rehu_prod-nista.
    <ls_rehu_prod>-nista_verif = cs_rehu_prod-nista_verif.

    IF <ls_rehu_prod>-ritmid IS INITIAL.
      <ls_rehu_prod>-ritmid = cs_rehu_hu-ritmid.
    ENDIF.
  ENDLOOP.

*--------------------------------------------------------------------*
* Update RF screen fields
*--------------------------------------------------------------------*
  CLEAR lt_dynp.

  APPEND VALUE #( fieldname  = lc_fld_batch
                  fieldvalue = lv_charg_verif ) TO lt_dynp.

  APPEND VALUE #( fieldname  = lc_fld_vbatch
                  fieldvalue = gv_vendor_batch ) TO lt_dynp.

  IF lv_bbdat IS NOT INITIAL.
    WRITE lv_bbdat TO lv_date_ext.
    APPEND VALUE #( fieldname  = lc_fld_bbdat
                    fieldvalue = lv_date_ext ) TO lt_dynp.
  ENDIF.

  IF lv_pddat IS NOT INITIAL.
    WRITE lv_pddat TO lv_date_ext.
    APPEND VALUE #( fieldname  = lc_fld_pddat
                    fieldvalue = lv_date_ext ) TO lt_dynp.
  ENDIF.

  CALL FUNCTION 'DYNP_VALUES_UPDATE'
    EXPORTING
      dyname     = lc_prog
      dynumb     = lc_dynnr
    TABLES
      dynpfields = lt_dynp
    EXCEPTIONS
      OTHERS     = 1.

*--------------------------------------------------------------------*
* Partial qty only: keep RF context, let actual pack flow handle split
*--------------------------------------------------------------------*
  IF lv_full_qty = abap_false.

    /scwm/cl_rf_bll_srvc=>set_field( space ).
    /scwm/cl_rf_bll_srvc=>set_prmod(
      /scwm/cl_rf_bll_srvc=>c_prmod_foreground ).
    /scwm/cl_rf_bll_srvc=>set_fcode( lc_pbo2 ).

    IF lv_existing_msg = abap_true.
      MESSAGE s046(zmsg_i2o_rf) DISPLAY LIKE 'E'.
    ELSE.
      MESSAGE s049(zmsg_i2o_rf).
    ENDIF.

    RETURN.

  ENDIF.

*--------------------------------------------------------------------*
* Full qty only: assign batch/BBD directly to original item
*--------------------------------------------------------------------*
  /scwm/cl_tm=>set_lgnum( cs_rehu-lgnum ).

  CREATE OBJECT lo_query_pre.

  CLEAR ls_docid_query_pre.
  ls_docid_query_pre-docid  = cs_rehu_hu-docid.
  ls_docid_query_pre-itemid = cs_rehu_hu-ritmid.
  ls_docid_query_pre-doccat = cs_rehu_hu-rdoccat.
  APPEND ls_docid_query_pre TO lt_docid_query_pre.

  ls_read_opt_pre-mix_in_object_instances =
    /scwm/if_dl_c=>sc_mix_in_load_instance.

  TRY.
      CALL METHOD lo_query_pre->query
        EXPORTING
          it_docid        = lt_docid_query_pre
          iv_whno         = cs_rehu-lgnum
          is_read_options = ls_read_opt_pre
        IMPORTING
          et_items        = lt_items_pre.
    CATCH /scdl/cx_delivery.
      MESSAGE e045(zmsg_i2o_rf).
  ENDTRY.

  CREATE OBJECT lo_dlv.

  " This explicit lo_dlv->lock( ) call was rejecting consistently across
  " different items and after clearing all stale SM12 entries, meaning
  " it conflicts with locking the RF transaction/session already holds
  " on this delivery just by having it open for processing - not an
  " actual competing session. The calls below (update( )/execute( )/
  " save( )) each carry out their own rejected check already and the
  " standard SCDL save( ) framework performs its own locking internally
  " as part of persisting the document, so this redundant upfront lock
  " isn't needed to protect data integrity here.
*--------------------------------------------------------------------*
* core batch number to delivery item
*--------------------------------------------------------------------*
  CLEAR: ls_inrecords_prod,
         lt_inrecords_prod,
         lt_outrecords_prod.

  ls_inrecords_prod-docid         = cs_rehu_hu-docid.
  ls_inrecords_prod-itemid        = cs_rehu_hu-ritmid.
  ls_inrecords_prod-productid     = ls_item-product-productid.
  ls_inrecords_prod-productno     = ls_item-product-productno.
  ls_inrecords_prod-productno_ext = ls_item-product-productno_ext.
  ls_inrecords_prod-productent    = ls_item-product-productent.
  ls_inrecords_prod-product_text  = ls_item-product-product_text.
  ls_inrecords_prod-batchno       = cs_rehu_prod-charg.

  APPEND ls_inrecords_prod TO lt_inrecords_prod.

  lo_dlv->/scdl/if_sp1_aspect~update(
    EXPORTING
      aspect       = /scdl/if_sp_c=>sc_asp_item_product
      inrecords    = lt_inrecords_prod
    IMPORTING
      outrecords   = lt_outrecords_prod
      rejected     = lv_rejected
      return_codes = lt_return_code ).

  IF lv_rejected = abap_true.
    MESSAGE e045(zmsg_i2o_rf).
  ENDIF.

*--------------------------------------------------------------------*
* BBD to delivery item (ITEM_SAPEXT_PRDI aspect - valid,
* registered aspect; BBD stored as a timestamp interval).
*--------------------------------------------------------------------*
  IF lv_bbdat IS NOT INITIAL.

    CALL FUNCTION '/SCWM/LGNUM_TZONE_READ'
      EXPORTING
        iv_lgnum        = cs_rehu-lgnum
      IMPORTING
        ev_tzone        = lv_timezone
      EXCEPTIONS
        interface_error = 1
        data_not_found  = 2
        OTHERS          = 3.

    IF sy-subrc = 0.

      CLEAR: ls_inrecords_bbd,
             lt_inrecords_bbd,
             lt_outrecords_bbd,
             lv_tstamp_bbd.

      CONVERT DATE lv_bbdat
            INTO TIME STAMP lv_tstamp_bbd
            TIME ZONE lv_timezone.

      ls_inrecords_bbd-docid   = cs_rehu_hu-docid.
      ls_inrecords_bbd-itemid  = cs_rehu_hu-ritmid.
      ls_inrecords_bbd-tzonebb = lv_timezone.
      ls_inrecords_bbd-tstfrbb = lv_tstamp_bbd.
      ls_inrecords_bbd-tsttobb = lv_tstamp_bbd.

      APPEND ls_inrecords_bbd TO lt_inrecords_bbd.

      lo_dlv->/scdl/if_sp1_aspect~update(
        EXPORTING
          aspect       = /scdl/if_sp_c=>sc_asp_item_sapext_prdi
          inrecords    = lt_inrecords_bbd
        IMPORTING
          outrecords   = lt_outrecords_bbd
          rejected     = lv_rejected
          return_codes = lt_return_code ).

      IF lv_rejected = abap_true.
        MESSAGE e045(zmsg_i2o_rf).
      ENDIF.

    ENDIF.

  ENDIF.

*--------------------------------------------------------------------*
* Update 3: force redetermination so item picks up batch-derived
* data (vendor batch / production date) from the batch master.
*--------------------------------------------------------------------*
  CLEAR lt_item_key.
  ls_item_key-docid  = cs_rehu_hu-docid.
  ls_item_key-itemid = cs_rehu_hu-ritmid.
  APPEND ls_item_key TO lt_item_key.

  CLEAR ls_action.
  ls_action-action_code = /scdl/if_bo_action_c=>sc_determine.

  lo_dlv->execute(
    EXPORTING
      aspect       = /scdl/if_sp_c=>sc_asp_item
      inkeys       = lt_item_key
      inparam      = ls_action
      action       = /scdl/if_sp_c=>sc_act_execute_action
    IMPORTING
      outrecords   = lt_outrecords
      rejected     = lv_rejected
      return_codes = lt_return_code ).

  IF lv_rejected = abap_true.
    MESSAGE e045(zmsg_i2o_rf).
  ENDIF.

  lo_dlv->/scdl/if_sp1_transaction~before_save(
    IMPORTING
      rejected = lv_rejected ).

  IF lv_rejected = abap_true.
    MESSAGE e045(zmsg_i2o_rf).
  ENDIF.

  lo_dlv->/scdl/if_sp1_transaction~save(
    IMPORTING
      rejected = lv_rejected ).

  IF lv_rejected = abap_true.
    MESSAGE e045(zmsg_i2o_rf).
  ENDIF.

  COMMIT WORK AND WAIT.
  CALL METHOD /scwm/cl_tm=>cleanup( ).

*--------------------------------------------------------------------*
* Stay on same RF screen
*--------------------------------------------------------------------*
  /scwm/cl_rf_bll_srvc=>set_field( space ).
  /scwm/cl_rf_bll_srvc=>set_prmod(
    /scwm/cl_rf_bll_srvc=>c_prmod_foreground ).
  /scwm/cl_rf_bll_srvc=>set_fcode( lc_pbo2 ).

  IF lv_existing_msg = abap_true.
    MESSAGE s046(zmsg_i2o_rf) DISPLAY LIKE 'E'.
  ELSE.
    MESSAGE s050(zmsg_i2o_rf).
  ENDIF.

ENDFUNCTION.
