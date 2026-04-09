# Technische Plattform (Überblick)

**Stand:** 09.04.2026

| Bereich                   | Technologie                                                |
| ------------------------- | ---------------------------------------------------------- |
| Backend                   | .NET 8 / ASP.NET Core, HotChocolate GraphQL                |
| TMS Bridge API            | GraphQL (kein REST)                                        |
| Datenhaltung              | PostgreSQL (AlloyDB)                                       |
| UI                        | Angular 19                                                 |
| Echtzeit / Push           | Google Cloud Pub/Sub, Google Datastream                    |
| Asynchrone Integration    | Azure Service Bus (für EDI-Austausch), GCP Cloud Functions |
| Caching / State           | Kein Caching von TMS-Daten                                 |
| Infrastruktur als Code    | Kubernetes YAML Manifests                                  |
| Softwarebereitstellung    | Azure Pipelines                                            |
| Hosting / Cloud-Plattform | GCP (GKE, Cloud Run, AlloyDB)                              |
| Secrets Management        | GCP Secret Manager                                         |
| Logging                   | Serilog                                                    |

## Schnittstelle Elektronischer Datenaustausch (EDI): Lobster

Business-to-Business- (B2B-) und elektronischer Datenaustausch (EDI) mit Kunden und Partnern erfolgen typischerweise auf Basis branchenüblicher Nachrichten (z. B. UN/EDIFACT, GS1 XML o. ä.). Lobster Data Platform (Lobster) ist die Integrations- und EDI-Plattform für Übersetzung, Validierung und technischen Versand der Nachrichten (Partnerformate, Transportprotokolle).

## Anbindung CALSuite über Azure Service Bus

New Dispo ist über den Azure Service Bus (CALSuite Service Bus Namespace) mit der EDI-Kette verbunden. Der Transport erfolgt über AMQP (WebSockets). Für die EDI-Kommunikation sind folgende Azure-Service-Bus-Warteschlangen (Queues) definiert:

| Queue (Name)          | Richtung                                                                         |
| --------------------- | -------------------------------------------------------------------------------- |
| `newdispo_to_lobster` | **Ausgang** (Sender): von New Dispo kommende EDI-Nachrichten in Richtung Lobster |

Die Lobster-Anbindung läuft über die oben genannte Azure-Service-Bus-Queue.

**Hinweis:** New Dispo sendet nur EDI-Nachrichten (z.B. Rechnungsdaten), empfängt aber aktuell keine Nachrichten über den Service Bus.

## Anbindung Frachtenbörsen

New Dispo ist direkt mit externen Frachtenbörsen über deren REST-APIs verbunden. Die Anbindung ermöglicht das Erstellen, Aktualisieren, Abrufen und Löschen von Frachtangeboten auf den jeweiligen Plattformen.

| Plattform | Anbindung | Authentifizierung              |
| --------- | --------- | ------------------------------ |
| Timocom   | REST API  | Basic Auth (Username/Password) |
| Trans.eu  | REST API  | OAuth2 (Client Credentials)    |

Die Konfiguration (Credentials, API-Keys) erfolgt pro Niederlassung (Database) und wird über GCP Secret Manager verwaltet.

## Environments und GCP Workloads

| Komponente          | Workload | DEV | TEST | PROD |
| ------------------- | -------- | --- | ---- | ---- |
| Frontend            | WL4      | x   | x    | x    |
| Backend             | WL4      | x   | x    | x    |
| TMS Bridge          | WL5      | x   | x    | x    |
| TMS Pulse           | WL5      | x   | x    | x    |
| Cloud4Log / Markant DVA | WL5  | x   | x    | x    |
| Dispo Filter (CDC)  | WL5      | x   | x    | x    |
| Cross-Dock Connector | WL5      | x   | x    | x    |
