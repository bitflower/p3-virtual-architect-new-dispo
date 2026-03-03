# 2025-10-10

Teams: https://teams.microsoft.com/l/message/19:700ca03dc12944a38db6d07d631c3a84@thread.v2/1760102358076?context=%7B%22contextType%22%3A%22chat%22%7D

the topic from this morning is a completely different from this yes, but for the error flows, we don't know what is happening with the legs on tms side in the different scenarios (for example traffic mode changes) so there's no way to say how much effort would take to sync in new dispo



Right now in New Dispo, we have 2 big conceptual software development challanges arised from the nature of the application.
 
 
1. Achieve atomic/transactional behavior between New Dispo and TMS
 
For every bussiness logic flow for which we need to persist information both in New Dispo DB and TMS DB we are vulnerable to getting our of sync.
 
Flows such as leg/lot assignment, leg/lot unassignment, create transport ordere from leg/lot, delete transport order, mark leg as stays loaded and maybe more, we are vulnerable to the issue.
 
Each of these flows contains transactional behavior meaning that if the operation fails on TMS it should also fail in New Dispo and vice versa.
 
For example if we assign a leg we first assign the Leg on TMS and if it succeeds we assign in New Dispo. Lets say tho that for some reason we're unable to assign it in New Dispo, we don't have logic to rollback on TMS. Even if we do try to rollback on TMS it might not succeed.
 
This is a complex problem/challange that all distributed systems suffer from due to the nature of the architecture.
 
There are different solutions for this problem but not all will fit our architecture. It's a complex topic for which is cruical to get it right otherwise it might turn out having catastrophic effect.
 
 
2. CDC error handling / disaster recovery mechanism
 
For each CDC event that New Dispo is subscribed for we should have mechanism to recover from in case that New Dispo is unable to process the event.
 
Our current cloud event messaging mechanism provides out of the box functionality to guarantee that every event will be eventually consumed from New Dispo.
 
For example if New Dispo app crashes the messaging mechanism will keep retrying sending the event until it is consumed.
 
What we don't have is a mechanism to guarantee that the event will be eventually processed if New Dispo fails the first time.
 
Lets say new CDC event for NewShipmentInserted is consumed from New Dispo. At this point our cloud messaging mechanism has done its job and it won't try to process the event again as it is successfully consumed.
 
What happens next is that issue arises in New Dispo internal processing of the event, for example it fails to create the legs for this new shipment or New Dispo DB is not available for a moment.
 
The outcome of this would be that New Dispo will not be able to retry processing the event and it will eventually get out of sync.
 
This could happen for each and every CDC event New Dispo subscribed for.
 
This issue is signficantly less complex than the first one but its something that it's also not adressed yet.