----------------------
Email from 2025-12-23
----------------------


Hi Matthias,

hier die Antworten auf deine Fragen. Im Text in Rot.


Von: Matthias Max <matthias.max@p3-group.com>
Gesendet: Freitag, 12. Dezember 2025 16:27
Bis: Christian Lang <Christian.Lang@cal-consult.de>
Cc: Sebastian Gieschen <Sebastian.Gieschen@p3-group.com>; Uschmann, Patrick <Patrick.Uschmann@nagel-group.com>; Beisheim, Maximilian <Maximilian.Beisheim@nagel-group.com>; Pascal Leicht <Pascal.Leicht@cal-consult.de>; Raul Godoy Chicas <raul.godoy-chicas@cal-consult.de>; Martin Dittmann <Martin.Dittmann@p3-group.com>; Maximilian Kehder <maximilian.kehder@p3-group.com>; Aktan Aktas <aktan.aktas@p3-group.com>
Betreff: AW: Dispo Q1 26 - Einbindung der Oracle Welt

Hallo Christian,

Stimme Dir zu, wir haben 2 Streams:

Konzeptionell: TMS Pulse um CDC-Lösung für Oracle erweitern
Anforderungsbeschreibung durch CAL / Nagel
z.B. Welche Use Cases gibt es (Business-Ziele)? Welche Tabellen werden benötigt?

Der Use-Case ist die Aktivierung der NewDispo auf Basis der Oracle Welt. D.h. die selben Tabellen, die wir unter AlloyDB verwenden.

z.B. welche Systeme sind das Ziel der Events (New Dispo, Cross-Dock/CALSuite, Cloud4Log, weitere, ….)

siehe oben. Use-Case New Dispo mit entsprechendem Zielsetting.

Sollen die Quellen (Postgres & Oracle) zusammengeführt werden (in einem Bus)? „Unsichtbar“ für Konsumenten?

Stand jetzt, imho, nein.

Alle bekannten Optionen nennen, falls vorhanden
Datastream kann ggf. Oracle(https://docs.cloud.google.com/datastream/docs/sources-oracle?hl=de)
Pascal hatte Optionen

Wir sind offen was das Tooling anbelangt. Oracle wird weiterhin OnPrem laufen, während das Tool sowohl OnPrem (nicht bevorzugt) als auch in der Cloud laufen könnte. 

Next Steps:
In der Vergangenheit haben sich hier kleine PoC als effizient und effektiv bei der Optionensuche und Entscheidung herausgestellt => das würde ich hier ebenfalls empfehlen
Anforderungen wie oben beschrieben bereitstellen (CAL)
Mini-Kickoff Workshop planen, remote, Vorschlag 90-120 Min (Teilnehmer: Christian, Pascal, Ron, Matt, Boyan/Yosif, Matthias - ggf. weitere?)
Vorstellung der Ziele
Vorstellung der bekannten Optionen
Takeaway von Aufgaben je Rolle als Vorbereitung für Folgeworkshop zur Festlegung von PoCs

Schickt uns doch hierzu einfach ein kleines "Angebot" durch damit wir hieraus eine PO machen können. Dann können wir hier in die Evaluierung gehen.


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