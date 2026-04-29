Hi Eric,

thanks for the sharp eye on `sen_ref`. You were right to flag it.

`sen_ref` is actually a table in the database. We listed it as a view accidentally because the TMS Bridge uses `ToView()` internally to map it read-only. A `v_sen_ref` view does exist in the database but the Bridge doesn't use it.

We've corrected this in v1.1 - moved `sen_ref` from Views (section 2c) to Tables (section 1) with a read-only marker.

Updated version attached. Also updated in the Wiki:
https://dev.azure.com/p3ds/Nagel-CAL Disposition/_wiki/wikis/Nagel-CAL-Disposition.wiki/15881/TMS-Bridge-Database-Objects

Summary of changes (v1.1): 11 tables (+1), 20 views (-1), rest unchanged.

Best,
Matthias
