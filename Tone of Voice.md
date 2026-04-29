# Tone of Voice

## General Rules

- Avoid "AI characters" like — (long dash)
- Avoid heavy formatting besides bold, list items

## Teams Message Examples

These are examples of Teams messages of mine. They can be used as reference when drafting messages for me.

### Exmaple 1

"Topic TBD:
Who monitors certificate rotation ? We should setup a proactive solution to prevent such situations."

### Example 2

"Nach dem Meeting  Tim Willenbrink glaube ich umso mehr, dass wir ein Operationsthema haben. Die ganze Thematik "Ist es Network" oder "Oracle selber" verschwimmt mit der reinen Feature-Anforderung: Macht die entwickelte Lösung was sie soll per Spezifikation?
 
Wie ist der Stand hier? Ich habe Ivailo gebeten hier als aktives Bindeglied reinzugehen zwischen den P3 Devs, Nagel IT Platform (Ron) und den Mind Shorting Kollegen."

### Exmaple 3

"One observation: If we log bug tickets. Please add all relevant info like branch, branch ID, time when it happenend .."

### Exmaple 4

"HI Ivailo Pashov, Great chance to observe the challenges live
 
It would be great if you could support here from now on and be the active communicator to either our PM or the client (TBD).
 
One major part of the work is also to identify when an issue is caused on our side or on Nagel IT side. Like the wrong DiGiLis paths for example."

### Exmaple 5

"Ivailo Pashov and I had a good sync. He now has access to all relevant resources.
 
He started analyzing the requirements for Markant DVA. We also answered some early questions.
 
Full meeting notes:
Markant DVA Sync.loop
Markant DVA Sync.loop
 
Cem Karaman Tim Willenbrink Marius is the business contact for requirements questions, correct?"

## E-Mail Exmaples

### Exmaple 1

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

### Exmaple 2

Hallo Christian,

Stimme Dir zu, wir haben 2 Streams:

Konzeptionell: TMS Pulse um CDC-Lösung für Oracle erweitern
Anforderungsbeschreibung durch CAL / Nagel
z.B. Welche Use Cases gibt es (Business-Ziele)? Welche Tabellen werden benötigt?
z.B. welche Systeme sind das Ziel der Events (New Dispo, Cross-Dock/CALSuite, Cloud4Log, weitere, ….)
Sollen die Quellen (Postgres & Oracle) zusammengeführt werden (in einem Bus)? „Unsichtbar“ für Konsumenten?
Alle bekannten Optionen nennen, falls vorhanden
Datastream kann ggf. Oracle(https://docs.cloud.google.com/datastream/docs/sources-oracle?hl=de)
Pascal hatte Optionen

Next Steps:
In der Vergangenheit haben sich hier kleine PoC als effizient und effektiv bei der Optionensuche und Entscheidung herausgestellt => das würde ich hier ebenfalls empfehlen
Anforderungen wie oben beschrieben bereitstellen (CAL)
Mini-Kickoff Workshop planen, remote, Vorschlag 90-120 Min (Teilnehmer: Christian, Pascal, Ron, Matt, Boyan/Yosif, Matthias - ggf. weitere?)
Vorstellung der Ziele
Vorstellung der bekannten Optionen
Takeaway von Aufgaben je Rolle als Vorbereitung für Folgeworkshop zur Festlegung von PoCs

Operativ
Oracle-Development Enablement für P3 Devs
Bestands New Dispo Objekte in Oracle bringen
Zukünftig neue Objekte direkt in beiden Datenbanken entwickeln

    Next Steps:
Schulung durch Bestandseentwickler
Tooling: Aufsetzen der benötigen IDEs, ...
Access: Zugriff auf Repo/Codebase
Dev-Testing ermöglichen: Lokale Instanzen? Welche Environemnts gibt es? Benötigen wir UniFace?
QA befähigen: Wir können P3 QA Supporten?
Collaborationsprozess festlegen: Pull-Requests, Reviews durch CAL, 

Deployment & Release-Prozess
Abstimmung der Liefergrenze (Welche Aufgaben müssen P3 Devs erledigen, welche nicht)
Release-Prozess: Wie wird gebrancht, versioniert, released und durch wen
Wie werden PostGres & Oracle synchronisiert  (Schema und Daten Migrationen)?

        Next Steps: 
Vorstellung des holistischen Deployment-Prozess durch CAL/Matt
Fortfolgende Abstimmung zur Unterstützungsform von P3 bei Deployments

Benötigen wir den Kickoff noch vor X-Mas ?

Grüße
Matthias

### Exmaple 3

Hi,

Wie im Chat besprochen - Der aktuelle Stand der Enterprise Architektur. Work in Progress.

Stand von gestern.

Was stellt es dar? Das bekannte TMS/New Dispo Diagram erweitert um die WMS Infos von Rafael. Kombiniert in einem Chart.

Links:
Nagel-Architecture-Enterprise-2026-01-16.mmd
TMS-Disposition-NewDispo-2025-11-18.drawio.png

TMS-Disposition-NewDispo-2025-11-18.drawio.png

Gruß
Matthias

### Exmaple 4 

Hallo Christoph,
kommt in den besten Familien vor 😅
Ansonsten komme ich immer gerne für einen strategischen Austausch nach Stuttgart.
Liebe Grüße, dir auch,
Matthias

### Example 5

Hi all,

as discussed during the GoLive 1060 alignment, please find attached the complete inventory of all database objects accessed by the TMS Bridge application. 

This defines the required permission scope for the TMS Bridge database user (e.g. TMSBR1060) on the Oracle instances. For the Datastream/Striim user we are still looking - maybe we can also discuss this again reg. the needs from Striim side (Redo Logs). Is there any documentation from Striim @Matt Wilkinson?

Summary

The TMS Bridge user requires permissions on 77 objects in total:
- 10 tables (SELECT)
- 21 views (SELECT)
- 11 functions (EXECUTE)
- 35 stored procedures (EXECUTE)
- 1 custom type (USAGE)

These are spread across 9 schemas: 
- tms (tenant)
- public
- pdis_transportorder
- pdis_tourpoint
- pdis_leg
- pdis_transportorderdto
- disp_mde_ah
- disp_mde_eb
- cal_uniface

The attached PDF contains the full breakdown per object - including schema, access type (read/write), and which TMS Bridge component calls it. 

The document is also available in the Wiki:
https://dev.azure.com/p3ds/Nagel-CAL Disposition/_wiki/wikis/Nagel-CAL-Disposition.wiki/15881/TMS-Bridge-Database-Objects

One note: 7 views were renamed in the current TMS Database release (release/7.0.0.8+NEW-DISPO). The document already uses the new names.

The immediate ask is to set up the user with these permissions on ORA-ABN-1060. The same scope applies to ORA-UAT-1060 and production after the respective sign-offs.

Happy to walk through the details if there are questions.

Best,
Matthias