----------------------
Email from 2026-01-15
----------------------
Hi Matt,

Happy new year!

We are preparing an evaluation of Oracle CDC für New Dispo.

Remembering that you are using Striim for Pretzel I was wondering if you could provide the detailed configuration Oracle and Striim configuration. This would be valuable for our preparation. There should basically be a good config already in place. We also need to know if the existing Striim is in conflict with other potential CDC-players.

For example we are looking for these answers:

Is Striim only used on a small dedicated set of branch DBs? It has temporary character and will be phased out once all branches are on Alloy?
Are the databases in archive log mode?
Are the redo logs stored locally? For how long?
Is LogMiner enabled/allowed?
Does the DBA team agree with GRANTS such as LOGMINING, SELECT ANY TRANSACTION, EXECUTE_CATALOG_ROLE, etc.?

Thanks
