
----------------------
Email from 2026-01-15
----------------------


Hi Matthias,

Happy new year to you too. 

We can get Striim looped in if needed but I'll answer everything as best I can.

Is Striim only used on a small dedicated set of branch DBs? It has temporary character and will be phased out once all branches are on Alloy? - At the moment its running on 5 branches, its has been running across all branches before and can be reenabled. 
Are the databases in archive log mode? Which databases are you referring to? The Oracle side? 
Are the redo logs stored locally? For how long? So the branches have Oracle redo logs however it varies per branch due to the storage on the Oracle disks. So for example, if the Striim lost connection (network blip) at D33 we'd need to get it up and running ASAP or we'd have to do an initial load again because the transaction count would recycle within an hour (assumption) its a very short period anyway. 
Is LogMiner enabled/allowed? - unsure but is there an impact to this being enabled to the database load?
Does the DBA team agree with GRANTS such as LOGMINING, SELECT ANY TRANSACTION, EXECUTE_CATALOG_ROLE, etc.? - once its understood on what we are trying to solve with this I think it'll be OK. Just depends if its best to introduce another tool and another cost. 

Questions I'll ask:
What's the thoughts/ requirements here as we can utilise Striim to push data into another database in GCP? 
Is it thought out / understood the impacts of adding another transaction log monitor onto the Oracle Infrastracture as its a bit "creeky" at the moment. 



Kind regards / Mit freundlichen Grüßen / Met vriendelijke groet

Matt Wilkinson
External Delivery Consultant - Programme management 