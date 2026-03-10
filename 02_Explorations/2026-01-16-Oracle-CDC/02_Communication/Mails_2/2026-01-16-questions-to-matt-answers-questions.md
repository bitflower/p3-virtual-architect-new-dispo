
----------------------
Email from 2026-01-16
----------------------


Hi Matt,

Thanks for the answers. Would be great to have a quick back and forth ping pong here - thanks!

Answers and new questions in red.

Matthias

Von: Matt Wilkinson <Matt.Wilkinson@cal-consult.de>
Datum: Donnerstag, 15. Januar 2026 um 15:06
An: Matthias Max <matthias.max@p3-group.com>
Cc: Christian Lang <christian.lang@cal-consult.de>, Martin Dittmann <Martin.Dittmann@p3-group.com>, Pascal Leicht <pascal.leicht@cal-consult.de>, Maximilian Kehder <Maximilian.Kehder@p3-group.com>
Betreff: Re: Striim: Oracle Configuration Documentation

CAUTION: This email originated from outside of the organization. Do not click links or open attachments unless you recognize the sender and know the content is safe.

Hi Matthias,

Happy new year to you too. 

We can get Striim looped in if needed but I'll answer everything as best I can.

Is Striim only used on a small dedicated set of branch DBs? It has temporary character and will be phased out once all branches are on Alloy? - At the moment its running on 5 branches, its has been running across all branches before and can be reenabled. 
What is the target picture? To have it running on all branches (for which use cases?) Or to phase it out slowly once we either have migrated to Postgres for a branch or stay on Oracle (for a certain time or forever) ? Is there still a need to push data to Postgres once a branch is live on Postgres?
Are the databases in archive log mode? Which databases are you referring to? The Oracle side? 
Yes, we only talk Oracle right now. As far as my current knowledge goes there is Oracle LogMiner or the Binary Log Reader - in the end one must be enabled to utilise CDC
Are the redo logs stored locally? For how long? So the branches have Oracle redo logs however it varies per branch due to the storage on the Oracle disks. So for example, if the Striim lost connection (network blip) at D33 we'd need to get it up and running ASAP or we'd have to do an initial load again because the transaction count would recycle within an hour (assumption) its a very short period anyway. 
My assumption here is that any CDC is second priority to the scenario you a describing (which would result in heavier data loss anyway).
Is LogMiner enabled/allowed? - unsure but is there an impact to this being enabled to the database load?
See my above answer reg. the two Logger options. I’ll get int touch with Robert about this.
Does the DBA team agree with GRANTS such as LOGMINING, SELECT ANY TRANSACTION, EXECUTE_CATALOG_ROLE, etc.? - once it’s understood on what we are trying to solve with this I think it'll be OK. Just depends if it’s best to introduce another tool and another cost. 
Good points. We should definitely separate between the use cases and the strategy (phase out Striim or introduce/reactivate on all branches). Datastream seems to offer Oracle as well. Which leads me to think that this is the first approach we should try. Also Striim seems very expensive. Can you provide the costs for it that are currently and say the last 6 months have been billed?

Questions I'll ask:
What's the thoughts/ requirements here as we can utilise Striim to push data into another database in GCP? 
The use case is not pushing (huge amounts) of data. We need to trigger business logic based on certain data changes (e.g. a new Shipment comes in). These are very narrow cases where we are interested in the change of one field for example of one table record. Target is definitely to have this installed on all productive database (same as for Postgres).
Is it thought out / understood the impacts of adding another transaction log monitor onto the Oracle Infrastracture as it’s a bit "creeky" at the moment. 
Creeky being? Unreliable? Slow? But definitely one of the main discussion points. Hence my question reg. the plan for Striim (temporary vs. long-term).
I definitely see a conflict in having two CDCs installed



Kind regards / Mit freundlichen Grüßen / Met vriendelijke groet

Matt Wilkinson
External Delivery Consultant - Programme management 