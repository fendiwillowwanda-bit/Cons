FUNCTION zfm_i2o_rf_micotr_miqusl_pai.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  CHANGING
*"     REFERENCE(CS_MFG_CON_STATIC_DATA) TYPE
*"        /SCWM/S_RF_MFG_CON_STATIC_DATA
*"     REFERENCE(CS_MFG_CON_CHG_DATA) TYPE  /SCWM/S_RF_MFG_CON_CHG_DATA
*"     REFERENCE(CS_MFG_CON_SCREEN_DATA) TYPE
*"        /SCWM/S_RF_MFG_CON_SCREEN_DATA
*"----------------------------------------------------------------------

********************
* Data declaration *
********************

  DATA: lv_fcode         TYPE /scwm/de_fcode,
        lv_qty1_dis      TYPE char80,
        lv_qty2_dis      TYPE char80,
        lv_quantity      TYPE /scwm/de_quantity,
        lv_uom           TYPE /scwm/de_unit,
        lo_rf_mfg_con    TYPE REF TO /scwm/cl_rf_mfg_con,
        lx_mfg_con_error TYPE REF TO /scwm/cx_rf_mfg_con.

******************
* Implementation *
******************

  DATA:
    ls_config TYPE ztxca_config.

  /scwm/cl_rf_bll_srvc=>set_prmod( /scwm/cl_rf_bll_srvc=>c_prmod_foreground ).

  lo_rf_mfg_con = /scwm/cl_rf_mfg_con=>get_instance( ).
  IF lo_rf_mfg_con IS NOT BOUND.
    MESSAGE ID gc_rf_msgid_de TYPE wmegc_severity_err NUMBER '008'.
  ENDIF.

  lv_fcode = /scwm/cl_rf_bll_srvc=>get_fcode( ).

  TRY.
      IF gv_error EQ abap_true
         AND lv_fcode NE 'BACK'
         AND lv_fcode NE gc_fcode_zacons.
        IF gv_invalid_matkl EQ abap_true.
          MESSAGE |Material Group { gv_matkl } is not COI Relevant.| TYPE 'E'.
        ELSE.
          MESSAGE ID gv_msgid
                  TYPE gv_msgty
                  NUMBER gv_msgno.
        ENDIF.
      ENDIF.

      CASE lv_fcode.

        WHEN gc_fcode_zacons.

*--------------------------------------------------------------------*
* SF3 / ZACONS - Actual Consumed Quantity
*--------------------------------------------------------------------*
          DATA:
            lv_acons_qty TYPE /scwm/de_quantity,
            lv_char_qty  TYPE char40.

          CLEAR lv_acons_qty.

          IF cs_mfg_con_screen_data-zzacons_qty IS NOT INITIAL.

            lv_char_qty = cs_mfg_con_screen_data-zzacons_qty.
            CONDENSE lv_char_qty NO-GAPS.

            "RF input: force dot as decimal separator
            REPLACE ALL OCCURRENCES OF ',' IN lv_char_qty WITH '.'.

            TRY.
                lv_acons_qty = lv_char_qty.
              CATCH cx_sy_conversion_no_number.
                MESSAGE e058(zmsg_i2o_rf) WITH 'ActQ'.
            ENDTRY.

          ENDIF.

          "Do not allow ConsQ + ActQ
          IF cs_mfg_con_screen_data-consumed_qty IS NOT INITIAL
          AND cs_mfg_con_screen_data-consumed_qty > 0
          AND lv_acons_qty > 0.
            MESSAGE e055(zmsg_i2o_rf) WITH 'ConsQ' 'ActQ'.
          ENDIF.

          "Do not allow ScrQ + ActQ
          IF cs_mfg_con_screen_data-zzscrap_qty IS NOT INITIAL
          AND cs_mfg_con_screen_data-zzscrap_qty > 0
          AND lv_acons_qty > 0.
            MESSAGE e055(zmsg_i2o_rf) WITH 'ScrQ' 'ActQ'.
          ENDIF.

          "ActQ requires Reason Code
          IF lv_acons_qty > 0
          AND cs_mfg_con_screen_data-zzreason_code IS INITIAL.
            MESSAGE e056(zmsg_i2o_rf).
          ENDIF.

          "ActQ is required when pressing ACon
          IF lv_acons_qty <= 0.
            MESSAGE e058(zmsg_i2o_rf) WITH 'ActQ'.
          ENDIF.

          "Pass converted quantity to CHG data for ZFM_I2O_RF_POST_ACT_CONS
          cs_mfg_con_chg_data-consumed_qty = lv_acons_qty.
          cs_mfg_con_chg_data-consumed_uom = cs_mfg_con_screen_data-consumed_uom.

          CALL FUNCTION 'ZFM_I2O_RF_POST_ACT_CONS'
            EXPORTING
              is_static_data = cs_mfg_con_static_data
              is_screen_data = cs_mfg_con_screen_data
            CHANGING
              cs_chg_data    = cs_mfg_con_chg_data
            EXCEPTIONS
              error          = 1
              OTHERS         = 2.

          IF sy-subrc <> 0.
            "Surface the *specific* message raised inside
            "ZFM_I2O_RF_POST_ACT_CONS (e.g. BOM mismatch, tolerance
            "exceeded, PI/Diff Analyzer failure) instead of masking it
            "with a generic message - required for an auditable,
            "diagnosable posting failure per the FDS.
            IF sy-msgid IS NOT INITIAL.
              MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
            ELSE.
              MESSAGE e057(zmsg_i2o_rf).
            ENDIF.
          ENDIF.

          "Standard 261 consumption against the Process Order, using the
          "actual quantity now reconciled in EWM via PI + Diff Analyzer
          cs_mfg_con_chg_data-consumed_qty = lv_acons_qty.
          cs_mfg_con_chg_data-consumed_uom = cs_mfg_con_screen_data-consumed_uom.

          IF cs_mfg_con_chg_data-batch-batchid IS NOT INITIAL.
            TRY.
                CALL FUNCTION '/SCWM/MATERIAL_QUAN_CONVERT'
                  EXPORTING
                    iv_matid     = cs_mfg_con_chg_data-batch-matid
                    iv_quan      = cs_mfg_con_chg_data-consumed_qty
                    iv_unit_from = cs_mfg_con_chg_data-consumed_uom
                    iv_unit_to   = cs_mfg_con_chg_data-mat_global-meins
                    iv_batchid   = cs_mfg_con_chg_data-batch-batchid.
              CATCH /scwm/cx_md INTO DATA(lx_md_zacons).
                MESSAGE lx_md_zacons TYPE wmegc_severity_err.
                RETURN.
            ENDTRY.
          ENDIF.

          lo_rf_mfg_con->post_consumption(
            EXPORTING
              is_mfg_con_static_data = cs_mfg_con_static_data
            CHANGING
              cs_mfg_con_chg_data    = cs_mfg_con_chg_data ).

          CLEAR:
            cs_mfg_con_screen_data-consumed_qty,
            cs_mfg_con_screen_data-remaining_qty,
            cs_mfg_con_screen_data-zzscrap_qty,
            cs_mfg_con_screen_data-zzacons_qty,
            cs_mfg_con_screen_data-zzreason_code,
            cs_mfg_con_screen_data-qty_sav.

          /scwm/cl_rf_bll_srvc=>set_prmod(
            /scwm/cl_rf_bll_srvc=>c_prmod_background ).

          IF lo_rf_mfg_con->is_mfg_order_completed( cs_mfg_con_static_data ) = abap_true.
            /scwm/cl_rf_bll_srvc=>set_fcode( gc_fcode_mimosl ).
            /scwm/cl_rf_bll_srvc=>set_call_stack_optimizer( gc_step_mimosl ).
          ELSE.
            /scwm/cl_rf_bll_srvc=>set_fcode( gc_fcode_mihbsl ).
            /scwm/cl_rf_bll_srvc=>set_call_stack_optimizer( gc_step_mihbsl ).
          ENDIF.

        WHEN gc_fcode_enter OR gc_fcode_zscrap.

          "---"---------------------------------------------------------------------------------"
          " 1 " The quantity can be entered within two different modes ConsQ and RemQ. These
          "   " modes are handled by two different states of this step. Within the ConsQ mode,
          "   " the user specifies the quantity that they would like to consume, i.e. the
          "   " quantity they take to production. Within the RemQ mode they specifiy the quantity
          "   " they want to leave behind, i.e. the quantity that stays in the warehouse.
          "---"---------------------------------------------------------------------------------"

          IF /scwm/cl_rf_bll_srvc=>get_state( ) <> gc_state_rmqtsl.

            "Use scrap qty field
            IF cs_mfg_con_screen_data-zzscrap_qty > 0 AND
               cs_mfg_con_screen_data-zzreason_code IS NOT INITIAL.

              IF cs_mfg_con_screen_data-consumed_qty > 0 AND
                 cs_mfg_con_screen_data-zzscrap_qty > 0.
                MESSAGE e901.
              ENDIF.

              cs_mfg_con_chg_data-consumed_qty = cs_mfg_con_screen_data-zzscrap_qty.
              cs_mfg_con_chg_data-consumed_uom = cs_mfg_con_screen_data-consumed_uom.

              "Check in BAdI /SCWM/ES_ERP_GOODSMVT
              ls_config-mandt  = sy-mandt.
              ls_config-kdef01 = 'ZFM_I2O_RF'.
              ls_config-kdef02 = 'SCRAP'.
              ls_config-pval01 = 'X'.

              MODIFY ztxca_config FROM ls_config.
              CLEAR ls_config.

              ls_config-mandt  = sy-mandt.
              ls_config-kdef01 = 'ZFM_I2O_RF'.
              ls_config-kdef02 = 'REASON'.
              ls_config-pval02 = cs_mfg_con_screen_data-zzreason_code.

              MODIFY ztxca_config FROM ls_config.
              CLEAR ls_config.
            ELSE.
              IF cs_mfg_con_screen_data-consumed_qty < 0.
                MESSAGE e022.
              ENDIF.

              cs_mfg_con_chg_data-consumed_qty = cs_mfg_con_screen_data-consumed_qty.
              cs_mfg_con_chg_data-consumed_uom = cs_mfg_con_screen_data-consumed_uom.

            ENDIF.
          ELSE.

            IF cs_mfg_con_screen_data-remaining_qty < 0.
              MESSAGE e022.
            ENDIF.

            cs_mfg_con_chg_data-remaining_qty = cs_mfg_con_screen_data-remaining_qty.
            cs_mfg_con_chg_data-remaining_uom = cs_mfg_con_screen_data-remaining_uom.

            lo_rf_mfg_con->calculate_consumed_qty(
              CHANGING
                cs_mfg_con_chg_data = cs_mfg_con_chg_data
            ).
          ENDIF.


          IF cs_mfg_con_chg_data-batch-batchid IS NOT INITIAL.
*         Mostly implemented for batch specific UoM Materials
            TRY.
                CALL FUNCTION '/SCWM/MATERIAL_QUAN_CONVERT'
                  EXPORTING
                    iv_matid     = cs_mfg_con_chg_data-batch-matid
                    iv_quan      = cs_mfg_con_chg_data-consumed_qty
                    iv_unit_from = cs_mfg_con_chg_data-consumed_uom
                    iv_unit_to   = cs_mfg_con_chg_data-mat_global-meins
                    iv_batchid   = cs_mfg_con_chg_data-batch-batchid.
              CATCH /scwm/cx_md INTO DATA(lx_md).
                MESSAGE lx_md TYPE wmegc_severity_err.
                RETURN.
            ENDTRY.
          ENDIF.

          "---"---------------------------------------------------------------------------------"
          " 2 " Post the consumption
          "---"---------------------------------------------------------------------------------"
          lo_rf_mfg_con->post_consumption(
            EXPORTING
              is_mfg_con_static_data = cs_mfg_con_static_data
            CHANGING
              cs_mfg_con_chg_data    = cs_mfg_con_chg_data
          ).

          "---"---------------------------------------------------------------------------------"
          " 3 " Decide where to go next
          "---"---------------------------------------------------------------------------------"

          " If the post was successful, return to the HU / bin selection
          " step or the manufacturing order selection step in case the order
          " was completed. Note that the stack optimizer needes to be called
          " to remove the previous selection from the stack.
          /scwm/cl_rf_bll_srvc=>set_prmod( /scwm/cl_rf_bll_srvc=>c_prmod_background ).

          IF lo_rf_mfg_con->is_mfg_order_completed( cs_mfg_con_static_data ) = abap_true.
            /scwm/cl_rf_bll_srvc=>set_fcode( gc_fcode_mimosl ).
            /scwm/cl_rf_bll_srvc=>set_call_stack_optimizer( gc_step_mimosl ).
          ELSE.
            /scwm/cl_rf_bll_srvc=>set_fcode( gc_fcode_mihbsl ).
            /scwm/cl_rf_bll_srvc=>set_call_stack_optimizer( gc_step_mihbsl ).
          ENDIF.

        WHEN gc_fcode_micuom.

          IF /scwm/cl_rf_bll_srvc=>get_state( ) <> gc_state_rmqtsl.
            WRITE cs_mfg_con_screen_data-consumed_qty TO lv_qty1_dis.
            WRITE cs_mfg_con_screen_data-qty_sav      TO lv_qty2_dis.
            lv_quantity = cs_mfg_con_screen_data-consumed_qty.
            lv_uom      = cs_mfg_con_screen_data-consumed_uom.
          ELSE.
            WRITE cs_mfg_con_screen_data-remaining_qty  TO lv_qty1_dis.
            WRITE cs_mfg_con_screen_data-qty_sav        TO lv_qty2_dis.
            lv_quantity = cs_mfg_con_screen_data-remaining_qty.
            lv_uom      = cs_mfg_con_screen_data-remaining_uom.
          ENDIF.

          IF  lv_qty1_dis <> lv_qty2_dis.
            cs_mfg_con_chg_data-qty_int = lv_quantity.
          ENDIF.

          /scwm/cl_rf_mfg=>change_calculate_uom(
            EXPORTING
              iv_matid        = cs_mfg_con_chg_data-mat_global-matid
              iv_act_uom      = lv_uom
              iv_act_quantity = cs_mfg_con_chg_data-qty_int
              it_mat_uom      = cs_mfg_con_chg_data-mat_uom
            IMPORTING
              ev_new_uom      = lv_uom
              ev_new_quantity = cs_mfg_con_chg_data-qty_int
          ).

          IF /scwm/cl_rf_bll_srvc=>get_state( ) <> gc_state_rmqtsl.
            cs_mfg_con_screen_data-consumed_uom = lv_uom.
            cs_mfg_con_screen_data-consumed_qty = cs_mfg_con_chg_data-qty_int.
            cs_mfg_con_chg_data-consumed_qty    = cs_mfg_con_chg_data-qty_int.
          ELSE.
            cs_mfg_con_screen_data-remaining_uom = lv_uom.
            cs_mfg_con_screen_data-remaining_qty = cs_mfg_con_chg_data-qty_int.
            cs_mfg_con_chg_data-remaining_qty    = cs_mfg_con_chg_data-qty_int.
          ENDIF.

          cs_mfg_con_screen_data-qty_sav      = cs_mfg_con_chg_data-qty_int.


        WHEN gc_fcode_miconq.

          " There are two states: Consumed Quantity Selection and
          " Remaining Quantity Selection.
          " This function sets the state: Consumed Quantity selection.
          " In this  state the user can specify the quantity they want to consume
          " (i.e. taking away).

          IF cs_mfg_con_chg_data-remaining_uom IS INITIAL.
            cs_mfg_con_chg_data-remaining_uom = cs_mfg_con_chg_data-consumed_uom.
          ENDIF.

          IF /scwm/cl_rf_bll_srvc=>get_state( ) = gc_state_rmqtsl.
            cs_mfg_con_chg_data-remaining_qty = cs_mfg_con_screen_data-remaining_qty.
            cs_mfg_con_chg_data-remaining_uom = cs_mfg_con_screen_data-remaining_uom.

            lo_rf_mfg_con->calculate_consumed_qty(
              CHANGING
                cs_mfg_con_chg_data = cs_mfg_con_chg_data
            ).

            cs_mfg_con_screen_data-consumed_qty = cs_mfg_con_chg_data-consumed_qty.
            cs_mfg_con_screen_data-consumed_uom = cs_mfg_con_chg_data-consumed_uom.

            /scwm/cl_rf_bll_srvc=>set_state( gc_state_qtysel ).
          ENDIF.

        WHEN gc_fcode_miremq.

          " There are two states: Consumed Quantity Selection and Remaining
          " Quantity Selection.
          " This function sets the state: Remaining Quantity selection.
          " In this  state the user can specify the quantity they do not want
          " to consume (i.e. the quantity that stays in the PSA).

          IF /scwm/cl_rf_bll_srvc=>get_state( ) = gc_state_qtysel.
            cs_mfg_con_chg_data-consumed_qty  = cs_mfg_con_screen_data-consumed_qty.
            cs_mfg_con_chg_data-consumed_uom  = cs_mfg_con_screen_data-consumed_uom.

            lo_rf_mfg_con->calculate_remaining_qty(
              CHANGING
                cs_mfg_con_chg_data = cs_mfg_con_chg_data
            ).

            cs_mfg_con_screen_data-remaining_qty = cs_mfg_con_chg_data-remaining_qty.
            cs_mfg_con_screen_data-remaining_uom = cs_mfg_con_chg_data-remaining_uom.

            /scwm/cl_rf_bll_srvc=>set_state( gc_state_rmqtsl ).
          ENDIF.

        WHEN gc_fcode_milist OR gc_fcode_zrlist.
          CLEAR:  cs_mfg_con_screen_data-consumed_qty,
                  cs_mfg_con_screen_data-remaining_qty.

        WHEN gc_fcode_mifull.
          IF /scwm/cl_rf_bll_srvc=>get_state( ) = gc_state_rmqtsl.
            cs_mfg_con_screen_data-remaining_qty  = 0.
          ELSE.
            cs_mfg_con_chg_data-remaining_qty = 0.
            cs_mfg_con_chg_data-remaining_uom = cs_mfg_con_screen_data-consumed_uom.

            lo_rf_mfg_con->calculate_consumed_qty(
              CHANGING
                cs_mfg_con_chg_data = cs_mfg_con_chg_data
            ).

            cs_mfg_con_screen_data-consumed_qty = cs_mfg_con_chg_data-consumed_qty.
            cs_mfg_con_screen_data-consumed_uom = cs_mfg_con_chg_data-consumed_uom.
          ENDIF.

      ENDCASE.

    CATCH /scwm/cx_rf_mfg_con INTO lx_mfg_con_error.
      MESSAGE lx_mfg_con_error TYPE wmegc_severity_err.
  ENDTRY.

ENDFUNCTION.
