----------------------
Email from 2026-01-15
----------------------

Hallo Christian,
 
anbei die Antworten zu den Fragen:
 
Welche Version von Oracle setzt ihr ein (11.2, 12c, 18, …) ?
Hauptsächlich 12.1.0.2 die KRITIS Datenbanken sind auf 19.9 und 19.21
Hat jeder Branch die gleiche Version?
Je nach dem ob es KRITIS relevant ist sind die Versionen 12.1.0.2, 19.9 und 19.21
Welche Edition setzt ihr ein (Enterprise, Standard, XE, Free, ...)?
In der Zentrale EE sonst SE2
Sind die Datenbank in Archivelog Modus?
ja
Werden die redo Logs lokal gespeichert? Wie lange?
Ja, Aufbewahrungszeit ist Abhängig von zur Verfügung stehendem Platz in der jeweiligen Niederlassung. Aber kein Archivelog das nicht gebackuped wurde wird gelöscht.
Ist LogMiner aktiviert/erlaubt?
Ja ist teilweise bereits aktiv und kann genutzt werden
Ist das DBA Team einverstanden mit GRANTS wie LOGMINING, SELECT ANY TRANSACTION, EXECUTE_CATALOG_ROLE, etc. ?
Wenn das durch CAL/Nagel abgenickt wird, natürlich.
 
@Christian Lang:
 
Wie sind die Datenbanken on-prem gehostet (Bare metal, VM, RAC, Exadata, Docker, …)  -> VM
Nur um sicherzugehen, falls mit dem Punkt die Datenbankserver gemeint sind, diese sind alle bare metal.
 
 
 
Mit freundlichen Grüssen,
Robert Zanter