----------------------
Email from 2026-01-14
----------------------


Hi Christian,

Offene Fragen für die Vorbereitung:

Welche Version von Oracle setzt ihr ein (11.2, 12c, 18, …) ?
Hat jeder Branch die gleiche Version?
Welche Edition setzt ihr ein (Enterprise, Standard, XE, Free, ...)?
Wie sind die Datenbanken on-prem gehostet (Bare metal, VM, RAC, Exadata, Docker, …) ?
Besteht Netzwerkverbindung zum Internet - konkret zu GCP? (TMS Bridge funktioniert ja bereits, von daher denke ich ja)
Sind die Datenbank in Archivelog Modus?
Werden die redo Logs lokal gespeichert? Wie lange?
Ist LogMiner aktiviert/erlaubt?
Soll ein dedizierter User für das CDC verwendet werden?
Ist das DBA Team einverstanden mit GRANTS wie LOGMINING, SELECT ANY TRANSACTION, EXECUTE_CATALOG_ROLE, etc. ?

Danke & Grüße
Matthias
