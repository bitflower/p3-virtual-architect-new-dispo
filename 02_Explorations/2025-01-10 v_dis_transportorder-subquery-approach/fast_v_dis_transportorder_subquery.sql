SELECT
	*
FROM
	TMS1034.V_DIS_TRANSPORTORDER
WHERE
	TRANSPORTORDERID = ANY (
		ARRAY(
			SELECT
				TA_TIX -- WE ONLY SELECT THE TIX FIELD BECAUSE IT'S THE "FILTER" DATA FOR THE PARENT VIEW SELECT
			FROM
				V_DIS_TRANSPORTORDER_FILTER
			WHERE
				-- HERE WE ACTUALLY FILTER (BUT ONLY ON THE FILEDS THE NEW VIEW HAS = REDUCED SET OF FILTERS! BUT STILL A VERY GOOD AMOUNT OF FIELDS .....)
				TA_REGION = 'NL'
				--AND U_TIME >= '2024-07-01'
			ORDER BY -- WE CAN STILL ORDER
				LST_D
			LIMIT -- AND PAGINATE
				10
			OFFSET
				45
		)
	)

-- RUNS FOREVER ....
SELECT
	*
FROM
	TMS1034.V_DIS_TRANSPORTORDER
WHERE
	regionid = 'NL' -- equals TA_REGION
ORDER BY
    loadingdate -- equals LST_D
LIMIT
	10
OFFSET
	45

 SELECT v_ta.ta_tix AS transportorderid,
    v_ta.ta_n AS transportordernumber,
    v_ta.firma AS company,
    v_ta.nl AS branch,
    v_ta.lst_d AS loadingdate,
    v_ta.ta_region AS regionid,
    v_ta.ta_region_t AS region,
    v_ta.vk_art AS transportmode,
    v_ta.status,
    v_ta.unt_tix AS contractorid,
    v_ta.unt_n AS contractornumber,
    v_ta.unt_i AS contractorindex,
    v_ta.unt_name1 AS contractorname1,
    v_ta.unt_name2 AS contractorname2,
    v_ta.unt_name3 AS contractorname3,
    v_ta.unt_match AS contractormatchcode,
    v_ta.unt_adr_art AS contractorparticipanttype,
    v_ta.unt_str AS contractorstreet,
    v_ta.unt_land AS contractorcountry,
    v_ta.unt_plz AS contractorpostalcode,
    v_ta.unt_ort AS contractorcity,
    v_ta.unt_bez AS contractordistrict,
    v_ta.unt_ort_tix AS contractoraddressid,
    v_ta.lkw_tix AS truckid,
    v_ta.lkw_k AS truckmatchcodeid,
    v_ta.lkw_amtl_k AS trucklicenseplate,
    v_ta.lkw_plombe_k AS trucksealid,
    v_ta.anh_tix AS trailerid,
    v_ta.anh_k AS trailermatchcodeid,
    v_ta.anh_amtl_k AS trailerlicenseplate,
    v_ta.anh_plombe_k AS trailersealid,
    v_ta.fahrer_n AS driverid,
    v_ta.fahrer_name AS drivername,
    v_ta.beifah_n AS codriverid,
    v_ta.beifah_name AS codrivername,
    v_ta.lkw_stellplatz_c AS vehiclepalletspaces,
    v_ta.lkw_gew AS vehicleweight,
    v_ta.belad_tor AS gateid,
    v_ta.soll_abfahrt_e AS planneddeparturetime,
    v_ta.belad_c AS pickuplocationssum,
    v_ta.entl_c AS deliverylocationssum,
    v_ta.kammer_c AS chamberssum,
    v_ta.entl_info AS unloadinginfo,
    v_ta.rel_info AS serviceareainfo,
    v_ta.stellplatz_c AS plannedpalletspaces,
    v_ta.volstpl_c AS plannedvolumepalletspaces,
    v_ta.bodenstpl_c AS plannedfloorpalletspaces,
    v_ta.lhm_c AS loadingaidssum,
    v_ta.gew AS weight,
    v_ta.fracht_g AS freightcosts,
    v_ta.maut_g AS tollcosts,
    v_ta.ges_g AS totalcosts,
    v_ta.w AS currency,
    v_ta.firma_fracht_g AS companyfreightcosts,
    v_ta.firma_maut_g AS companytollcosts,
    v_ta.firma_ges_g AS companytotalcosts,
    v_ta.firma_w AS companycurrency
   FROM v_ta;