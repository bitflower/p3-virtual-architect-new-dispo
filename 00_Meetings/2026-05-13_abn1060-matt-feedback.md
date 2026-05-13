Hi all

There has been two deployments with the corrected code:

In Oracle the pDIS_TransportOrder.CreateTransportOrderFromLeg is now Procedure (it is not a Function) 

In this procedure there is also a change to Mode numeric > this has now become nMode numeric - this is because MODE is ORACLE reserved word.  

V_DIS_TO_PickupPlanning.ora.sql now contains U_TIME in the view.

Please can you confirm

Kind regards / Mit freundlichen Grüßen / Met vriendelijke groet

Matt Wilkinson