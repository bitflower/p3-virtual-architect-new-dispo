**To:** Joachim Schreiner, Bernd Friedewald, Thomas Paulus, Christian [Last Name], Ron [Last Name], Patrick U., Max K., Max Beisheim
**Subject:** TMS Bridge – Database User Permission Scope (for Oracle 1060)

**Attachment:** 2026-04-29_TMS-Bridge-Database-Objects.pdf

---

Hi all,

as discussed during the GoLive 1060 alignment, please find attached the complete inventory of all database objects accessed by the TMS Bridge application. This defines the required permission scope for the TMS Bridge database user (e.g. `TMSBR1060`) on the Oracle instances. For the Datastream/Striim user we are still looking - maybe we can also discuss this again reg. the needs from Striim side (Redo Logs). Is there any documentation from Striim @Matt Wilkinson?


**Summary:**

The TMS Bridge user requires permissions on **77 objects** in total — 10 tables (SELECT), 21 views (SELECT), 11 functions (EXECUTE), 35 stored procedures (EXECUTE), and 1 custom type (USAGE). These are spread across 9 schemas: `tms` (tenant), `public`, `pdis_transportorder`, `pdis_tourpoint`, `pdis_leg`, `pdis_transportorderdto`, `disp_mde_ah`, `disp_mde_eb`, and `cal_uniface`.

The attached PDF contains the full breakdown per object — - including schema, access type (read/write), and which TMS Bridge component calls it. The document is also available in the Wiki:
https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_wiki/wikis/Nagel-CAL-Disposition.wiki/15881/TMS-Bridge-Database-Objects

**One note:** 7 views were renamed in the current TMS Database release (`release/7.0.0.8+NEW-DISPO`). The document already uses the new names.

The immediate ask is to set up the user with these permissions on **ORA-ABN-1060**. The same scope applies to ORA-UAT-1060 and production after the respective sign-offs.

Happy to walk through the details if there are questions.

Best,
Matthias
