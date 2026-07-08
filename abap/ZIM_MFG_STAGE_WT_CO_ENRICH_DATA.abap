METHOD /scwm/if_ex_mfg_stage_wt_co~enrich_data.

    DATA: lv_atinn TYPE ausp-atinn,
          lv_valid TYPE abap_bool.

    DATA: lt_psabin TYPE ztt_i2o_brf_psabin,
          ls_psabin TYPE zsi2o_brf_psabin,
          lv_lgnum  TYPE /scwm/lgnum,
          lv_memid  TYPE char80,
          lt_ctx    TYPE STANDARD TABLE OF zsi2o_psa_ctx,
          ls_ctx    TYPE zsi2o_psa_ctx,
          lv_wcr    TYPE /scwm/de_wcr.

    FIELD-SYMBOLS: <lv_any> TYPE any.

    lv_lgnum = /scwm/cl_tm=>sv_lgnum.

    "Check BRF+
    zcl_brfplus_data=>get_psa_bin(
      EXPORTING
        iv_lgnum  = lv_lgnum
      IMPORTING
        et_result = lt_psabin ).

    IF lt_psabin IS INITIAL.
      RETURN.
    ENDIF.

    "Continue only if current WPT is maintained in BRF+
    READ TABLE lt_psabin INTO ls_psabin
      WITH KEY procty = is_create-procty.

    IF sy-subrc NE 0.
      RETURN.
    ENDIF.

    "Validate PSA bin determined by standard /SCWM/STAGE
    IF is_stage-lgpla IS INITIAL.
      MESSAGE e087(zmsg_i2o).
    ENDIF.

    IF is_stage-psa IS INITIAL.
      MESSAGE e088(zmsg_i2o).
    ENDIF.

    IF lv_lgnum IS INITIAL
       OR is_create-procty IS INITIAL
       OR is_stage-lgpla IS INITIAL
       OR is_stage-psa IS INITIAL
       OR is_stage-docid IS INITIAL
       OR is_stage-itemid IS INITIAL.
      RETURN.
    ENDIF.

    ASSIGN COMPONENT 'WCR' OF STRUCTURE is_create TO <lv_any>.
    IF sy-subrc = 0.
      lv_wcr = <lv_any>.
    ENDIF.

    "Store PSA context in ABAP memory for WT creation BAdI
    lv_memid = |ZI2O_PSA_BIN_{ lv_lgnum }|.

    IMPORT lt_ctx = lt_ctx
      FROM MEMORY ID lv_memid.

    DELETE lt_ctx WHERE lgnum  = lv_lgnum
                    AND procty = is_create-procty
                    AND docid  = is_stage-docid
                    AND itemid = is_stage-itemid.

    CLEAR ls_ctx.

    ls_ctx-lgnum  = lv_lgnum.
    ls_ctx-procty = is_create-procty.
    ls_ctx-docid  = is_stage-docid.
    ls_ctx-itemid = is_stage-itemid.
    ls_ctx-bin    = is_stage-lgpla.
    ls_ctx-psa    = is_stage-psa.
    ls_ctx-wcr    = lv_wcr.

    SELECT SINGLE productno
    FROM /scdl/db_proci_p
    INTO @ls_ctx-matnr
   WHERE docid  = @is_stage-docid
     AND itemid = @is_stage-itemid.

    APPEND ls_ctx TO lt_ctx.

    SORT lt_ctx BY lgnum procty docid itemid.
    DELETE ADJACENT DUPLICATES FROM lt_ctx
      COMPARING lgnum procty docid itemid.

    EXPORT lt_ctx = lt_ctx
      TO MEMORY ID lv_memid.

*--------------------------------------------------------------------*
* COI logic
*--------------------------------------------------------------------*
    "get coi from header table
    SELECT  SINGLE zzcoi
      FROM  /scdl/db_proch_p
      INTO  @DATA(lv_coi)
     WHERE  docid EQ @is_stage-docid.

    "if coi is not initial then it is coi relevant
    IF sy-subrc EQ 0 AND lv_coi IS NOT INITIAL.
      lv_valid = abap_true.

      SELECT SINGLE productno,
                    stock_owner
        FROM /scdl/db_proci_p
        INTO @DATA(ls_proci)
       WHERE docid EQ @is_stage-docid
         AND itemid EQ @is_stage-itemid.

      IF sy-subrc NE 0.
        lv_valid = abap_false.
      ENDIF.

      IF lv_valid EQ abap_true.
        SELECT SINGLE matkl
          FROM mara
          INTO @DATA(lv_matkl)
         WHERE matnr EQ @ls_proci-productno.

        IF sy-subrc EQ 0.
          SELECT SINGLE @abap_true
            FROM ztxca_config
            INTO @DATA(lv_valid_matkl)
           WHERE kdef01 EQ 'ZMM_COI_3WAYCHECK'
             AND kdef02 EQ 'MATKL'
             AND kval02 EQ @lv_matkl.
        ENDIF.
      ENDIF.

      IF lv_valid EQ abap_true AND lv_valid_matkl EQ abap_true.
        CALL FUNCTION 'CONVERSION_EXIT_ATINN_INPUT'
          EXPORTING
            input  = 'CGT_COI_BDF'
          IMPORTING
            output = lv_atinn.
        SELECT objek
          FROM ausp
          INTO TABLE @DATA(lt_ausp)
         WHERE atwrt EQ @lv_coi
           AND atinn EQ @lv_atinn.

        IF sy-subrc NE 0.
          lv_valid = abap_false.
*          Error Message
          MESSAGE e002(zmsg_i2o_coi)
             WITH lv_coi.
        ENDIF.
      ENDIF.

      IF lv_valid EQ abap_true AND lv_valid_matkl EQ abap_true.
        LOOP AT lt_ausp ASSIGNING FIELD-SYMBOL(<lfs_ausp>).
          DATA(lv_cuobj) = CONV cuobj( <lfs_ausp>-objek ).

          SELECT matnr,
                 charg,
                 vfdat
            FROM mch1
            INTO TABLE @DATA(lt_mch1)
           WHERE cuobj_bm EQ @lv_cuobj
             AND matnr EQ @ls_proci-productno.

          IF sy-subrc EQ 0.
            SORT lt_mch1 ASCENDING BY vfdat.
            DATA(ls_mch1) = lt_mch1[ 1 ].

            SELECT SINGLE scm_matid_guid16
              FROM mara
              INTO @DATA(lv_matid)
             WHERE matnr EQ @ls_mch1-matnr.
            IF sy-subrc EQ 0.
              SELECT lgnum,
                     lgpla,
                     huident,
                     vfdat,
                     wdatu
                FROM /scwm/aqua
                INTO TABLE @DATA(lt_aqua)
               WHERE lgtyp EQ 'A001'
                 AND matid EQ @lv_matid
                 AND charg EQ @ls_mch1-charg
                 AND cat EQ 'F2'
                 AND owner EQ @ls_proci-stock_owner
                 AND quan GE @is_stage-quan.

              IF sy-subrc EQ 0.
                "select the storage bin with the latest expiration date
                SORT lt_aqua ASCENDING BY vfdat wdatu.

                "select only where storage bin is not blank
                LOOP AT lt_aqua ASSIGNING FIELD-SYMBOL(<lfs_aqua>) WHERE lgpla IS NOT INITIAL.
                  DATA(lv_lgpla) = <lfs_aqua>-lgpla.
                  lv_lgnum = <lfs_aqua>-lgnum.
                  EXIT.
                ENDLOOP.

*                SELECT SINGLE @abap_true
*                  FROM ztxca_config
*                  INTO @DATA(lv_valid_lgnum)
*                 WHERE kdef01 EQ 'ZEWM_COI_PRORD'
*                   AND kdef02 EQ 'LGNUM'
*                   AND kval02 EQ @lv_lgnum.
*
*                IF lv_valid_matkl IS INITIAL AND lv_valid_lgnum IS INITIAL.
                IF lv_valid_matkl IS INITIAL.
                  MESSAGE |Material Group { lv_matkl } is not COI Relevant.| TYPE 'E'.
*                  "Error Message
*                    MESSAGE e003(zmsg_i2o_coi)
*                       WITH lv_matkl lv_lgnum.
                ELSE.
                  IF lv_lgpla IS NOT INITIAL.
                    cs_create-vlpla = lv_lgpla.
                  ENDIF.
                ENDIF.
              ELSE.
                "Error message
                MESSAGE e004(zmsg_i2o_coi).
              ENDIF.
            ENDIF.
          ENDIF.
        ENDLOOP.
      ENDIF.

    ENDIF.
  ENDMETHOD.
