CALL PDIS_TRANSPORTORDER.SETVEHICLEATTRIBUTES (10340431803549, TRUE)
SELECT	* FROM	RES_HST WHERE 	REF_TIX = 10340431803549 LIMIT	10;

SELECT
	t
	--,*
FROM
	RES_HST_ZUS
WHERE
	RES_HST_TIX IN (
		SELECT
			RES_HST_TIX
		FROM
			RES_HST
		WHERE
			REF_TIX = 10340431803549
	)
	AND TYP = 262
	--and key IS NOT NULL 
LIMIT
	100

CALL PDIS_TRANSPORTORDER.SETVEHICLEATTRIBUTES (10340431803549, TRUE)
-- Test Case 1 (OK): "atp_frc_b=T atp_frb_b=F atp_koffer_b=F wb_b=F plane_b=F tank_b=F vorkuehl_b=T tempschreiber_b=F trennwand_b=T doppelstock_b=T"

CALL PDIS_TRANSPORTORDER.SETVEHICLEATTRIBUTES (10340431803549, FALSE)
-- Test Case 2 (OK): "atp_frc_b=F atp_frb_b=F atp_koffer_b=F wb_b=F plane_b=F tank_b=F vorkuehl_b=F tempschreiber_b=F trennwand_b=F doppelstock_b=F"

CALL PDIS_TRANSPORTORDER.SETVEHICLEATTRIBUTES (10340431803549, p_precooling_required:=FALSE)
-- Test Case 3 (NOK): "atp_frc_b=F atp_frb_b=F atp_koffer_b=F wb_b=F plane_b=F tank_b=F vorkuehl_b=F tempschreiber_b=F trennwand_b=F doppelstock_b=F atp_frb_b=F atp_koffer_b=F wb_b=F plane_b=F tank_b=F vorkuehl_b=F tempschreiber_b=F trennwand_b=F doppelstock_b=F"

CALL PDIS_TRANSPORTORDER.SETVEHICLEATTRIBUTES (10340431803549, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)
-- Test Case 4 (OK): "atp_frc_b=F atp_frb_b=F atp_koffer_b=F wb_b=F plane_b=F tank_b=F vorkuehl_b=F tempschreiber_b=F trennwand_b=F doppelstock_b=F"