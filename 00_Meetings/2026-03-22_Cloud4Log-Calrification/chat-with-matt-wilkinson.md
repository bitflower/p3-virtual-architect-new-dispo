# Database/ GCP access + permissions P3 (CHat)

## Yosif

We also have 1 more topic that is blocker for us:
 
Dev resources that were provided to us for local testing does not contain relevant data
In order to enable local development testing we need access to TMS Oracle database, Digilis Oracle database and SMB file share all for the same depot and most importantly containing relevant shipment information for the Cloud 4 Log use case.
Some time ago we were provided for resources to use for local development testing these were: 
Oracle TMS - User Id=tms1057 and Data Source=d57.tmsrel:1521/d57.tmsrel
DigiLiS - User Id=nagdigilis and Data Source=D57DB.DIGILISREL:1521/D57DB.DIGILISREL
The problem which we currently have with them is that they do not contain relevant shipment data for C4L use case.
We tried to fed these resources with data ourselves but the db users that were provided to us do not have the needed write permissions.
Couple of options to resolve the issues we have: 
1. We need different resources (tms/digilis/smb) that already contain relevant shipment information
2. The current provided resources d57.tmsrel, D57DB.DIGILISREL etc. are fed with relevant shipment information
3. Our db users for d57.tmsrel, D57DB.DIGILISREL are given the needed write access so we try to feed the data ourselves

## Matt Wilkinson

Hi all,
 
In summary my immdiate response to this why do we need it set to being Publically accessible? The internal services like the TMS Bridge should 100% NOT be made available to be accessible via a Public IP. 
 
If it needs to be Publiceally accessible this needs to be written down on how this is secure and I'll need to show to the security team.
 
Currently the TMS Bridge in WL5 -p- is set to Public which is NOT the expectation that Christian has (I've just spoken to him about it).  

## Yosif

Nikolay Hristov can you provide some input on that ? 
 
On the other hand Matt Wilkinson is it not an option to set it to PUBLIC for our DEV environment given that its being dev environment and not test just so we can enable the development and address the topic in parallel so we don't get blocked, else we are risking of not meeting the deadlines if we have to solve this topic right now from the ground ?
 
I'm just trying to find a way forward which is not disrupting our velocity
 
## Nikolay

Matt Wilkinson it is the same deployment as in t-t and in p-p, I am cloning the services (tmsbridge and keycloak)
 
## Yosif

> Nikolay Hristov: Matt Wilkinson it is the same deployment as in t-t and in p-p, I am cloning the services (tmsbridge and keycloak)
Nikolay Hristov it is already clear that it is the same deployment in t-t and p-p what Matt is trying to say is that he believes this was a mistake in first place and the technical devops question from him is why we need it public and who decided that it should be public and why
 
Matt Wilkinson either way as I already saide above I think its best if we find a way around this and we tackled this in parallel and not block C4L development as we really cannot afford to spend time and wait to solve this topic conceptually from the ground up

## Matt Wilkinson

> Nikolay Hristov: Matt Wilkinson it is the same deployment as in t-t and in p-p, I am cloning the services (tmsbridge and keycloak)
I know what you are doing, but the question is this correct and we'll need to justify to security why we need that setting and if so how are we making sure its secure.
 
Yosif Mihaylov I spoke to Christian and he is not expecting you or P3 to make updates to any database.
If there are any scripts you need to run. PLease provide via email and the Database engineer team can deploy them.
 
 
Digilis and TMS database should be aligned the databases that you are stating access to are NOT development databases they are the REL databases. 

## Yosif

Matt Wilkinson this is again something that won't turn out working well and we will end up loosing again a lot of time, the assumption we had is that we are going to be provided with resources that are straight away suitable to use for development testing, I would say lets go with that and just please provide us some resources that have relevant data inside, we don't really have capacity and time for the workflow you're suggesting
 
## Matt Wilkinson

But Yosif Mihaylov its not your deccision to make that call - I pushed the request to Christian who said you only need Read.
 
You changing the source databases to be inline with what you need isn't neceassily what should be happening. TMS and Digilis shoud be the same (depending the data) 
 
please understand you working in a larger environment of connected databases and instances running.
 
So if you can provide the scripts you need to pull them into the direction you think you need please do. And we can get on a call and execute them together. 
 
Is there a reason we've now all pushed all these requests into this chat
 
Write down what you want to do and I'll sponsor getting write access. But the reason " we are missing data"
 
*The problem which we currently have with them is that they do not contain relevant shipment data for C4L use case.
We tried to fed these resources with data ourselves but the db users that were provided to us do not have the needed write permissions.*
 
Can be solved in another way...

## Yosif

Matt Wilkinson
 
Yes the reason is that we have lost a lot of time during these last months over missing accesses and permissions and the communication and velocity we have in terms of resolving these issues is not good and these keep coming and we're now at serious risk of meeting our deadlines
 
We don't really insist or need of having WRITE permissions, it was something we were willing to do as a workaround to ease off you guys, I would say please give us proper development resources (so we don't use REL lets call that communication issue), we need TMS Oracle db, Digilis Oracle Db, SMB File share (including machine credentials) all pointing to the same repo and more importantly **having data inside which is relevant** for C4L (we can provide more details on this one)

## Matt Wilkinson

I don't know anything about C4Log or what it does / need. 
 
If you need data then this can be created in teh REL databases through Pascal / Bernd F - they can log on and create it Or should be able to. 
(our testing team could easily create some shipment data in REL)
 
We have:
Oracle Dev - called ENT where we currently host ENT1 - which are connected to Oracle DEV central
Oracle Test - called ABN where we currently host ABN1060 and others - which are connected to Oracle ABN central (pretty sure there is a Digilis database here) 
Oracle REL - where hose REL2820/ REL1060 connected to REL central - which are connected to Oracle REL central / Digilis database is here
Oracle UAT - which is hosted in Versmold that the UAT guys have access (likley not a Digilis database here)
Oracle Prod - the prod databases with 
 
We also have the same setup in Posgtres / a few more databases:
 
PGS DEV - ENT1 / Dev debudg
PGS ABN - ABN1034 ABN2820 
PGS UAT - UAT1034 and UAT 2820 Connects to Digilis in REL
PGS PROD TMS2820 
 
Each of the above are all controlled by Repos and deployment tools (Oracle at the moment
 
We can hook up/ connect to any of the above - from GCP a service in GCP 
 
If you need data get whoever is leading if to create the data in those environments. Has that been requested? 

## Yosif

Matt Wilkinson can you provide the exact credentials for any depot for Oracle Dev, we need credentials for Oracle TMS, Oracle Digilis, and SMB pointing to that same repo ? So we don't use the REL as you said that are not the correct resources to use for development testing ?

## Matt Wilkinson

What do those users need to do on those databases? 
 
Point to raise - all development changes on TMS is done by the TMS team, same for Oracle Digilis. 
Writing data, changing package functionality, changing database objects isn't in the scope of P3 - unless someone tells me otherwise.
 
Recent example:
NEW dispo changes to TMS database converting back functionality to from PGS to Oracle. Done by the TMS team.
Request came in, planned it, converted it and tested it found issues - fixed the issues - tested again. 
 
## Yosif

okay thats fine, we need read access only then, and we will give further details on what data we need inside

## Matt

first acion for you guuys is PLEASE remove the PROD google secrets from the wl5-d-d

## Yosif

Matt Wilkinson
 
what we agreed on before with 
Matthias Max was to use the prod resources there as C4L project only ever does reading and NEVER writing to these resources(this could be restricted with user permissions as well)
 
we agreed on that so that we can have resources for multiple depots (that's essential to test concurrency and load and executing flows for multiple depots in parallel which is in the core of this project) and also to have resources that are constantly fed with data
 
we don't really have test environment available to test this (test environment is being used for uat (not my call)) so setting up the dev environment with just a few resources or anything that's not mimicking what really happens is not an option and it would mean that it would never be able to test the functionality properly
 
we don't mind going with development resources there as well but then we need to be provided with dev resources for 32 depots that are constantly fed with proper data and as we discussed back then and it was said to us that this is not feasible

> Yosif Mihaylov 21.05.26 16:00: Matt Wilkinson can you provide the exact credentials for any depot for Oracle Dev, we need credentials for Oracle TMS, Oracle Digilis, and SMB pointing to that same repo ? So we don't use the REL as…
so can we expect this for the local dev testing?