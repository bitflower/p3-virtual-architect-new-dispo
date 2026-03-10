----------------------
Email from 2026-01-15
----------------------


Hi @Robert Zanter,

kannst Du uns diese Fragen beantworten?
Wir sprechen hier von unseren produktiven TMS Datenbanken.

Welche Version von Oracle setzt ihr ein (11.2, 12c, 18, …) ?
Hat jeder Branch die gleiche Version?
Welche Edition setzt ihr ein (Enterprise, Standard, XE, Free, ...)?
Sind die Datenbank in Archivelog Modus?
Werden die redo Logs lokal gespeichert? Wie lange?
Ist LogMiner aktiviert/erlaubt?
Ist das DBA Team einverstanden mit GRANTS wie LOGMINING, SELECT ANY TRANSACTION, EXECUTE_CATALOG_ROLE, etc. ?

@Matthias Max

hier die Antworten auf deine restlichen Fragen:

Wie sind die Datenbanken on-prem gehostet (Bare metal, VM, RAC, Exadata, Docker, …) ?

VM

Besteht Netzwerkverbindung zum Internet - konkret zu GCP? (TMS Bridge funktioniert ja bereits, von daher denke ich ja)

Ja, GCP hat Zugriff auf die On-Prem DBs, siehe EBV.

Grüße