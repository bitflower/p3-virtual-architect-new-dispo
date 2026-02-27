Hey, quick one: The shipments data in this UI is coming from v_dis_shipment_all?
 
https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_workitems/edit/103821

	
            Azure DevOps Services | Sign In
        

 
Transport Order => Lot => Leg => ShipmentID => Shipment => OMS-ID
 
By shipment data you mean data used for generating legs?
 
Classic  
 
No, really the "original" shipment
 
..which we use to generate the legs, right?
 
Because with the link we want to go back to the original shipment spawning the legs.
 
Boyan Valchev
..which we use to generate the legs, right?
Correct
 
We query the v_dis_shipment_all and then apply filter to get the unplanned shipments
 
Phrased Differently: OMS-ID is a simple LEFT join on sendung. We just need to  provide it in the correct source view.
 
Boyan Valchev
We query the v_dis_shipment_all and then apply filter to get the unplanned shipments
That's my knowledge as well. Great. then I'll plan it like that and we can refine.
 

 Well we will need to extend the leg structure as well then
 
to store this OMSID
 
or the other option is to make query each time they want to navigate
 
But the second option is not great I think
 
Hm
 
Question is how often do they go there.
 
And do those OmsIds change
 
But when opening the drawer you read v_dis_shipment_all anyway?
 
Which drawer?
 
Boyan Valchev
And do those OmsIds change
1:1 TMS SHipment <> OMS Order
 
Boyan Valchev
Which drawer?
The Drive Instructions Side Bar

We don't use this view for nothing else other than the generation
 
of legs
 
Got'cha.
 
and the cdc
 
ofcourse
 
CDC is on sendung
 
But inside the app we are not calling it
 
?
 
CDC is on sendung not the view ?
 
We track changes from sendung
 
Because it needs to be a table
 
not a view
 
Exasctly. I was just confused. Good.
 
inside the resolvers we may be querying the view, but I am not sure
 
about that one
 
K. I'll check.
 
But this is not relevant for the OMSID
But that makes the flow clear. We need to store the OMS ID in our tables. It doesn't change.
 
No more reading of it later.
 
The 2 options as I see them are either to store this OmsId, when we generate legs, or resolve it with query when needed
 
Hey hey
 
Quick checkin: On ABN the Datastream works as of Nikolay.
 
Can you confirm this?
 
Well
 
As of this morning as per my knowledge it did not, but I have a message from Nikolay from 5 min ago saying that now he sees data in the bucket with an hour delay and no errors
 
So I can not confirm at this point
 
Ok, I can check with Nikolay reg. the cloud function runs and downstream process.
 
I understood that we are still connected to the DB through the proxy - this is not recommended when we have CDC approach. We should be as close to the db as possible
 