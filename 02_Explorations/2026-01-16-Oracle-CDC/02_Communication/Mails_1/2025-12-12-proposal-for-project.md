----------------------
Email from 2025-12-12
----------------------

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