--EXPLAIN
SELECT
	TRANSPORTORDERID,
	TRANSPORTORDERNUMBER,
	COMPANY,
	BRANCH,
	LOADINGDATE,
	REGIONID,
	REGION,
	TRANSPORTMODE,
	STATUS,
	CONTRACTORID,
	CONTRACTORNUMBER,
	CONTRACTORINDEX,
	CONTRACTORNAME1,
	CONTRACTORNAME2,
	CONTRACTORNAME3,
	CONTRACTORMATCHCODE,
	CONTRACTORPARTICIPANTTYPE,
	CONTRACTORSTREET,
	CONTRACTORCOUNTRY,
	CONTRACTORPOSTALCODE,
	CONTRACTORCITY,
	CONTRACTORDISTRICT,
	CONTRACTORADDRESSID,
	TRUCKID,
	TRUCKMATCHCODEID,
	TRUCKLICENSEPLATE,
	TRUCKSEALID,
	TRAILERID,
	TRAILERMATCHCODEID,
	TRAILERLICENSEPLATE,
	TRAILERSEALID,
	DRIVERID,
	DRIVERNAME,
	CODRIVERID,
	CODRIVERNAME,
	VEHICLEPALLETSPACES,
	VEHICLEWEIGHT,
	GATEID,
	PLANNEDDEPARTURETIME,
	PICKUPLOCATIONSSUM,
	DELIVERYLOCATIONSSUM,
	CHAMBERSSUM,
	UNLOADINGINFO,
	SERVICEAREAINFO,
	PLANNEDPALLETSPACES,
	PLANNEDVOLUMEPALLETSPACES,
	PLANNEDFLOORPALLETSPACES,
	LOADINGAIDSSUM,
	WEIGHT,
	FREIGHTCOSTS,
	TOLLCOSTS,
	TOTALCOSTS,
	CURRENCY,
	COMPANYFREIGHTCOSTS,
	COMPANYTOLLCOSTS,
	COMPANYTOTALCOSTS,
	COMPANYCURRENCY
FROM
	TMS1034.V_DIS_TRANSPORTORDER
WHERE
	TRANSPORTORDERID IN (
	10340490754503,
10340490486293,
10340490547506,
10340490633805,
10340490709876,
10340490711399,
10340490711514,
10340490724302,
10340490727406,
10340490727694,
10340490730106,
10340490732016,
10340490732476,
10340490796725,
10340490844027,
10340490844257,
10340490862213,
10340490862206
		-- SELECT
		-- 	TA_TIX
		-- FROM
		-- 	(
		-- 		-- THIS WOULD BE THE NEW V_DIS_TRANSPORT_ORDER_COUNT			
		-- 		SELECT
		-- 			S1.SENDUNG_TIX AS TA_TIX,
		-- 			S1.SENDUNG_N AS TA_N,
		-- 			S1.FIX_KEY AS TA_FIX_KEY,
		-- 			S1.SENDUNGSART AS TA_ART,
		-- 			S1.FIRMA,
		-- 			S1.NIEDERLASSUNG AS NL,
		-- 			S1.U_VERSION,
		-- 			S1.U_TIME,
		-- 			S1.LEISTUNGSDATUM AS LST_D,
		-- 			S1.RELATION AS TA_REL,
		-- 			REG.REGION AS TA_REGION,
		-- 			--NULLIF(rtrim(reg.region_bez), ''::text) AS ta_region_t,
		-- 			--pta.getstatus(s1.sendung_tix) AS status,
		-- 			--pta.getstatus(s1.sendung_tix, pta_lib.getstatusrange_mp4())::numeric(22,0) AS status_mp4,
		-- 			S1.STATUS_FRB,
		-- 			S1.STATUS_ABF,
		-- 			S1.STATUS_DIS,
		-- 			--pta.fgetmdestatus(s1.sendung_tix) AS status_mde,
		-- 			S1.FAKTUR_FREIGABE AS FAKTUR_FRG,
		-- 			S1.TRAN_ART AS VK_ART,
		-- 			P.PERS_TIX AS UNT_TIX,
		-- 			P.PERS_N AS UNT_N,
		-- 			P.PERS_I AS UNT_I,
		-- 			P.NAME1 AS UNT_NAME1,
		-- 			P.NAME2 AS UNT_NAME2,
		-- 			P.NAME3 AS UNT_NAME3,
		-- 			P.MATCH AS UNT_MATCH,
		-- 			P.ADR_ART AS UNT_ADR_ART,
		-- 			P.STR AS UNT_STR,
		-- 			P.SITZ_LAND AS UNT_LAND,
		-- 			P.SITZ_PLZ AS UNT_PLZ,
		-- 			P.SITZ_ORT AS UNT_ORT,
		-- 			P.SITZ_BEZ AS UNT_BEZ,
		-- 			P.SITZ_ORT_TIX AS UNT_ORT_TIX,
		-- 			U.LKW_TIX,
		-- 			U.LKW_K,
		-- 			U.LKW_AMTL_K,
		-- 			U.LKW_PLOMBE_K,
		-- 			U.ANH_TIX,
		-- 			U.ANH_K,
		-- 			U.ANH_AMTL_K,
		-- 			U.ANH_PLOMBE_K,
		-- 			U.FAHRER_N,
		-- 			U.FAHRER_NAME,
		-- 			U.BEIFAH_N,
		-- 			U.BEIFAH_NAME,
		-- 			U.STELLPLATZ_C AS LKW_STELLPLATZ_C,
		-- 			U.GEW AS LKW_GEW,
		-- 			U.VERTRAUEN_B,
		-- 			U.MOBIL_TEL_N,
		-- 			U.MOBIL_TEL_N2,
		-- 			U.LKW_WB_K,
		-- 			U.LKW_WB_ID,
		-- 			U.ANH_WB_K,
		-- 			U.ANH_WB_ID
		-- 			--substr(pta.getbeladtor(s1.sendung_tix)::text, 1, 255) AS belad_tor,
		-- 			--pta.getabfahrtsolle(s1.sendung_tix) AS soll_abfahrt_e,
		-- 			--pta.getbelad_c(s1.sendung_tix) AS belad_c,
		-- 			--pta.getentl_c(s1.sendung_tix) AS entl_c,
		-- 			--substr(pta.getkammerinfo(s1.sendung_tix)::text, 1, 255) AS kammer_t,
		-- 			--pta.getkammerc(s1.sendung_tix) AS kammer_c,
		-- 			--substr(pta.getentlinfo(s1.sendung_tix)::text, 1, 255) AS entl_info,
		-- 			--substr(pta.getrelinfo(s1.sendung_tix)::text, 1, 255) AS rel_info,
		-- 			--substr(pta.getinfo(s1.sendung_tix, 'TA1'::character varying)::text, 1, 255) AS ta_info1,
		-- 			--substr(pta.getinfo(s1.sendung_tix, 'SAI'::character varying)::text, 1, 255) AS ta_info2,
		-- 			--pta.getvolstpl_c(s1.sendung_tix) AS stellplatz_c,
		-- 			--pta.getvolstpl_c(s1.sendung_tix) AS volstpl_c,
		-- 			--pta.getbodenstpl_c(s1.sendung_tix) AS bodenstpl_c,
		-- 			--pta.getcolli_c(s1.sendung_tix) AS lhm_c,
		-- 			--pta.getgew(s1.sendung_tix) AS gew,
		-- 			--pta.getfrachtunfg(s1.sendung_tix, s1.leistungsdatum, pta.getuntw(s1.sendung_tix)) AS fracht_g,
		-- 			--pta.getmautunfg(s1.sendung_tix, s1.leistungsdatum, pta.getuntw(s1.sendung_tix)) AS maut_g,
		-- 			--pta.getunfg(s1.sendung_tix, s1.leistungsdatum, pta.getuntw(s1.sendung_tix)) AS ges_g,
		-- 			--pta.getuntw(s1.sendung_tix)::character(3) AS w,
		-- 			--pta.getfrachtunfg(s1.sendung_tix, s1.leistungsdatum) AS firma_fracht_g,
		-- 			--pta.getmautunfg(s1.sendung_tix, s1.leistungsdatum) AS firma_maut_g,
		-- 			--pta.getunfg(s1.sendung_tix, s1.leistungsdatum) AS firma_ges_g,
		-- 			--pta.getfirmaw()::character(3) AS firma_w,
		-- 			--NULLIF(rtrim(s1.verkehrsstrom), ''::text)::character varying(3) AS vk_strom,
		-- 			--pta.getstatus(s1.sendung_tix, pta_lib.getstatusrange_autoabf())::numeric(22,0) AS status_autoabf
		-- 		FROM
		-- 			SENDUNG S1
		-- 			LEFT JOIN RELATION REL ON S1.RELATION = REL.KZ_RELATION
		-- 			AND S1.FIRMA = REL.FIRMENNUMMER
		-- 			AND S1.NIEDERLASSUNG = REL.NIEDERLASSUNG
		-- 			LEFT JOIN REGION REG ON REL.REGION = REG.REGION
		-- 			AND REL.FIRMENNUMMER = REG.FIRMA
		-- 			AND REL.NIEDERLASSUNG = REG.NIEDERLASSUNG
		-- 			AND REG.VERKEHR_K = 'F'::BPCHAR
		-- 			LEFT JOIN SEN_FRK_UNT U ON U.SEN_TIX = S1.SENDUNG_TIX
		-- 			AND U.LFD_N = 1::NUMERIC
		-- 			LEFT JOIN V_PERS_NOREGION P ON U.UNT_TIX = P.TIX
		-- 		WHERE
		-- 			S1.SENDUNGSART = ANY (ARRAY['S'::BPCHAR, 's'::BPCHAR])
		-- 		ORDER BY
		-- 			TA_FIX_KEY
		-- 	) AS V_DIS_TRANSPORTORDER_FILTER
		-- WHERE
		-- 	TA_REGION = 'NL'
		-- 	AND U_TIME >= '2024-11-01'
	);



EXPLAIN ANALYZE
SELECT TRANSPORTORDERID, TRANSPORTORDERNUMBER
FROM TMS1034.V_DIS_TRANSPORTORDER
WHERE TRANSPORTORDERID IN (
    SELECT TA_TIX FROM (
         SELECT
			TA_TIX
		FROM
			(
				-- THIS WOULD BE THE NEW V_DIS_TRANSPORT_ORDER_COUNT			
				SELECT
					S1.SENDUNG_TIX AS TA_TIX,
					S1.SENDUNG_N AS TA_N,
					S1.FIX_KEY AS TA_FIX_KEY,
					S1.SENDUNGSART AS TA_ART,
					S1.FIRMA,
					S1.NIEDERLASSUNG AS NL,
					S1.U_VERSION,
					S1.U_TIME,
					S1.LEISTUNGSDATUM AS LST_D,
					S1.RELATION AS TA_REL,
					REG.REGION AS TA_REGION,
					--NULLIF(rtrim(reg.region_bez), ''::text) AS ta_region_t,
					--pta.getstatus(s1.sendung_tix) AS status,
					--pta.getstatus(s1.sendung_tix, pta_lib.getstatusrange_mp4())::numeric(22,0) AS status_mp4,
					S1.STATUS_FRB,
					S1.STATUS_ABF,
					S1.STATUS_DIS,
					--pta.fgetmdestatus(s1.sendung_tix) AS status_mde,
					S1.FAKTUR_FREIGABE AS FAKTUR_FRG,
					S1.TRAN_ART AS VK_ART,
					P.PERS_TIX AS UNT_TIX,
					P.PERS_N AS UNT_N,
					P.PERS_I AS UNT_I,
					P.NAME1 AS UNT_NAME1,
					P.NAME2 AS UNT_NAME2,
					P.NAME3 AS UNT_NAME3,
					P.MATCH AS UNT_MATCH,
					P.ADR_ART AS UNT_ADR_ART,
					P.STR AS UNT_STR,
					P.SITZ_LAND AS UNT_LAND,
					P.SITZ_PLZ AS UNT_PLZ,
					P.SITZ_ORT AS UNT_ORT,
					P.SITZ_BEZ AS UNT_BEZ,
					P.SITZ_ORT_TIX AS UNT_ORT_TIX,
					U.LKW_TIX,
					U.LKW_K,
					U.LKW_AMTL_K,
					U.LKW_PLOMBE_K,
					U.ANH_TIX,
					U.ANH_K,
					U.ANH_AMTL_K,
					U.ANH_PLOMBE_K,
					U.FAHRER_N,
					U.FAHRER_NAME,
					U.BEIFAH_N,
					U.BEIFAH_NAME,
					U.STELLPLATZ_C AS LKW_STELLPLATZ_C,
					U.GEW AS LKW_GEW,
					U.VERTRAUEN_B,
					U.MOBIL_TEL_N,
					U.MOBIL_TEL_N2,
					U.LKW_WB_K,
					U.LKW_WB_ID,
					U.ANH_WB_K,
					U.ANH_WB_ID
					--substr(pta.getbeladtor(s1.sendung_tix)::text, 1, 255) AS belad_tor,
					--pta.getabfahrtsolle(s1.sendung_tix) AS soll_abfahrt_e,
					--pta.getbelad_c(s1.sendung_tix) AS belad_c,
					--pta.getentl_c(s1.sendung_tix) AS entl_c,
					--substr(pta.getkammerinfo(s1.sendung_tix)::text, 1, 255) AS kammer_t,
					--pta.getkammerc(s1.sendung_tix) AS kammer_c,
					--substr(pta.getentlinfo(s1.sendung_tix)::text, 1, 255) AS entl_info,
					--substr(pta.getrelinfo(s1.sendung_tix)::text, 1, 255) AS rel_info,
					--substr(pta.getinfo(s1.sendung_tix, 'TA1'::character varying)::text, 1, 255) AS ta_info1,
					--substr(pta.getinfo(s1.sendung_tix, 'SAI'::character varying)::text, 1, 255) AS ta_info2,
					--pta.getvolstpl_c(s1.sendung_tix) AS stellplatz_c,
					--pta.getvolstpl_c(s1.sendung_tix) AS volstpl_c,
					--pta.getbodenstpl_c(s1.sendung_tix) AS bodenstpl_c,
					--pta.getcolli_c(s1.sendung_tix) AS lhm_c,
					--pta.getgew(s1.sendung_tix) AS gew,
					--pta.getfrachtunfg(s1.sendung_tix, s1.leistungsdatum, pta.getuntw(s1.sendung_tix)) AS fracht_g,
					--pta.getmautunfg(s1.sendung_tix, s1.leistungsdatum, pta.getuntw(s1.sendung_tix)) AS maut_g,
					--pta.getunfg(s1.sendung_tix, s1.leistungsdatum, pta.getuntw(s1.sendung_tix)) AS ges_g,
					--pta.getuntw(s1.sendung_tix)::character(3) AS w,
					--pta.getfrachtunfg(s1.sendung_tix, s1.leistungsdatum) AS firma_fracht_g,
					--pta.getmautunfg(s1.sendung_tix, s1.leistungsdatum) AS firma_maut_g,
					--pta.getunfg(s1.sendung_tix, s1.leistungsdatum) AS firma_ges_g,
					--pta.getfirmaw()::character(3) AS firma_w,
					--NULLIF(rtrim(s1.verkehrsstrom), ''::text)::character varying(3) AS vk_strom,
					--pta.getstatus(s1.sendung_tix, pta_lib.getstatusrange_autoabf())::numeric(22,0) AS status_autoabf
				FROM
					SENDUNG S1
					LEFT JOIN RELATION REL ON S1.RELATION = REL.KZ_RELATION
					AND S1.FIRMA = REL.FIRMENNUMMER
					AND S1.NIEDERLASSUNG = REL.NIEDERLASSUNG
					LEFT JOIN REGION REG ON REL.REGION = REG.REGION
					AND REL.FIRMENNUMMER = REG.FIRMA
					AND REL.NIEDERLASSUNG = REG.NIEDERLASSUNG
					AND REG.VERKEHR_K = 'F'::BPCHAR
					LEFT JOIN SEN_FRK_UNT U ON U.SEN_TIX = S1.SENDUNG_TIX
					AND U.LFD_N = 1::NUMERIC
					LEFT JOIN V_PERS_NOREGION P ON U.UNT_TIX = P.TIX
				WHERE
					S1.SENDUNGSART = ANY (ARRAY['S'::BPCHAR, 's'::BPCHAR])
				ORDER BY
					TA_FIX_KEY
			) AS V_DIS_TRANSPORTORDER_FILTER
		WHERE
			TA_REGION = 'NL'
			AND U_TIME >= '2024-11-01'
    ) AS V_DIS_TRANSPORTORDER_FILTER
);



SELECT
	T.*
FROM
	TMS1034.V_DIS_TRANSPORTORDER T
	JOIN (
		SELECT
			S1.SENDUNG_TIX AS TA_TIX,
			S1.SENDUNG_N AS TA_N,
			S1.FIX_KEY AS TA_FIX_KEY,
			S1.SENDUNGSART AS TA_ART,
			S1.FIRMA,
			S1.NIEDERLASSUNG AS NL,
			S1.U_VERSION,
			S1.U_TIME,
			S1.LEISTUNGSDATUM AS LST_D,
			S1.RELATION AS TA_REL,
			REG.REGION AS TA_REGION,
			--NULLIF(rtrim(reg.region_bez), ''::text) AS ta_region_t,
			--pta.getstatus(s1.sendung_tix) AS status,
			--pta.getstatus(s1.sendung_tix, pta_lib.getstatusrange_mp4())::numeric(22,0) AS status_mp4,
			S1.STATUS_FRB,
			S1.STATUS_ABF,
			S1.STATUS_DIS,
			--pta.fgetmdestatus(s1.sendung_tix) AS status_mde,
			S1.FAKTUR_FREIGABE AS FAKTUR_FRG,
			S1.TRAN_ART AS VK_ART,
			P.PERS_TIX AS UNT_TIX,
			P.PERS_N AS UNT_N,
			P.PERS_I AS UNT_I,
			P.NAME1 AS UNT_NAME1,
			P.NAME2 AS UNT_NAME2,
			P.NAME3 AS UNT_NAME3,
			P.MATCH AS UNT_MATCH,
			P.ADR_ART AS UNT_ADR_ART,
			P.STR AS UNT_STR,
			P.SITZ_LAND AS UNT_LAND,
			P.SITZ_PLZ AS UNT_PLZ,
			P.SITZ_ORT AS UNT_ORT,
			P.SITZ_BEZ AS UNT_BEZ,
			P.SITZ_ORT_TIX AS UNT_ORT_TIX,
			U.LKW_TIX,
			U.LKW_K,
			U.LKW_AMTL_K,
			U.LKW_PLOMBE_K,
			U.ANH_TIX,
			U.ANH_K,
			U.ANH_AMTL_K,
			U.ANH_PLOMBE_K,
			U.FAHRER_N,
			U.FAHRER_NAME,
			U.BEIFAH_N,
			U.BEIFAH_NAME,
			U.STELLPLATZ_C AS LKW_STELLPLATZ_C,
			U.GEW AS LKW_GEW,
			U.VERTRAUEN_B,
			U.MOBIL_TEL_N,
			U.MOBIL_TEL_N2,
			U.LKW_WB_K,
			U.LKW_WB_ID,
			U.ANH_WB_K,
			U.ANH_WB_ID
			--substr(pta.getbeladtor(s1.sendung_tix)::text, 1, 255) AS belad_tor,
			--pta.getabfahrtsolle(s1.sendung_tix) AS soll_abfahrt_e,
			--pta.getbelad_c(s1.sendung_tix) AS belad_c,
			--pta.getentl_c(s1.sendung_tix) AS entl_c,
			--substr(pta.getkammerinfo(s1.sendung_tix)::text, 1, 255) AS kammer_t,
			--pta.getkammerc(s1.sendung_tix) AS kammer_c,
			--substr(pta.getentlinfo(s1.sendung_tix)::text, 1, 255) AS entl_info,
			--substr(pta.getrelinfo(s1.sendung_tix)::text, 1, 255) AS rel_info,
			--substr(pta.getinfo(s1.sendung_tix, 'TA1'::character varying)::text, 1, 255) AS ta_info1,
			--substr(pta.getinfo(s1.sendung_tix, 'SAI'::character varying)::text, 1, 255) AS ta_info2,
			--pta.getvolstpl_c(s1.sendung_tix) AS stellplatz_c,
			--pta.getvolstpl_c(s1.sendung_tix) AS volstpl_c,
			--pta.getbodenstpl_c(s1.sendung_tix) AS bodenstpl_c,
			--pta.getcolli_c(s1.sendung_tix) AS lhm_c,
			--pta.getgew(s1.sendung_tix) AS gew,
			--pta.getfrachtunfg(s1.sendung_tix, s1.leistungsdatum, pta.getuntw(s1.sendung_tix)) AS fracht_g,
			--pta.getmautunfg(s1.sendung_tix, s1.leistungsdatum, pta.getuntw(s1.sendung_tix)) AS maut_g,
			--pta.getunfg(s1.sendung_tix, s1.leistungsdatum, pta.getuntw(s1.sendung_tix)) AS ges_g,
			--pta.getuntw(s1.sendung_tix)::character(3) AS w,
			--pta.getfrachtunfg(s1.sendung_tix, s1.leistungsdatum) AS firma_fracht_g,
			--pta.getmautunfg(s1.sendung_tix, s1.leistungsdatum) AS firma_maut_g,
			--pta.getunfg(s1.sendung_tix, s1.leistungsdatum) AS firma_ges_g,
			--pta.getfirmaw()::character(3) AS firma_w,
			--NULLIF(rtrim(s1.verkehrsstrom), ''::text)::character varying(3) AS vk_strom,
			--pta.getstatus(s1.sendung_tix, pta_lib.getstatusrange_autoabf())::numeric(22,0) AS status_autoabf
		FROM
			SENDUNG S1
			LEFT JOIN RELATION REL ON S1.RELATION = REL.KZ_RELATION
			AND S1.FIRMA = REL.FIRMENNUMMER
			AND S1.NIEDERLASSUNG = REL.NIEDERLASSUNG
			LEFT JOIN REGION REG ON REL.REGION = REG.REGION
			AND REL.FIRMENNUMMER = REG.FIRMA
			AND REL.NIEDERLASSUNG = REG.NIEDERLASSUNG
			AND REG.VERKEHR_K = 'F'::BPCHAR
			LEFT JOIN SEN_FRK_UNT U ON U.SEN_TIX = S1.SENDUNG_TIX
			AND U.LFD_N = 1::NUMERIC
			LEFT JOIN V_PERS_NOREGION P ON U.UNT_TIX = P.TIX
		WHERE
			S1.SENDUNGSART = ANY (ARRAY['S'::BPCHAR, 's'::BPCHAR])
		ORDER BY
			TA_FIX_KEY
	) AS V_DIS_TRANSPORTORDER_FILTER ON T.TRANSPORTORDERID = V_DIS_TRANSPORTORDER_FILTER.TA_TIX
WHERE
	V_DIS_TRANSPORTORDER_FILTER.TA_REGION = 'NL'
	AND V_DIS_TRANSPORTORDER_FILTER.U_TIME >= '2024-11-01';


WITH
	FILTEREDRESULTS AS (
		SELECT
			TA_TIX
		FROM
			(
				SELECT
					S1.SENDUNG_TIX AS TA_TIX,
					S1.SENDUNG_N AS TA_N,
					S1.FIX_KEY AS TA_FIX_KEY,
					S1.SENDUNGSART AS TA_ART,
					S1.FIRMA,
					S1.NIEDERLASSUNG AS NL,
					S1.U_VERSION,
					S1.U_TIME,
					S1.LEISTUNGSDATUM AS LST_D,
					S1.RELATION AS TA_REL,
					REG.REGION AS TA_REGION,
					--NULLIF(rtrim(reg.region_bez), ''::text) AS ta_region_t,
					--pta.getstatus(s1.sendung_tix) AS status,
					--pta.getstatus(s1.sendung_tix, pta_lib.getstatusrange_mp4())::numeric(22,0) AS status_mp4,
					S1.STATUS_FRB,
					S1.STATUS_ABF,
					S1.STATUS_DIS,
					--pta.fgetmdestatus(s1.sendung_tix) AS status_mde,
					S1.FAKTUR_FREIGABE AS FAKTUR_FRG,
					S1.TRAN_ART AS VK_ART,
					P.PERS_TIX AS UNT_TIX,
					P.PERS_N AS UNT_N,
					P.PERS_I AS UNT_I,
					P.NAME1 AS UNT_NAME1,
					P.NAME2 AS UNT_NAME2,
					P.NAME3 AS UNT_NAME3,
					P.MATCH AS UNT_MATCH,
					P.ADR_ART AS UNT_ADR_ART,
					P.STR AS UNT_STR,
					P.SITZ_LAND AS UNT_LAND,
					P.SITZ_PLZ AS UNT_PLZ,
					P.SITZ_ORT AS UNT_ORT,
					P.SITZ_BEZ AS UNT_BEZ,
					P.SITZ_ORT_TIX AS UNT_ORT_TIX,
					U.LKW_TIX,
					U.LKW_K,
					U.LKW_AMTL_K,
					U.LKW_PLOMBE_K,
					U.ANH_TIX,
					U.ANH_K,
					U.ANH_AMTL_K,
					U.ANH_PLOMBE_K,
					U.FAHRER_N,
					U.FAHRER_NAME,
					U.BEIFAH_N,
					U.BEIFAH_NAME,
					U.STELLPLATZ_C AS LKW_STELLPLATZ_C,
					U.GEW AS LKW_GEW,
					U.VERTRAUEN_B,
					U.MOBIL_TEL_N,
					U.MOBIL_TEL_N2,
					U.LKW_WB_K,
					U.LKW_WB_ID,
					U.ANH_WB_K,
					U.ANH_WB_ID
					--substr(pta.getbeladtor(s1.sendung_tix)::text, 1, 255) AS belad_tor,
					--pta.getabfahrtsolle(s1.sendung_tix) AS soll_abfahrt_e,
					--pta.getbelad_c(s1.sendung_tix) AS belad_c,
					--pta.getentl_c(s1.sendung_tix) AS entl_c,
					--substr(pta.getkammerinfo(s1.sendung_tix)::text, 1, 255) AS kammer_t,
					--pta.getkammerc(s1.sendung_tix) AS kammer_c,
					--substr(pta.getentlinfo(s1.sendung_tix)::text, 1, 255) AS entl_info,
					--substr(pta.getrelinfo(s1.sendung_tix)::text, 1, 255) AS rel_info,
					--substr(pta.getinfo(s1.sendung_tix, 'TA1'::character varying)::text, 1, 255) AS ta_info1,
					--substr(pta.getinfo(s1.sendung_tix, 'SAI'::character varying)::text, 1, 255) AS ta_info2,
					--pta.getvolstpl_c(s1.sendung_tix) AS stellplatz_c,
					--pta.getvolstpl_c(s1.sendung_tix) AS volstpl_c,
					--pta.getbodenstpl_c(s1.sendung_tix) AS bodenstpl_c,
					--pta.getcolli_c(s1.sendung_tix) AS lhm_c,
					--pta.getgew(s1.sendung_tix) AS gew,
					--pta.getfrachtunfg(s1.sendung_tix, s1.leistungsdatum, pta.getuntw(s1.sendung_tix)) AS fracht_g,
					--pta.getmautunfg(s1.sendung_tix, s1.leistungsdatum, pta.getuntw(s1.sendung_tix)) AS maut_g,
					--pta.getunfg(s1.sendung_tix, s1.leistungsdatum, pta.getuntw(s1.sendung_tix)) AS ges_g,
					--pta.getuntw(s1.sendung_tix)::character(3) AS w,
					--pta.getfrachtunfg(s1.sendung_tix, s1.leistungsdatum) AS firma_fracht_g,
					--pta.getmautunfg(s1.sendung_tix, s1.leistungsdatum) AS firma_maut_g,
					--pta.getunfg(s1.sendung_tix, s1.leistungsdatum) AS firma_ges_g,
					--pta.getfirmaw()::character(3) AS firma_w,
					--NULLIF(rtrim(s1.verkehrsstrom), ''::text)::character varying(3) AS vk_strom,
					--pta.getstatus(s1.sendung_tix, pta_lib.getstatusrange_autoabf())::numeric(22,0) AS status_autoabf
				FROM
					SENDUNG S1
					LEFT JOIN RELATION REL ON S1.RELATION = REL.KZ_RELATION
					AND S1.FIRMA = REL.FIRMENNUMMER
					AND S1.NIEDERLASSUNG = REL.NIEDERLASSUNG
					LEFT JOIN REGION REG ON REL.REGION = REG.REGION
					AND REL.FIRMENNUMMER = REG.FIRMA
					AND REL.NIEDERLASSUNG = REG.NIEDERLASSUNG
					AND REG.VERKEHR_K = 'F'::BPCHAR
					LEFT JOIN SEN_FRK_UNT U ON U.SEN_TIX = S1.SENDUNG_TIX
					AND U.LFD_N = 1::NUMERIC
					LEFT JOIN V_PERS_NOREGION P ON U.UNT_TIX = P.TIX
				WHERE
					S1.SENDUNGSART = ANY (ARRAY['S'::BPCHAR, 's'::BPCHAR])
				ORDER BY
					TA_FIX_KEY
			) AS V_DIS_TRANSPORTORDER_FILTER
		WHERE
			TA_REGION = 'NL'
			AND U_TIME >= '2024-11-01'
	)
SELECT
	TRANSPORTORDERID,
	TRANSPORTORDERNUMBER
FROM
	TMS1034.V_DIS_TRANSPORTORDER
WHERE
	TRANSPORTORDERID IN (
		SELECT
			TA_TIX
		FROM
			FILTEREDRESULTS
	);


SELECT
	TRANSPORTORDERID,
	TRANSPORTORDERNUMBER,
	COMPANY,
	BRANCH,
	LOADINGDATE,
	REGIONID,
	REGION,
	TRANSPORTMODE,
	STATUS,
	CONTRACTORID,
	CONTRACTORNUMBER,
	CONTRACTORINDEX,
	CONTRACTORNAME1,
	CONTRACTORNAME2,
	CONTRACTORNAME3,
	CONTRACTORMATCHCODE,
	CONTRACTORPARTICIPANTTYPE,
	CONTRACTORSTREET,
	CONTRACTORCOUNTRY,
	CONTRACTORPOSTALCODE,
	CONTRACTORCITY,
	CONTRACTORDISTRICT,
	CONTRACTORADDRESSID,
	TRUCKID,
	TRUCKMATCHCODEID,
	TRUCKLICENSEPLATE,
	TRUCKSEALID,
	TRAILERID,
	TRAILERMATCHCODEID,
	TRAILERLICENSEPLATE,
	TRAILERSEALID,
	DRIVERID,
	DRIVERNAME,
	CODRIVERID,
	CODRIVERNAME,
	VEHICLEPALLETSPACES,
	VEHICLEWEIGHT,
	GATEID,
	PLANNEDDEPARTURETIME,
	PICKUPLOCATIONSSUM,
	DELIVERYLOCATIONSSUM,
	CHAMBERSSUM,
	UNLOADINGINFO,
	SERVICEAREAINFO,
	PLANNEDPALLETSPACES,
	PLANNEDVOLUMEPALLETSPACES,
	PLANNEDFLOORPALLETSPACES,
	LOADINGAIDSSUM,
	WEIGHT,
	FREIGHTCOSTS,
	TOLLCOSTS,
	TOTALCOSTS,
	CURRENCY,
	COMPANYFREIGHTCOSTS,
	COMPANYTOLLCOSTS,
	COMPANYTOTALCOSTS,
	COMPANYCURRENCY
FROM
	TMS1034.V_DIS_TRANSPORTORDER
WHERE
	TRANSPORTORDERID = ANY (
		ARRAY(
			SELECT
				TA_TIX
			FROM
				(
					-- THIS WOULD BE THE NEW V_DIS_TRANSPORT_ORDER_COUNT			
					SELECT
						S1.SENDUNG_TIX AS TA_TIX,
						S1.SENDUNG_N AS TA_N,
						S1.FIX_KEY AS TA_FIX_KEY,
						S1.SENDUNGSART AS TA_ART,
						S1.FIRMA,
						S1.NIEDERLASSUNG AS NL,
						S1.U_VERSION,
						S1.U_TIME,
						S1.LEISTUNGSDATUM AS LST_D,
						S1.RELATION AS TA_REL,
						REG.REGION AS TA_REGION,
						--NULLIF(rtrim(reg.region_bez), ''::text) AS ta_region_t,
						--pta.getstatus(s1.sendung_tix) AS status,
						--pta.getstatus(s1.sendung_tix, pta_lib.getstatusrange_mp4())::numeric(22,0) AS status_mp4,
						S1.STATUS_FRB,
						S1.STATUS_ABF,
						S1.STATUS_DIS,
						--pta.fgetmdestatus(s1.sendung_tix) AS status_mde,
						S1.FAKTUR_FREIGABE AS FAKTUR_FRG,
						S1.TRAN_ART AS VK_ART,
						P.PERS_TIX AS UNT_TIX,
						P.PERS_N AS UNT_N,
						P.PERS_I AS UNT_I,
						P.NAME1 AS UNT_NAME1,
						P.NAME2 AS UNT_NAME2,
						P.NAME3 AS UNT_NAME3,
						P.MATCH AS UNT_MATCH,
						P.ADR_ART AS UNT_ADR_ART,
						P.STR AS UNT_STR,
						P.SITZ_LAND AS UNT_LAND,
						P.SITZ_PLZ AS UNT_PLZ,
						P.SITZ_ORT AS UNT_ORT,
						P.SITZ_BEZ AS UNT_BEZ,
						P.SITZ_ORT_TIX AS UNT_ORT_TIX,
						U.LKW_TIX,
						U.LKW_K,
						U.LKW_AMTL_K,
						U.LKW_PLOMBE_K,
						U.ANH_TIX,
						U.ANH_K,
						U.ANH_AMTL_K,
						U.ANH_PLOMBE_K,
						U.FAHRER_N,
						U.FAHRER_NAME,
						U.BEIFAH_N,
						U.BEIFAH_NAME,
						U.STELLPLATZ_C AS LKW_STELLPLATZ_C,
						U.GEW AS LKW_GEW,
						U.VERTRAUEN_B,
						U.MOBIL_TEL_N,
						U.MOBIL_TEL_N2,
						U.LKW_WB_K,
						U.LKW_WB_ID,
						U.ANH_WB_K,
						U.ANH_WB_ID
						--substr(pta.getbeladtor(s1.sendung_tix)::text, 1, 255) AS belad_tor,
						--pta.getabfahrtsolle(s1.sendung_tix) AS soll_abfahrt_e,
						--pta.getbelad_c(s1.sendung_tix) AS belad_c,
						--pta.getentl_c(s1.sendung_tix) AS entl_c,
						--substr(pta.getkammerinfo(s1.sendung_tix)::text, 1, 255) AS kammer_t,
						--pta.getkammerc(s1.sendung_tix) AS kammer_c,
						--substr(pta.getentlinfo(s1.sendung_tix)::text, 1, 255) AS entl_info,
						--substr(pta.getrelinfo(s1.sendung_tix)::text, 1, 255) AS rel_info,
						--substr(pta.getinfo(s1.sendung_tix, 'TA1'::character varying)::text, 1, 255) AS ta_info1,
						--substr(pta.getinfo(s1.sendung_tix, 'SAI'::character varying)::text, 1, 255) AS ta_info2,
						--pta.getvolstpl_c(s1.sendung_tix) AS stellplatz_c,
						--pta.getvolstpl_c(s1.sendung_tix) AS volstpl_c,
						--pta.getbodenstpl_c(s1.sendung_tix) AS bodenstpl_c,
						--pta.getcolli_c(s1.sendung_tix) AS lhm_c,
						--pta.getgew(s1.sendung_tix) AS gew,
						--pta.getfrachtunfg(s1.sendung_tix, s1.leistungsdatum, pta.getuntw(s1.sendung_tix)) AS fracht_g,
						--pta.getmautunfg(s1.sendung_tix, s1.leistungsdatum, pta.getuntw(s1.sendung_tix)) AS maut_g,
						--pta.getunfg(s1.sendung_tix, s1.leistungsdatum, pta.getuntw(s1.sendung_tix)) AS ges_g,
						--pta.getuntw(s1.sendung_tix)::character(3) AS w,
						--pta.getfrachtunfg(s1.sendung_tix, s1.leistungsdatum) AS firma_fracht_g,
						--pta.getmautunfg(s1.sendung_tix, s1.leistungsdatum) AS firma_maut_g,
						--pta.getunfg(s1.sendung_tix, s1.leistungsdatum) AS firma_ges_g,
						--pta.getfirmaw()::character(3) AS firma_w,
						--NULLIF(rtrim(s1.verkehrsstrom), ''::text)::character varying(3) AS vk_strom,
						--pta.getstatus(s1.sendung_tix, pta_lib.getstatusrange_autoabf())::numeric(22,0) AS status_autoabf
					FROM
						SENDUNG S1
						LEFT JOIN RELATION REL ON S1.RELATION = REL.KZ_RELATION
						AND S1.FIRMA = REL.FIRMENNUMMER
						AND S1.NIEDERLASSUNG = REL.NIEDERLASSUNG
						LEFT JOIN REGION REG ON REL.REGION = REG.REGION
						AND REL.FIRMENNUMMER = REG.FIRMA
						AND REL.NIEDERLASSUNG = REG.NIEDERLASSUNG
						AND REG.VERKEHR_K = 'F'::BPCHAR
						LEFT JOIN SEN_FRK_UNT U ON U.SEN_TIX = S1.SENDUNG_TIX
						AND U.LFD_N = 1::NUMERIC
						LEFT JOIN V_PERS_NOREGION P ON U.UNT_TIX = P.TIX
					WHERE
						S1.SENDUNGSART = ANY (ARRAY['S'::BPCHAR, 's'::BPCHAR])
					ORDER BY
						TA_FIX_KEY
				) AS V_DIS_TRANSPORTORDER_FILTER
			WHERE
				TA_REGION = 'NL'
				AND U_TIME >= '2024-11-01'
		)
	);