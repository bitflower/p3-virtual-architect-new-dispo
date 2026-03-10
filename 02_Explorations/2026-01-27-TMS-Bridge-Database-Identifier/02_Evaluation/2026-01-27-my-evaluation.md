## 2023-10-11 Zusammenfassung der Entscheidung zur Datenbank-Identifizierung

Mein persönliches Initialgefühl zu dieser Entscheidung war, dass der Datenbank-Typ, also Postgres oder Oracle, nicht Teil der Datenbank-Identifikation sein sollte. Warum? Weil wir auf der Ebene von TMS-Bridge und darüber liegender Applikations-Layerg nicht mehr über die zugrunde liegenden Datenbank-Technologien sprechen. Wir möchten uns mit den organisatorischen Ebenen, wie dem Land, dem Unternehmen und dem Branch/Niederlassung, befassen. Daher sollte der Stil in etwa so gestaltet sein, wie das Land, z. B. D für Deutschland oder SE für Schweden, eine Firma wie 10 oder 28 und dann eine Branche wie 34 oder 20.

Aus den Diskussionen, die ich mit Max Kehder, unserem Produktowner, und auch mit Pascal hatte, schien es jedoch, dass die Leute dazu tendieren, einen Identifier zu vermeiden, der die Technologie in den Datenbank-Identifizierungsstring einschließt. Daher haben wir zwei Optionen:

1. Wir lassen es weg und beginnen mit der Firmennummer, gefolgt vom Branch.
2. Wir behalten die Kennzeichnung durch Datenbank-Typen, d. h., O für Oracle und P für Postgres, gefolgt von Unternehmens- und Branchidentifikation .

Die Entscheidung ist, dass wir die Kennzeichnung durch Datenbanktypen behalten, weil es einfacher ist, die Nutzer damit vertraut zu machen und Verwirrung zu vermeiden.

## Code-Cross-Check

We should look into the TMS Bridge Repo to see the current implementation and to propose the new solution as a code sketch.

## Downstream Dependencies

We should mention the impact on downstream system that are live already like EBV, Cloud4Log, New Dispo