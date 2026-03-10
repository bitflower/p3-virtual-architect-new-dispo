----------------------
Email from 2026-01-16
----------------------


Hallo Robert,

Danke für die Antworten.

Ich habe noch Fragen unten in blau formuliert.

Danke

Matthias

Von: Robert Zanter <robert.zanter@pasolfora.de>
Datum: Donnerstag, 15. Januar 2026 um 12:33
An: Christian Lang <Christian.Lang@cal-consult.de>, Matthias Max <matthias.max@p3-group.com>
Cc: Sebastian Gieschen <Sebastian.Gieschen@p3-group.com>, 'Uschmann, Patrick' <Patrick.Uschmann@nagel-group.com>, 'Beisheim, Maximilian' <Maximilian.Beisheim@nagel-group.com>, Pascal Leicht <Pascal.Leicht@cal-consult.de>, Raul Godoy Chicas <raul.godoy-chicas@cal-consult.de>, Martin Dittmann <Martin.Dittmann@p3-group.com>, Maximilian Kehder <maximilian.kehder@p3-group.com>, Aktan Aktas <aktan.aktas@p3-group.com>, 'Andreas Prusch (pasolfora)' <andreas.prusch@pasolfora.de>
Betreff: RE: Dispo Q1 26 - Einbindung der Oracle Welt

You don't often get email from robert.zanter@pasolfora.de. Learn why this is important
CAUTION: This email originated from outside of the organization. Do not click links or open attachments unless you recognize the sender and know the content is safe.

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
Ja ist teilweise bereits aktiv und kann genutzt werden Sprechen wir von Oracle LogMiner oder Binary Log Reader ?
Ist das DBA Team einverstanden mit GRANTS wie LOGMINING, SELECT ANY TRANSACTION, EXECUTE_CATALOG_ROLE, etc. ?
Wenn das durch CAL/Nagel abgenickt wird, natürlich.
 
@Christian Lang:
 
Wie sind die Datenbanken on-prem gehostet (Bare metal, VM, RAC, Exadata, Docker, …)  -> VM
Nur um sicherzugehen, falls mit dem Punkt die Datenbankserver gemeint sind, diese sind alle bare metal. Sprechen wir also von:
Physischer Server => Betriebssystem => Oracle Database Server
Physischer Server => Betriebssystem => VM => Oracle Server?
Welche VM wird eingesetzt? Die Fragen stelle ich, weil wir ggf. das Setup nachstelle in Isolation (TBD)
 
 
 
Mit freundlichen Grüssen,
Robert Zanter