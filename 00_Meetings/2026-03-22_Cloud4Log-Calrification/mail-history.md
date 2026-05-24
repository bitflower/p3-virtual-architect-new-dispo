# Mail history Cloud4Log / Markant DVA

## Cem's Eskalation

Lieber Christian, lieber Marius,
ich benötige dringend eure Unterstützung, da unsere Entwickler aktuell durch mehrere kritische Themen blockiert sind und nicht weiterarbeiten können.
Die Situation stellt sich wie folgt dar:
Wir sind im Development Environment vollständig blockiert, da notwendige Konfigurationen (WL5) nicht umgesetzt werden.
Obwohl diese Konfiguration bereits im Testsystem funktioniert, wird sie im DEV aktuell nicht aktiviert, wodurch Deployments nicht möglich sind.
Es bestehen weiterhin Zugriffs- und Berechtigungsprobleme (Read/Write, Datenbankzugriffe, DevOps Ressourcen), die seit längerer Zeit bestehen und nun kritisch sind.
Zusätzlich ist lokales Entwickeln und Testen nicht sinnvoll möglich, da erforderliche Daten und Berechtigungen fehlen. Die aktuelle Vorgehensweise würde die Entwicklung massiv verlangsamen.
Auswirkungen:
Der Fortschritt ist aktuell gestoppt
Deployments sind nicht möglich
Der geplante Go-Live kann unter diesen Umständen nicht eingehalten werden
Wir haben diese Themen bereits mehrfach adressiert, jedoch haben wir keine feste Lösung
Wir benötigen daher dringend:
Aktivierung der notwendigen Konfigurationen im DEV
Vollständige Read/Write Berechtigungen für das Team
Bereitstellung geeigneter Dev/Test Ressourcen inkl. relevanter Daten
Ohne kurzfristige Klärung sind Verzögerungen unvermeidlich.
Ich empfehle dringend, noch heute einen Abstimmungstermin mit allen relevanten Stakeholdern anzusetzen, da der aktuelle Austausch keine Fortschritte bringt.
Vielen Dank für eure schnelle Unterstützung und Priorisierung.
Beste Grüße
Cem

## Christians Antwort

Hi Cem,

Hier hatten wir doch die Tage einen Mailaustausch wo unsere Infrastruktur sagte, dass die Zugänge da sind? Irgendwer kam auf Matt zu mit der Bitte um WRITE Access auf Diglis/Hyparchiv - das ist z.B. Absolut nicht notwendig.
Bitte stell mir eine Liste zusammen mit konkreten Punkten die wir angehen müssen. Ich muss konkret wissen, was nicht geht.

Danke

## Mein (Matthias) Versuch beruhigend einzugreifen

Hallo Cem,

Ich würde das gerne intern klären. Hierzu habe ich mich mit Christian gestern abgestimmt.

Speziell der Begriff „Write Access“ ist derzeit undefiniert (vermutlich fehlende Testdaten, die „selbst geschrieben werden sollen“).

Matthias

## Cems unstrukturierzte und chaotische Antqort

Hallo Christian,

zur Klarstellung: Der Wunsch nach WRITE Access war ursprünglich nur gedacht, um Plattform Team direkt bei der Korrektur der Daten zu unterstützen. Da dies nicht notwendig ist, warten wir nun, bis ihr die Datenbanken mit den erwarteten und korrekten Daten befüllt.

Aktuell befinden sich die Sendungen in den Datenbanken nicht in den richtigen Zuständen, wodurch sie für das Cloud4Log Projekt nicht nutzbar sind. Damit Daten für C4L relevant und hochladbar sind, müssen folgende Bedingungen erfüllt sein:

In Oracle TMS:

Sendungen müssen 'verkehrsstrom' = '30' haben.

Sendungen müssen einen nicht-leeren druckdatumE-Wert haben.

Sendungen müssen einen zugehörigen Bordero- oder Rollkart-Datensatz haben.

Bei Rollkart muss tranArt = 3 oder 6 sein.

Sendungen müssen einen zugehörigen Personendatensatz über EmpfN und EmpfI mit ILN-Werten 4099200045498 oder 4099200045504 haben.

Sendungen müssen einen zugehörigen pstHsts-Datensatz haben:

Status = '660'.

mp = '4' bei Bordero, '7' bei Rollkart.

Muss sinnvolle Metadaten enthalten.

Sendungen müssen zugehörige Daten in senLsPsts haben, wobei lsN mit dl_no aus Digilis DL_SHIP_ORD_POS übereinstimmt.

Sendungen müssen Daten in sen_ls_ref haben:

typ = "BES".

lsN entspricht dl_no aus Digilis DL_SHIP_ORD_POS.

sen_tix entspricht der Sendung.

sen_ls_ref muss mit senLs verknüpft sein, mit gleichem sen_tix und typ = "BES".

In Digilis Oracle:

Lieferschein muss denselben SEN_TIX wie die Sendung in TMS haben.

Lieferschein-Aufträge (DL_SHIP_ORD) müssen mit DL_SHIP_ORD_POS verknüpft sein.

DL_SHIP_ORD_POS muss mit DL_DEL_NOTE_CONN verknüpft sein.

In Digilis File Share:

Datei muss am in DL_DEL_NOTE_CONN.Path angegebenen Pfad vorhanden sein.

Matthias ist bereits mit Yosif im Austausch, daher möchte ich nicht parallel eingreifen. Bitte gibt uns Bescheid, sobald die korrigierten Daten verfügbar sind und wir weiterarbeiten können. 

sobald wir die korrekten WL5 Setup Updates sowie die erwarteten Daten erhalten, müssen wir unseren Go-Live leider um einen Sprint verschieben.

Liebe Grüße 

Cem Karaman

## Christian

Das sind nun ja alles SQL Daten und nicht wie eingangs erwähnt Devops, Zugänge und Co?! 

Was ich nicht verstehe: Wir sprechen gerade von einem Re-Design der Implementierung bedingt durch Markant. All diese Daten mussten doch schon beim initialen Testing in der ersten Iteration des Projekts verfügbar gewesen sein? Wie habt ihr denn da getestet?

## Cems Antwort

Hi Christian,
das initiale Testing wurde auf den Produktionsdatenbanken durchgeführt, da der Load aktuell nicht anders realistisch widergespiegelt werden kann.
Die Nutzung der Produktionsdaten im Dev Umfeld im Read-Only-Modus war  geplant, wurde jedoch nicht durchgängig umgesetzt.
Aktuell führt dies dazu, dass wir für Tests jedes Mal deployen müssen. Matthias ist hierzu bereits im direkten Austausch mit dir. Ich warte auf euren Support.
Schönes Wochenende & liebe Grüße
Cem Karaman

## Christian

Ihr könnt doch einfach Mock-Daten verwenden um Last zu simulieren.
Das ist je ein Datensatz aus der TMS Datenbank der mit einem Item aus Digilis korreliert? 

Wir werden hier keine Duplizierung von den Datenbanken oder Datenströmen für diesen Use-Case aufsetzen. Das bindet sinnfrei Ressourcen auf unserer Seite.

 Verkompliziert doch bitte dieses super simple Projekt nicht künstlich.

Danke