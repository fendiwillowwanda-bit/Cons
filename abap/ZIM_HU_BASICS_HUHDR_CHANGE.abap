METHOD /scwm/if_ex_hu_basics_huhdr~change.

* No functional change vs. the original - reviewed and kept as-is.
* This method only ever inherits DOWNWARD from an already-populated
* top HU (GUID_HU_TOP), so it correctly no-ops for a HU that has no
* top yet or whose top has no destination set. The "same level" /
* "child HU not carrying over" cases reported are caused elsewhere
* (see ZIM_HU_BASICS_NESTING_CHECK.abap and
* ZIM_CORE_CR_INT_CR_INSERT.abap) - fixing those means this method
* will now actually find a populated top HU to read from in more
* cases than before.

  DATA: ls_top_hu TYPE /scwm/huhdr.

  IF cs_huhdr-destination_bin IS NOT INITIAL
     OR cs_huhdr-destination_psa IS NOT INITIAL.
    RETURN.
  ENDIF.

  IF cs_huhdr-guid_hu_top IS INITIAL.
    RETURN.
  ENDIF.

  SELECT SINGLE destination_bin,
                destination_psa
    FROM /scwm/huhdr
    INTO CORRESPONDING FIELDS OF @ls_top_hu
    WHERE guid_hu = @cs_huhdr-guid_hu_top.

  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  IF ls_top_hu-destination_bin IS INITIAL
     OR ls_top_hu-destination_psa IS INITIAL.
    RETURN.
  ENDIF.

  cs_huhdr-destination_bin = ls_top_hu-destination_bin.
  cs_huhdr-destination_psa = ls_top_hu-destination_psa.

ENDMETHOD.
