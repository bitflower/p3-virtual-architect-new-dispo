Morning All, 

I've not seen anything shared through on actions yet so just wanted to circle back on what was discussed:
Two options to be looked into Striim and Datastream. Nagel INF to look into the data stream setup for Oracle. I need someone to confirm if this is the correct documentation we should be following. LINK HERE - P3 to confirm? 
P3 to create target storage buckets for ABN tests - 2 buckets to be created one called Striim and one called Datastream
Nagel to initiate full database copy of PROD 1060 and 1034 to be loaded into target oracle INF ( Nagel to decide where) 

Approach:
Nagel to set up on a Test environment and manually confirm technical ability (target complete this week if we can get the storage buckets). 
Technical setup confirmed load test will be initiated with order duplication from OMS. (I'm suggesting we run it for a week) As the test databases will need clearing as they will begin to slow down if the orders aren't cleared up. (Target Wednesday next week for this)

Points raised:
We aren't going to consider any resilience tests if there is an issue with connectivity or something stops. 
Striim will be relatively setup but is a little overkill for a or two tables cdc capture. 
Striim has a higher cost implication than datastream. 

Is there a group chat/ somewhere you want us to communicate the updates? 

Matt Wilkinson