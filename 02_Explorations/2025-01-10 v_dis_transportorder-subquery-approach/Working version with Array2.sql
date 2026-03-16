SELECT
	*
FROM
	TMS1034.V_DIS_TRANSPORTORDER
WHERE
	-- THE ANY IS CRUCIAL! (IN(), JOINS ETC don't work!)
	TRANSPORTORDERID = ANY (
		-- THE "ARRAY" IS KEY: It converts the results of the sub query into an actual array forcing the sub query to be executed FIRST!
	    ARRAY(
			SELECT
				TA_TIX -- WE ONLY SELECT THE TIX FIELD BECAUSE IT'S THE "FILTER" DATA FOR THE PARENT VIEW SELECT
			FROM
				(
					-- START: NEW V_DIS_TRANSPORT_ORDER_COUNT	(THIS CAN BE A REAL VIEW LATER ON, FOR THE DEMO IT'S INCLUDED IN THE MAIN QUERY STRING)	
					SELECT
						--S1.SENDUNG_TIX AS TA_TIX
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
						--NULLIF(rtrim(reg.region_bez), ''::text) AS ta_region_t, __ SOME FIELD NEED TO BE DISABLED HERE = THE "EXPENSIVE" ONES WITH FUNCTION CALLS
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
						--ORDER BY
						--TA_FIX_KEY
				) AS V_DIS_TRANSPORTORDER_FILTER -- WE GIVE THE INNER VIEW A NAME (ONLY NECEASSARY IN THIS INTEGRATED VERSION)
				-- END OF V_DIS_TRANSPORTORDER_FILTER
			WHERE
				-- HERE WE ACTUALLY FILTER (BUT ONLY ON THE FILEDS THE NEW VIEW HAS = REDUCED SET OF FILTERS! BUT STILL A VERY GOOD AMOUNT OF FIELDS .....)
				TA_REGION = 'NL'
				AND U_TIME >= '2024-07-01'
			ORDER BY -- WE CAN STILL ORDER
				LST_D -- CA. 200MS TO EXECUTE
			LIMIT -- AND PAGINATE
				5 -- LET'S START WITH 10 as it's STILL KINDA FAST
			OFFSET -- ... MORE PAGINATION
				45
		) -- END OF ARRAY()
	) -- CA 6s for a page size of 10, 3s for 5, 15s for 25
	AND loadingdate > '2024-01-09';