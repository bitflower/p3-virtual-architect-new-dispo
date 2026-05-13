
  TMS Bridge DB Verification
  Provider: Oracle | User: TMSBR1060 | Schema: TMS1060
  Levels: 1.0-Existence + 1.5-Signature + 2.0-Permissions
==================================================================

  TABLES (11)
  [+] TMS1060.BORDERO                            EXISTS  SELECT granted
  [+] TMS1060.FAHRER                             EXISTS  SELECT granted
  [+] TMS1060.ORT                                EXISTS  SELECT granted
  [+] TMS1060.PERSON                             EXISTS  SELECT granted
  [+] TMS1060.PST_HST                            EXISTS  SELECT granted
  [+] TMS1060.ROLLKART                           EXISTS  SELECT granted
  [+] TMS1060.SENDUNG                            EXISTS  SELECT granted
  [+] TMS1060.SEN_LS_PST                         EXISTS  SELECT granted
  [+] TMS1060.SEN_LS_REF                         EXISTS  SELECT granted
  [+] TMS1060.SEN_ZUORD                          EXISTS  SELECT granted
  [+] TMS1060.SEN_REF                            EXISTS  SELECT granted

  VIEWS (20)
  [+] TMS1060.V_DIS_TRANSPORTORDER               EXISTS  SELECT granted
  [+] TMS1060.V_DIS_TO_FILTER                    EXISTS  SELECT granted
  [+] TMS1060.V_DIS_TO_PICKUPPLANNING            EXISTS  SELECT granted
  [+] TMS1060.V_DIS_SHIPMENT_ALL                 EXISTS  SELECT granted
  [+] TMS1060.V_DIS_TO_TOURPOINT                 EXISTS  SELECT granted
  [+] TMS1060.V_DIS_FREIGHT_EXCHANGE_TP          EXISTS  SELECT granted
  [+] TMS1060.V_DIS_TO_PRESETTEMP                EXISTS  SELECT granted
  [+] TMS1060.V_DIS_BRANCH_ADDRESS               EXISTS  SELECT granted
  [+] TMS1060.V_DIS_LEG                          EXISTS  SELECT granted
  [+] TMS1060.V_DIS_TO_FEATURES                  EXISTS  SELECT granted
  [+] TMS1060.V_DIS_CONTACT_DETAILS              EXISTS  SELECT granted
  [+] TMS1060.V_DIS_TO_TP_TARGET_DATES           EXISTS  SELECT granted
  [+] TMS1060.V_DIS_TP_CLIENT_COMM               EXISTS  SELECT granted
  [+] TMS1060.V_PERS_TB                          EXISTS  SELECT granted
  [+] TMS1060.V_EBV_SHIPMENT                     EXISTS  SELECT granted
  [+] TMS1060.V_EBV_DELIVERY_NOTE                EXISTS  SELECT granted
  [+] TMS1060.V_EBV_LEG                          EXISTS  SELECT granted
  [+] TMS1060.V_EBV_PARTICIPANT                  EXISTS  SELECT granted
  [+] TMS1060.V_EBV_SERVICE                      EXISTS  SELECT granted
  [+] TMS1060.V_SEN_LS                           EXISTS  SELECT granted

  FUNCTIONS (11)
  [+] PDIS_TRANSPORTORDERDTO.GET                 EXISTS  sig OK (1 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.GETXSERVERDTO          EXISTS  sig OK (1 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.GETDRIVER              EXISTS  sig OK (4 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.GETERRORMESSAGE        EXISTS  sig OK (2 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.SETXSERVERDTO          EXISTS  sig OK (1 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.CREATETRANSPORTORDERFROMLEG EXISTS  sig: 15 args (not verified)  EXECUTE granted
  [X] PDIS_TRANSPORTORDER.CREATETRANSPORTORDERFROMSHIPMENT NOT FOUND  EXECUTE DENIED
  [X] PDIS_TRANSPORTORDER.ADDSHIPMENT            NOT FOUND  EXECUTE DENIED
  [+] PDIS_LEG.GETSTAYSLOADEDSTATUS              EXISTS  sig OK (1 args)  EXECUTE granted
  [+] CAL_UNIFACE.ITEM                           EXISTS  sig OK (12 args)  EXECUTE granted
  [+] CAL_UNIFACE.LIST2DBTT                      EXISTS  sig OK (1 args)  EXECUTE granted

  PROCEDURES (35)
  [+] PDIS_TRANSPORTORDER.DELETE                 EXISTS  sig OK (2 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.ADDTOURPOINT           EXISTS  sig OK (21 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.EDITTOURPOINT          EXISTS  sig OK (14 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.DELETETOURPOINT        EXISTS  sig OK (3 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.MOVETOURPOINT          EXISTS  sig OK (5 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.REMOVELEG              EXISTS  sig OK (3 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.CREATEANDADDLEG        EXISTS  sig OK (9 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.REMOVESHIPMENT         EXISTS  sig: 3 args (not verified)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.ADDVEHICLE             EXISTS  sig OK (7 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.REMOVEVEHICLE          EXISTS  sig OK (2 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.ADDTRAILER             EXISTS  sig OK (7 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.REMOVETRAILER          EXISTS  sig OK (2 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.SETPARTICIPANT         EXISTS  sig OK (79 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.REMOVEPARTICIPANT      EXISTS  sig OK (3 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.SETPRESETTEMP          EXISTS  sig OK (3 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.SETTRANSPORTMODE       EXISTS  sig OK (2 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.SETVEHICLEATTRIBUTES   EXISTS  sig OK (11 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.SETEQUIPMENTHIRED      EXISTS  sig OK (5 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.SETLOADINGAIDSOPTIONS  EXISTS  sig OK (2 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.SETCOMMENT             EXISTS  sig OK (2 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.SETDRIVER              EXISTS  sig OK (4 args)  EXECUTE granted
  [+] PDIS_TRANSPORTORDER.REMOVEDRIVER           EXISTS  sig OK (1 args)  EXECUTE granted
  [+] PDIS_TOURPOINT.SETCUSTOMERTOURNUMBER       EXISTS  sig OK (2 args)  EXECUTE granted
  [+] PDIS_TOURPOINT.SETLOADINGINTERVAL          EXISTS  sig OK (3 args)  EXECUTE granted
  [+] PDIS_TOURPOINT.SETTARGETLOADINGSTARTTIME   EXISTS  sig OK (2 args)  EXECUTE granted
  [+] PDIS_TOURPOINT.SETTARGETLOADINGENDTIME     EXISTS  sig OK (2 args)  EXECUTE granted
  [+] PDIS_TOURPOINT.REMOVELOADINGINTERVALS      EXISTS  sig OK (1 args)  EXECUTE granted
  [+] PDIS_TOURPOINT.SETLOADINGREFERENCE         EXISTS  sig OK (2 args)  EXECUTE granted
  [+] PDIS_LEG.STAYSLOADED                       EXISTS  sig OK (2 args)  EXECUTE granted
  [+] DISP_MDE_AH.SCANBARCODE                    EXISTS  sig OK (10 args)  EXECUTE granted
  [+] DISP_MDE_AH.STARTENTLADUNG                 EXISTS  sig OK (24 args)  EXECUTE granted
  [+] DISP_MDE_AH.ENDEENTLADUNG                  EXISTS  sig OK (7 args)  EXECUTE granted
  [+] DISP_MDE_AH.ABSCHLNVE                      EXISTS  sig OK (13 args)  EXECUTE granted
  [+] DISP_MDE_EB.ENDEENTLADUNG                  EXISTS  sig OK (9 args)  EXECUTE granted
  [+] DISP_MDE_EB.ABSCHLNVE                      EXISTS  sig OK (18 args)  EXECUTE granted

  TYPES (1)
  [o] PDIS_TRANSPORTORDER.LEGTYPE                SKIPPED  SKIPPED (PostgreSQL-only)
==================================================================
  [X] Level 1.0 (Existence):  75/77 found, 1 skipped, 2 NOT FOUND
  [+] Level 1.5 (Signature):  42/42 match, 36 unchecked (no expected args)
  [X] Level 2.0 (Permission): 75/77 granted, 1 skipped, 2 DENIED

  Result: FAILURES DETECTED