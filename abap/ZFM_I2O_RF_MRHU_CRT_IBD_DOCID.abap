FUNCTION zfm_i2o_rf_mrhu_crt_ibd_docid.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(IV_LGNUM) TYPE  /SCWM/LGNUM
*"     REFERENCE(IV_EGR_DOCID) TYPE  /SCDL/DL_DOCID
*"     REFERENCE(IV_EGR_ITEMID) TYPE  /SCDL/DL_ITEMID
*"     REFERENCE(IV_LGPLA) TYPE  /SCWM/LGPLA
*"  EXPORTING
*"     REFERENCE(EV_DOCID) TYPE  /SCWM/DE_DOCID
*"     REFERENCE(EV_ITEMID) TYPE  /SCDL/DL_ITEMID
*"     REFERENCE(EV_DOCNO) TYPE  /SCDL/DL_DOCNO
*"     REFERENCE(EV_SUCCESS) TYPE  ABAP_BOOL
*"     REFERENCE(EV_MESSAGE) TYPE  STRING
*"     REFERENCE(ET_BAPIRET) TYPE  BAPIRETTAB
*"  EXCEPTIONS
*"      ERROR
*"----------------------------------------------------------------------

  DATA:
    lo_egr2pdi            TYPE REF TO /scwm/cl_dlv_egr2pdi,
    lo_message            TYPE REF TO /scdl/cl_dm_message,
    lo_dlv_manag          TYPE REF TO /scwm/if_dlv_manag,
    lt_item_egr           TYPE /scdl/t_sp_k_item,
    ls_item_egr           TYPE /scdl/s_sp_k_item,
    lt_item_pdi           TYPE /scwm/t_dlv_egr2pdi_item_ass,
    lt_bapiret            TYPE bapirettab,
    ls_bapiret            TYPE bapiret2,
    lv_rejected           TYPE boole_d,
    lv_rollback_work_done TYPE boole_d,
    lv_commit_work_done   TYPE boole_d,
    lv_check_itemid       TYPE /scdl/dl_itemid,
    lv_gmbin              TYPE /scwm/dl_gmbin,
    lv_exception_text     TYPE string.

  FIELD-SYMBOLS:
    <ls_item_pdi> TYPE /scwm/s_dlv_egr2pdi_item_ass.

  DEFINE append_return.
    CLEAR ls_bapiret.
    ls_bapiret-type    = &1.
    ls_bapiret-id      = 'ZMSG_I2O_RF'.
    ls_bapiret-number  = &2.
    ls_bapiret-message = ev_message.
    APPEND ls_bapiret TO lt_bapiret.
  END-OF-DEFINITION.

  CLEAR:
    ev_docid,
    ev_itemid,
    ev_docno,
    ev_success,
    ev_message,
    et_bapiret,
    lt_bapiret.

*--------------------------------------------------------------------*
* Validate input
*--------------------------------------------------------------------*
  IF iv_lgnum IS INITIAL.
    MESSAGE e014(zmsg_i2o_rf) INTO ev_message.
    append_return 'E' '014'.
    et_bapiret = lt_bapiret.
    RAISE error.
  ENDIF.

  IF iv_egr_docid IS INITIAL OR iv_egr_itemid IS INITIAL.
    MESSAGE e015(zmsg_i2o_rf) INTO ev_message.
    append_return 'E' '015'.
    et_bapiret = lt_bapiret.
    RAISE error.
  ENDIF.

*--------------------------------------------------------------------*
* Initialize EWM context
*--------------------------------------------------------------------*
  TRY.
      /scwm/cl_tm=>cleanup( ).

      /scwm/cl_tm=>set_lgnum(
        EXPORTING
          iv_lgnum = iv_lgnum ).

    CATCH cx_root INTO DATA(lx_tm).
      lv_exception_text = lx_tm->get_text( ).
      MESSAGE e016(zmsg_i2o_rf) WITH lv_exception_text INTO ev_message.
      append_return 'E' '016'.
      et_bapiret = lt_bapiret.
      RAISE error.
  ENDTRY.

*--------------------------------------------------------------------*
* Build EGR item key
*--------------------------------------------------------------------*
  CLEAR ls_item_egr.

  ls_item_egr-docid  = iv_egr_docid.
  ls_item_egr-itemid = iv_egr_itemid.

  APPEND ls_item_egr TO lt_item_egr.

*--------------------------------------------------------------------*
* Create PDI from EGR in standard buffer
*--------------------------------------------------------------------*
  TRY.
      lo_egr2pdi = /scwm/cl_dlv_egr2pdi=>get_instance( ).

      lo_egr2pdi->create_item_new_pdi(
        EXPORTING
          it_item_egr = lt_item_egr
        IMPORTING
          et_item_pdi = lt_item_pdi
          eo_message  = lo_message ).

    CATCH /scdl/cx_delivery INTO DATA(lx_delivery).
      lv_exception_text = lx_delivery->get_text( ).

      IF lv_exception_text IS INITIAL.
        MESSAGE e017(zmsg_i2o_rf) INTO ev_message.
        append_return 'E' '017'.
      ELSE.
        MESSAGE e016(zmsg_i2o_rf) WITH lv_exception_text INTO ev_message.
        append_return 'E' '016'.
      ENDIF.

      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      /scwm/cl_tm=>cleanup( ).

      et_bapiret = lt_bapiret.
      RAISE error.

    CATCH cx_root INTO DATA(lx_create).
      lv_exception_text = lx_create->get_text( ).

      IF lv_exception_text IS INITIAL.
        MESSAGE e018(zmsg_i2o_rf) INTO ev_message.
        append_return 'E' '018'.
      ELSE.
        MESSAGE e016(zmsg_i2o_rf) WITH lv_exception_text INTO ev_message.
        append_return 'E' '016'.
      ENDIF.

      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      /scwm/cl_tm=>cleanup( ).

      et_bapiret = lt_bapiret.
      RAISE error.
  ENDTRY.

*--------------------------------------------------------------------*
* Check standard message object from creation
*--------------------------------------------------------------------*
  IF lo_message IS BOUND AND lo_message->check( ) = abap_true.
    MESSAGE e017(zmsg_i2o_rf) INTO ev_message.
    append_return 'E' '017'.

    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    /scwm/cl_tm=>cleanup( ).

    et_bapiret = lt_bapiret.
    RAISE error.
  ENDIF.

*--------------------------------------------------------------------*
* Read created PDI association
*--------------------------------------------------------------------*
  READ TABLE lt_item_pdi ASSIGNING <ls_item_pdi> INDEX 1.

  IF sy-subrc <> 0 OR <ls_item_pdi> IS NOT ASSIGNED.
    MESSAGE e017(zmsg_i2o_rf) INTO ev_message.
    append_return 'E' '017'.

    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    /scwm/cl_tm=>cleanup( ).

    et_bapiret = lt_bapiret.
    RAISE error.
  ENDIF.

  ev_docid  = <ls_item_pdi>-docidpdi.
  ev_itemid = <ls_item_pdi>-itemidpdi.

  IF ev_docid IS INITIAL OR ev_itemid IS INITIAL.
    MESSAGE e017(zmsg_i2o_rf) INTO ev_message.
    append_return 'E' '017'.

    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    /scwm/cl_tm=>cleanup( ).

    CLEAR:
      ev_docid,
      ev_itemid.

    et_bapiret = lt_bapiret.
    RAISE error.
  ENDIF.

*--------------------------------------------------------------------*
* Save PDI through standard delivery management
*--------------------------------------------------------------------*
  TRY.
      lo_dlv_manag = /scwm/cl_dlv_management_prd=>get_doccat_instance(
        iv_doccat = /scdl/if_dl_doc_c=>sc_doccat_inb_prd ).

      IF lo_dlv_manag IS NOT BOUND.
        MESSAGE e019(zmsg_i2o_rf) INTO ev_message.
        append_return 'E' '019'.

        CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
        /scwm/cl_tm=>cleanup( ).

        CLEAR:
          ev_docid,
          ev_itemid.

        et_bapiret = lt_bapiret.
        RAISE error.
      ENDIF.

      lo_dlv_manag->save(
        EXPORTING
          iv_synchronously      = abap_true
          iv_wait               = abap_true
          iv_do_commit_work     = abap_true
        IMPORTING
          ev_rejected           = lv_rejected
          ev_rollback_work_done = lv_rollback_work_done
          ev_commit_work_done   = lv_commit_work_done ).

    CATCH cx_root INTO DATA(lx_save).
      lv_exception_text = lx_save->get_text( ).

      IF lv_exception_text IS INITIAL.
        MESSAGE e019(zmsg_i2o_rf) INTO ev_message.
        append_return 'E' '019'.
      ELSE.
        MESSAGE e016(zmsg_i2o_rf) WITH lv_exception_text INTO ev_message.
        append_return 'E' '016'.
      ENDIF.

      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      /scwm/cl_tm=>cleanup( ).

      CLEAR:
        ev_docid,
        ev_itemid.

      et_bapiret = lt_bapiret.
      RAISE error.
  ENDTRY.

  IF lv_rejected = abap_true OR lv_rollback_work_done = abap_true.
    MESSAGE e019(zmsg_i2o_rf) INTO ev_message.
    append_return 'E' '019'.

    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    /scwm/cl_tm=>cleanup( ).

    CLEAR:
      ev_docid,
      ev_itemid.

    et_bapiret = lt_bapiret.
    RAISE error.
  ENDIF.

  IF lv_commit_work_done IS INITIAL.
    COMMIT WORK AND WAIT.
  ENDIF.

*--------------------------------------------------------------------*
* Validate saved PDI and GMBIN
*--------------------------------------------------------------------*
  CLEAR:
    lv_check_itemid,
    lv_gmbin.

  SELECT SINGLE itemid,
                /scwm/gmbin
    FROM /scdl/db_proci_i
    WHERE docid  = @ev_docid
      AND itemid = @ev_itemid
    INTO (@lv_check_itemid, @lv_gmbin).

  IF sy-subrc <> 0 OR lv_check_itemid IS INITIAL.
    MESSAGE e019(zmsg_i2o_rf) INTO ev_message.
    append_return 'E' '019'.

    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    /scwm/cl_tm=>cleanup( ).

    CLEAR:
      ev_docid,
      ev_itemid.

    et_bapiret = lt_bapiret.
    RAISE error.
  ENDIF.

  IF lv_gmbin IS INITIAL.
    MESSAGE e020(zmsg_i2o_rf) INTO ev_message.
    append_return 'E' '020'.

    /scwm/cl_tm=>cleanup( ).

    et_bapiret = lt_bapiret.
    RAISE error.
  ENDIF.

*--------------------------------------------------------------------*
* Get document number
*--------------------------------------------------------------------*
  CLEAR ev_docno.

  SELECT SINGLE docno
    FROM /scdl/db_proci_i
    WHERE docid  = @ev_docid
      AND itemid = @ev_itemid
    INTO @ev_docno.

  ev_success = abap_true.

  MESSAGE s021(zmsg_i2o_rf) WITH ev_docno lv_gmbin INTO ev_message.
  append_return 'S' '021'.

  et_bapiret = lt_bapiret.

  /scwm/cl_tm=>cleanup( ).

ENDFUNCTION.
