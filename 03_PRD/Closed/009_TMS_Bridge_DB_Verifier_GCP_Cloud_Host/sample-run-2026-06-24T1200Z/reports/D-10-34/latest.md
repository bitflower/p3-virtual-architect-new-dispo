# TMS Bridge DB Verification Report

| | |
|---|---|
| **Database** | abn1034 |
| **Schema** | tms1034 |
| **Provider** | PostgreSql |
| **Level** | All |
| **Timestamp** | 2026-06-24T12:00:10.9492779Z |
| **Duration** | 2.01s |
| **Result** | **FAILURES DETECTED** |

## Summary

| Level | Passed | Failed | Skipped |
|---|---:|---:|---:|
| Existence | 77 | 1 | 2 |
| Type | 76 | 1 | 3 |
| Signature | 43 | 1 | 36 |
| Permissions | 77 | 1 | 2 |

**Columns:** 33 objects checked, 625 OK, 0 missing
**Drift:** 18 objects with drift (551 extra columns total)

## Results

### Tables (11)

| Object | Status | Details |
|---|---|---|
| tms1034.bordero | PASS | drift: 31 extra |
| tms1034.fahrer | PASS |  |
| tms1034.ort | PASS | drift: 17 extra |
| tms1034.person | PASS | drift: 108 extra |
| tms1034.pst_hst | PASS | drift: 14 extra |
| tms1034.rollkart | PASS | drift: 32 extra |
| tms1034.sen_ls_pst | PASS | drift: 3 extra |
| tms1034.sen_ls_ref | PASS | drift: 6 extra |
| tms1034.sen_ref | PASS | drift: 6 extra |
| tms1034.sen_zuord | PASS | drift: 6 extra |
| tms1034.sendung | PASS | drift: 170 extra |

### Views (22)

| Object | Status | Details |
|---|---|---|
| tms1034.v_dis_branch_address | PASS |  |
| tms1034.v_dis_contact_details | PASS | drift: 34 extra |
| tms1034.v_dis_freight_exchange_tp | PASS |  |
| tms1034.v_dis_leg | PASS |  |
| tms1034.v_dis_shipment | PASS |  |
| tms1034.v_dis_shipment_all | PASS |  |
| tms1034.v_dis_to_features | PASS |  |
| tms1034.v_dis_to_filter | PASS |  |
| tms1034.v_dis_to_pickupplanning | PASS |  |
| tms1034.v_dis_to_presettemp | PASS |  |
| tms1034.v_dis_to_tourpoint | PASS | drift: 1 extra |
| tms1034.v_dis_to_tp_target_dates | PASS |  |
| tms1034.v_dis_to_tp_tour_number | PASS |  |
| tms1034.v_dis_tp_client_comm | PASS |  |
| tms1034.v_dis_transportorder | PASS | drift: 2 extra |
| tms1034.v_ebv_delivery_note | PASS |  |
| tms1034.v_ebv_leg | PASS |  |
| tms1034.v_ebv_participant | PASS | drift: 1 extra |
| tms1034.v_ebv_service | PASS | drift: 2 extra |
| tms1034.v_ebv_shipment | PASS | drift: 1 extra |
| tms1034.v_pers_tb | PASS | drift: 42 extra |
| tms1034.v_sen_ls | PASS | drift: 75 extra |

### Functions (7)

| Object | Status | Details |
|---|---|---|
| cal_uniface.item | PASS |  |
| pdis_leg.getstaysloadedstatus | PASS |  |
| pdis_transportorder.createtransportorderfromshipment | SKIP | deprecated |
| pdis_transportorder.geterrormessage | PASS |  |
| pdis_transportorder.getxserverdto | PASS |  |
| pdis_transportorder.setxserverdto | PASS |  |
| pdis_transportorderdto.get | PASS |  |

### Table Functions (1)

| Object | Status | Details |
|---|---|---|
| cal_uniface.list2dbtt | FAIL | type: expected TableFunction, got Function |

### Procedures (38)

| Object | Status | Details |
|---|---|---|
| disp_mde_ah.abschlnve | FAIL | sig mismatch (got 6 args) |
| disp_mde_ah.endeentladung | PASS |  |
| disp_mde_ah.scanbarcode | PASS |  |
| disp_mde_ah.startentladung | PASS |  |
| disp_mde_eb.abschlnve | PASS |  |
| disp_mde_eb.endeentladung | PASS |  |
| pdis_leg.staysloaded | PASS |  |
| pdis_tourpoint.removeloadingintervals | PASS |  |
| pdis_tourpoint.setcustomertournumber | PASS |  |
| pdis_tourpoint.setloadinginterval | PASS |  |
| pdis_tourpoint.setloadingreference | PASS |  |
| pdis_tourpoint.settargetloadingendtime | PASS |  |
| pdis_tourpoint.settargetloadingstarttime | PASS |  |
| pdis_transportorder.addshipment | SKIP | deprecated |
| pdis_transportorder.addtourpoint | PASS |  |
| pdis_transportorder.addtrailer | PASS |  |
| pdis_transportorder.addvehicle | PASS |  |
| pdis_transportorder.createandaddleg | PASS |  |
| pdis_transportorder.createtransportorderfromleg | PASS |  |
| pdis_transportorder.delete | PASS |  |
| pdis_transportorder.deletetourpoint | PASS |  |
| pdis_transportorder.edittourpoint | PASS |  |
| pdis_transportorder.getdriver | PASS |  |
| pdis_transportorder.movetourpoint | PASS |  |
| pdis_transportorder.removedriver | PASS |  |
| pdis_transportorder.removeleg | PASS |  |
| pdis_transportorder.removeparticipant | PASS |  |
| pdis_transportorder.removeshipment | PASS |  |
| pdis_transportorder.removetrailer | PASS |  |
| pdis_transportorder.removevehicle | PASS |  |
| pdis_transportorder.setcomment | PASS |  |
| pdis_transportorder.setdriver | PASS |  |
| pdis_transportorder.setequipmenthired | PASS |  |
| pdis_transportorder.setloadingaidsoptions | PASS |  |
| pdis_transportorder.setparticipant | PASS |  |
| pdis_transportorder.setpresettemp | PASS |  |
| pdis_transportorder.settransportmode | PASS |  |
| pdis_transportorder.setvehicleattributes | PASS |  |

### Types (1)

| Object | Status | Details |
|---|---|---|
| pdis_transportorder.legtype | FAIL | not found; USAGE denied |

## Drift Warnings

### tms1034.bordero

**Extra columns:** u_version, nummernkreis_k, firma, c_time, u_time, ols_user, absend_n, absend_i, absend_name1, empf_n, empf_i, empf_name1, gewicht, relation, dispo_text, status_k, status_text, pauschale_aufw_g, pauschale_aufw_w, stop_pauschale, stop_pauschale_w, status_fak, spt_n, spt_i, spt_name1, rueckm_k, rueckm_e, lhm_list_tix, maut_fix_g, maut_fix_w, lst_d

### tms1034.ort

**Extra columns:** post_orts_idnr, ols_user, ortsklasse_degt, ortsklasse_bsl, ortsklasse_db, ortskl_rueckrech, ikona_knoten_1, ikona_knoten_2, gem_schluessel, typ, ort_k, bezirk_k, gemeinde_k, ews_knoten, ews_knoten_int, ort_status, ref_city_id

### tms1034.person

**Extra columns:** u_version, firmennummer, region, sprache, verbund_code, kz_waehrung, name_alp_sortierun, c_time, c_user, u_time, ols_user, typ, anrede_kz, name_3, postfach, plz_postfach, bezirk_sitz, ort_sitz_tix, land_berechnung, plz_berechnung, ort_berechnung, bezirk_berechnung, ort_bere_tix, zone, kdnr_frachtzahler, kdnr_index_frachtz, kdnr_rg_empf, kdnr_index_rg_emf, sperrkz_auftrag, ausf_besch_b, fax_b, intrastat_b, faktura_vor_abf_nv, faktura_kz_art, faktura_zeitraum, mwst_kz, umsatzsteuer_id, kostenart, rechnungs_komp_kz, scheck_akz_b, kto_nr_fibu_spezi, kontonr_fibu, kto_n_fibu_k, kunde_n, bankeinzug, bankleitzahl_1, bankname_1, kontonummer_bank_1, bankleitzahl_2, bankname_2, kontonummer_bank_2, bankleitzahl_3, bankname_3, kontonummer_bank_3, telefonnummer, telefaxnummer, modem_n, isdn_nummer, e_mail_adr, www_adr, partner_aquisition, partner_buchhaltun, partner_dispo, partner_leitung, postf_ort, postf_land, sort_fakpos_k, fiskal_vertret_b, nullregelung_b, pseudobeleg_fibu_b, sachbearb, allfa_min_g, fak_min_g_k, st_n, fibu_n, rea_st_n_re_b, rea_st_n_gs_b, lhm_options, iban1, iban2, iban3, swift1, swift2, swift3, zahlart, firma_ident_n, firma_reg_n, firma_sitz_t, archiv_dok_typ, archiv_druck_b, sammelbeleg_b, info_t, gesch_bereich, vs_pm, eing_kontr_b, lspers_tix, kleinunt_b, ls_ware_b, ls_emp_b, ls_pdf_b, ls_label_druck_b, fak_abl_anhang_b, lagerknd_b, verkehr_k, prod_grp, ladzrmp7prio_b, au7_sperr_b, au7_extern_b

### tms1034.pst_hst

**Extra columns:** u_version, c_time, c_user, ref_tix, ref_k, t, ereignis_e, quell_k, mp_sub, rel, c_utc, ereignis_utc, mde_id, sachbearb

### tms1034.rollkart

**Extra columns:** u_version, nummernkreis_k, firma, c_time, u_time, ols_user, absend_n, absend_i, absend_name1, gewicht, tour, entf, stop_c, rueckmeldung_e, status_k, status_text, pauschale_aufw_g, pauschale_aufw_w, stop_pauschale, stop_pauschale_w, status_fak, unfr_b, lst_d, maut_fix_g, maut_fix_w, planung_b, entf_top, maut_entf_t, stop_c_top, status, abfahrt_soll_e, ankunft_soll_e

### tms1034.sen_ls_pst

**Extra columns:** u_version, c_time, c_user

### tms1034.sen_ls_ref

**Extra columns:** u_version, c_time, c_user, u_time, u_user, art

### tms1034.sen_ref

**Extra columns:** u_version, c_time, c_user, u_time, u_user, art

### tms1034.sen_zuord

**Extra columns:** u_version, c_time, c_user, u_time, u_user, lfd_n

### tms1034.sendung

**Extra columns:** u_version, fix_key, firma, niederlassung, rollkart_tix, bordero_tix, ladelist_tix, c_time, c_user, u_time, ols_user, auftrag_n, lagerplatz, zone_abg, zone_empf, fixtermin_zeit, frankatur, status_erf, status_dis, tour, status_zus, status_frb, status_mod, status_abf, status_fak, status_rue, status_sta, status_hst, status_1, status_2, status_3, status_4, status_5, status_6, status_7, status_8, status_9, status_10, status_11, status_12, status_13, status_14, status_15, auftrag_doss_t, absend_n, absend_i, empf_name1, sped_n, sped_i, sped_name1, unt_n, unt_i, unt_name1, dispo_deaktiv, direktsendung, direkt_angeladen, gefahrgut, lauf_kennz, zeitzone, gewicht, gewicht_frachtpf, volumen, anzahl_colli, eing_bordero_n, eing_bordero_pos, rollk_pos, rollk_e, rollk_abhol_n, rollk_abhol_pos, bordero_pos, bordero_e, ladeliste_n, ladeliste_pos, ladeliste_e, entladeliste, auftragsart, faktur_freigabe, selbstabholer, selbstanlieferer, dfue_in, dfue_out, dfue_empf_sped, absend_name2, absend_name3, absend_strasse, absend_land, absend_plz, absend_ort, absend_bezirk, absend_ort_tix, absend_postf, absend_pf_plz, absend_abw_land, absend_abw_plz, absend_abw_ort, absend_abw_bez, absend_abworttix, absend_ust_id, empf_name2, empf_name3, empf_strasse, empf_land, empf_plz, empf_ort, empf_bezirk, empf_ort_tix, empf_postf, empf_pf_plz, empf_abw_land, empf_abw_plz, empf_abw_ort, empf_abw_bez, empf_abwort_tix, empf_ust_id, empf_adr_aend, sped_strasse, sped_ort_tix, sped_postf, sped_pf_plz, sped_ust_id, unt_strasse, unt_ort_tix, unt_postf, unt_pf_plz, unt_ust_id, zustelldatum, absend_adr_aend, abs_rel, kond_bed, transit_k, ref_sen_tix, ref_k, stellplatz_c, quell_k, abl_scan_anw_k, emp_erm_rel, emp_abf_rel, rrv_gremp_b, pst_verfolg_k, abs_ursp_rel, abs_st_land, emp_st_land, zusa_k, prod_grp, abf_bereich_k, neutr_auslief_b, emp_adr_art, tran_art2, fix_bis_d, fix_bis_z, ursp_sen_n, lspers_k, logistik_k, dok_emp_b, d_kunde_b, kombisen_b, rrv_sperr_k, rrv_emp_typ, emp_rel_prod_grp, mde_id, prod_k, prod_intern_k, fix_von_d, fix_von_z, bodenstpl_c, volstpl_c, abh_von_d, abh_von_z, abh_bis_d, abh_bis_z

### tms1034.v_dis_contact_details

**Extra columns:** tix, u_version, del_flag, firma, nl, pers_i, typ, name3, match, info_t, adr_art, sitz_bez, sitz_ort_tix, postf_land, postf_plz, postf_ort, postf, ber_land, ber_plz, ber_ort, ber_bez, ber_ort_tix, lad_str, lad_land, lad_plz, lad_ort, lad_bez, gln, rel, region, fibu_n, w, tel, fax

### tms1034.v_dis_to_tourpoint

**Extra columns:** waitingduration

### tms1034.v_dis_transportorder

**Extra columns:** contractoraddresstype, transportordertype

### tms1034.v_ebv_participant

**Extra columns:** mail_address

### tms1034.v_ebv_service

**Extra columns:** receipt_state, ref_id

### tms1034.v_ebv_shipment

**Extra columns:** tms_relation

### tms1034.v_pers_tb

**Extra columns:** iln, matchcode, name2, name3, postf, postf_plz, sitz_okl_bsl, sitz_okl_db, ber_land, ber_plz, ber_ort, ber_bez, ber_ort_tix, ber_okl_bsl, ber_okl_db, rel, rel_tk, zone, adr_aend_b, erf_sperr_b, selbstanl_b, selbstabh_b, ust_id, kst, frz_n, frz_i, bee_n, bee_i, abl_scan_anw_k, adr_art, rrv_gremp_b, pst_verfolg_k, d_kunde_b, kond_bed, abl_scan_anw_aus_emp_b, st_land, ls_label_druck_b, logistik_k, rrv_sperr_k, rrv_knd_typ, emp_master_pst_b, mp8_digitalsign_b

### tms1034.v_sen_ls

**Extra columns:** ls_e, lspers_k, lspers_t, u_version, sen_n, fix_key, sen_art, vkstrom, firma, nl, lst_d_ym, lst_d, fix_d, fix_t, zus_d, frankatur, emp_rel, abs_rel, tour, abs_n, abs_i, abs_name1, abs_name2, abs_name3, abs_strasse, abs_land, abs_plz, abs_ort_tix, abs_ort, abs_bezirk, abs_postf, abs_postf_plz, abs_ustid, emp_n, emp_i, emp_name1, emp_name2, emp_name3, emp_strasse, emp_land, emp_plz, emp_ort_tix, emp_ort, emp_bezirk, emp_postf, emp_postf_plz, emp_ustid, gew, gew_fp, vol, ebo_n, ebo_pos, rk_tix, rk_n, rk_pos, rk_e, bo_tix, bo_n, bo_pos, bo_e, ll_tix, ll_n, ll_pos, ll_e, druck_k, prod_grp, status_vorl, ls_ext_tix, sen_display, sen_ls, sen_ls_avail, ls_dup, tranart, lsinfo_k, digilis_sort_k

