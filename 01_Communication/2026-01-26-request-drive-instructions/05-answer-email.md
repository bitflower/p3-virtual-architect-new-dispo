# Antwort-E-Mail

---

Hallo,

vielen Dank für die Anfrage zur Dokumentation der Fahranweisung in der New Dispo App. Anbei die gewünschte Aufschlüsselung.

Basierend auf den Code-Repositories:
1. **TMS Bridge:** https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Disposition-Abstraction-Layer
2. **Backend:** https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Disposition-Backend
3. **Frontend:** https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Disposition-Frontend

## Zusammenfassung

Wir haben ein **kombiniertes Dokument** erstellt (siehe Anhang `2026-01-26-Fahranweisung-Dokumentation.pdf`), das folgende Bereiche abdeckt:

### 1. Backend (Disposition-Backend)

- **Authentifizierung:** Keycloak JWT Bearer Token + Database-Identifier Header auf jedem Request
- **Endpoints:** Alle REST-Endpoints für Fahranweisungen, Tourpunkte (CRUD + Reorder), Ladeintervalle, Ladereferenzen, Lot-/Leg-Zuweisungen und Ladereihenfolge
- **Datenverträge:** Request/Response Bodies für alle Operationen
- **Swagger:** Die vollständige API-Spezifikation liegt bei. Swagger UI ist in Local-Umgebungen unter `/swagger` erreichbar.

### 2. Frontend (Disposition-Frontend)

- **Darstellung:** Die Fahranweisung wird im Transport Order Slider (Planning-View) und in den Transport Order Details dargestellt
- **Services:** Manage Tour Points, Drive Instructions Drawer, Reorder Drag & Drop, Assignment Requests, etc.
- **TypeScript-Interfaces:** TourPointDetails, TourPointConfig, LotTourPointConfig, LegTourPointConfig mit allen Feldern
- **Tourpunkt-Typen:** Pickup (1), Delivery (3), Exchange of Carrier (5), Border Crossing (8), Customs (9), Start (11), Finish (12)

### 3. TMS Bridge (Disposition-Abstraction-Layer) — Datenbank-Zuordnung

Besonders relevant für euch: Wir haben für **jede GraphQL Query und Mutation** der TMS Bridge aufgeschlüsselt, welche **Datenbank-View, -Funktion oder -Prozedur** im TMS verwendet wird. Hier die Kurzfassung der fahranweisungsrelevanten Operationen:

| Operation                | TMS-Prozedur                                 |
| ------------------------ | -------------------------------------------- |
| Tourpunkt verschieben    | `pdis_transportorder.movetourpoint()`        |
| Tourpunkt anlegen        | `pdis_transportorder.addtourpoint()`         |
| Tourpunkt bearbeiten     | `pdis_transportorder.edittourpoint()`        |
| Tourpunkt löschen        | `pdis_transportorder.deletetourpoint()`      |
| Ladereferenz setzen      | `pdis_tourpoint.setloadingreference()`       |
| Ladezeit (Start) setzen  | `pdis_tourpoint.settargetloadingstarttime()` |
| Ladezeit (Ende) setzen   | `pdis_tourpoint.settargetloadingendtime()`   |
| Ladeintervall entfernen  | `pdis_tourpoint.removeloadingintervals()`    |
| Kunden-Tournummer setzen | `pdis_tourpoint.setcustomertournumber()`     |
| "Bleibt geladen" setzen  | `pdis_leg.staysloaded()`                     |

Die Queries lesen aus Views wie `v_dis_transportorder`, `v_dis_to_tourpoint`, `v_dis_leg`, `v_dis_shipment_all` u.a. — die vollständige Zuordnung aller 34 Queries und 35 Mutations findet ihr im Dokument unter Abschnitt 7.

### 4. Edit Tour Point Data (Feature 119752 - 14.1)

Das Bearbeiten von Tourpunkt-Daten läuft wie folgt:
- **Frontend:** `PUT /api/transportorders/tourpoints/{tourPointId}` mit Feldern wie name1, tourNumber, country, postalCode, city, streetAndHouseNumber, district
- **Backend:** Delegiert an TMS Bridge via GraphQL Mutation `callEditTourpoint`
- **TMS Bridge:** Ruft die Prozedur `pdis_transportorder.edittourpoint()` auf
- **Quellcode:** `Features/TransportOrders/Requests/EditTourpoint/` im Backend

---

Bei Rückfragen stehe ich gerne zur Verfügung. Falls ihr einen Termin zur Abstimmung möchtet, meldet euch gerne.

Mit freundlichen Grüßen
