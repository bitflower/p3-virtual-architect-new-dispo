# 2024-03-27 Intro Call

Teilnehmer: Pascal Leicht, P´Raul Godoy Chicas

## Fragen

- Workshop Date (On-Site)
- Figma-Zugang

### Pascal Leicht

- 14 Jahre bei der CAL
- Webbereich
- Vieles mit aufgebaut
- 4 Jahre Architektur Veratnwortng

### Raul Godoy Chicas

- seit einem jahr bei CAL / DIspo / Transportbereihc
- Product owner
- Logistikkenntnisse begrenzt
- Requirements der Nagel Group sammeln, Backlog, PBIs verwalten

### Thema

- 90% Lesen => kann Pascal nicht bestätigen
- Lorry Anwendung => wird eine (neue) Webanwendung
- Planen von Transporten
- Anders / besser implenetnieren
- => Transportaufträge

- WebService ist andere Produkt als das TMS

- Cross-Branch Sicht
-> Sieht er für den Anfang nicht
=> sehr großes internes Thema
=> Abstimmung mit Christian läuft

- Migration vollständig => für Hauptprozesse verwenden
- => Legacy-System

ENDZIEL: Alles über neue Oberfläche ändern können
=> Ganze Planung für Disposition machen

=> 1. Schnittstelle
=> 2. 

Material:

- UX/UI Designer haben sie
- Es gibt 2 Versionen
- 1. Vision, langfristig
- 2. Greifbarer Scope, kurzfristig

- eine Functionaltität steht schon, die als erstes gestaret werden soll => TMS
=> ich bekomme das Paket, Collab Modell noch zu bestimmen

- Wunsch: mit Standardelelenten arbeiten
- Keine Sonderimplemetnierung

- TMS Heute: Daten sind in Tabellen => Businesslogik befindet sich in Packages => wir wollen schnell Ergebnis liefern => wieder verwenden => wir werden viele package Calls haben => mit Kollegen von P3 besprechen => macht Einsatz von ORM Sinn ? => Kennt Packges von TMS aber so nicht im Detail
z.B: Transportauftrag anlegen => ist das ein Aufruf Package oder 5 oder müssen wir Ergenis entgegen nehmen und nachmal was aufrufen

- WebService: werden wir nicht verwenden und verwenden können => ruft zwar Packages auf aber es sind nicht alle Packages enthalten
=> Anwendung ersetzt TMS Produkt => Hat Desktop Oberläche Uniface => spricht direkt mit der Datenbank

=> MobileWebService verwendet Schnittstelle des TMS Produkts auf => WebService ist ein anderes UI um die Packages zu nutzen
=> Wird von MDE / handheld Geräten verwendet
=> Ownership" gegenüber dem TMS Produkt => MobileWebService ist ein Nebenprodukt
=> ob wir MobileServicve verwenden hat er Zweifel

=> Neue Technologie für die Anbindung von Packages nach heutigem Standard

- Lorry und "New Dispo" ist das gleiche
- => Plan G Projekt = Migration von Oracle
- Stream "Lorry" => neue Anwednung bauen ist ein Workstream

=> Orga / Projektplan angefordert (ich)

- Workshop: Pascal tut sich schwer mit konkretem Termin => sie sind noch sehr früh im der Architektur => Workshop sollte Gesprächstoff habe
=> evtl. in 2 oder 3 Wochen

Ende KW 15 Termin nennen, für KW 16/17 Termin

3 Sachen wichtig (Raul)

1. Architektur
2. UI => welcher Workflow, etc.
3. Funktionialität

## Zusamenarbeit

- Raul: Collaboration, Abnahme, Monitoring des Progress ("wo stehen wir")
- => auf Feature-Ebene

## Architektur

- Termine mit Pascal, wahlweise mit Raul
- Für KW15

## UI

- später starten? Haben sie auch schon gespielt (Raul) => KW 20 stehen die Anforderungen => Meeting mit Stakeholdern
- => Anforderungen für erste Version können evtl erst dort bestätigt werden
- => Davor Architekturarbeit starten

- viel Basisarbeit machen: Design System, etc. ableiten => aus Figma ableiten => Bootstrap ?
- => basiert auf Material Design => Entscheidung aus erstem Workshop mit den Designern => Memmet (Designer)

- Erwartung: Standardelemente verwenden, nichts neu erfinden => erste paar Schritte

- UI Lib für wietere Anwendungen verwenden ? => ob sie noch mehr bauen wollen, kann Pascal nicht beantworten
- Sie haben noch eine andere Anwendnung, ie auch auf modernem techstack bsiert => ANgular, Microservices, ...

=> im On-Site WOrkshop tiefer reingehen
=> uns mal zeigen, was sie da noch haben => Synergiepotentiale ! Das wird sehr geschätzt ("Ihnen sagen, wass unserer meinung nach wiederverwendet werden kann etc")

Pascal: wollte er los werden: Architekru Groundwork => wird mich mit reinholen => KW 14 ff.

## Orga

- Raul: Di + Mi frei
- Pascal: ist da
