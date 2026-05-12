
Hi Matthias, 

The permission grant for CAL_QUEUE_Q has been provided to TMSBR1060 user but the question has come up to why this is needed? 
Can you retry?

Regarding the U_TIME, Andrej has found that U_TIME is not in the either postgres or Oracle or in the REPO for those views. I can confirm this being the case in the Postgres github repo.

Regarding the next point "ORA-21000: error number argument to raise_application_error of -24010 is out of range
 -> TMS1060.PTA (line 5060)
 -> TMS1060.PDIS_TRANSPORTORDER (line 72)"

I'm working with the team on this now. 

## As comment on the WIKI:

(EXT) Matt Wilkinson
commented 6h ago

Feedback from Andrej on review of the U_TIME missing:
The field named U_TIME is not available in either of the views V_DIS_TRANSPORTORDER or V_DIS_TO_PICKUPPLANNING—neither in PGS nor in Oracle.

What is the recommended next step here?