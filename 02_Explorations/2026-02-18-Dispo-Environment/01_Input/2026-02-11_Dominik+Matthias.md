

Historie und Aufbau des GCP-Projekts: 

Dominik erläutert Matthias die Entstehung und Entwicklung des GCP-Projekts, beschreibt die Übernahme durch Harun und Team nach Kudehau, die initialen Herausforderungen mit fehlender Dokumentation und die schrittweise Strukturierung der Umgebung.
	Projektübernahme und Aufgaben: Dominik erklärt, dass er im September des Vorjahres zum Projekt hinzukam, nachdem Harun und Team das Projekt von Kudehau übernommen hatten. Kudehau hatte die Lending Zone aufgebaut, wurde dann abgelöst, und Haruns Team sollte fünf zentrale Aufgaben übernehmen, kam aber nicht weiter, weshalb Dominik hinzugezogen wurde.
	Herausforderungen bei Dokumentation: Ein zentrales Problem war das Fehlen von Dokumentation und Visualisierungen, wodurch die Zuordnung und der Zweck vieler Objekte unklar waren. Erst ab Oktober/November konnten die wichtigsten Aufgaben abgearbeitet und die Umgebung strukturiert werden.
	Erstellung eigener Workloads: Ab November war es möglich, eigene Workloads zu erstellen, statt nur die bestehenden zu nutzen. Dies führte zu einer besseren Handhabbarkeit und Flexibilität im Projekt.

Struktur und Verwaltung der GCP-Projekte: 

Dominik und Matthias besprechen die technische Struktur der GCP-Projekte, die Nutzung von mehreren Umgebungen (Dev, Test, Prod, Shared), Besonderheiten bei Workload 4 und 5 sowie die Komplexität des Monorepos und der Namensgebung.
	Projekt- und Netzwerkstruktur: Für jede Workload werden typischerweise vier Projekte (Shared, Test, Dev, Prod) angelegt, wobei jedem Projekt ein eigenes Netzwerk zugeordnet ist. Shared bildet eine Ausnahme ohne Subnetze. Workload 4 hat kein Dev-Projekt, während Workload 5 eines erhält.
	Komplexität durch Monorepo: Die ursprüngliche Anlage der Projekte erfolgte durch ein großes Monorepo von QDR, was die Verwaltung und Anpassung erschwert, da viele Abhängigkeiten bestehen und Änderungen weitreichende Auswirkungen haben können.
	Vereinfachung durch Refactoring: Das Team hat das Repository refactored, um die Anlage neuer Workloads zu vereinfachen. Nun genügt das Kopieren einer Main-TF-Datei und die Definition eines Namens, um ein Grundgerüst zu erstellen. Ziel ist eine übersichtlichere und leichter bedienbare Struktur.
	Namenskonventionen und Übersicht: Die Namensgebung der Projekte und Ordner ist historisch gewachsen und teilweise unübersichtlich. Das Team hat begonnen, die Namensschemata zu vereinfachen, um die Übersichtlichkeit zu erhöhen.

Zugriffsrechte, Environments und Datenbankanbindung: 

Matthias und Dominik diskutieren die Zugriffsrechte auf die verschiedenen Workloads, die Environment-Struktur, Besonderheiten bei der Datenbankanbindung und die tatsächlichen Zugriffsmöglichkeiten zwischen den Umgebungen.
	Zugriffsrechte und Projektanlage: Die Nutzer sind auf die jeweiligen Workloads berechtigt und können diese in ihrer Umgebung sehen. Neue Workloads könnten theoretisch manuell angelegt werden, wobei Abstimmung mit Nagel, Kalk und Salt notwendig wäre.
	Shared VPC und Netzwerksegmentierung: In GCP werden Shared VPCs verwendet, sodass Instanzen verschiedener Workloads innerhalb einer Umgebung miteinander kommunizieren können. Zwischen den Environments (Dev, Test, Prod) sind die Zugriffe jedoch standardmäßig abgekapselt.
	Datenbankanbindung und Environment-Grenzen: Matthias stellt fest, dass entgegen der Annahme auch Zugriffe von Test auf Dev-Datenbanken möglich sind. Dominik bestätigt, dass dies von der konkreten Implementierung abhängt und die Environment-Grenzen nicht immer strikt eingehalten werden.
	Datenbankmigration und Automatisierung: Die Migration von Oracle zu Postgres (AlloyDB) ist im Gange. Bisher wurden Datenbankdeployments manuell durchgeführt, was zu Inkonsistenzen führte. Nun wird die Automatisierung mit Flyway angestrebt, um zukünftig CI/CD-Prozesse zu ermöglichen.

Transparenz und Dokumentation der Infrastruktur: 

Dominik und Matthias betonen die Notwendigkeit klarer Dokumentation und Transparenz über die Infrastruktur, um Missverständnisse und ineffiziente Arbeitsweisen zu vermeiden; Dominik bietet an, eine Übersicht und ein Makro-Dokument zu erstellen.
	Fehlende Übersicht und Blackbox-Problematik: Es besteht ein Mangel an klarer Struktur und Dokumentation, wodurch viele Zusammenhänge unklar bleiben und die Entwicklung oft wie in einer Blackbox erfolgt.
	Erstellung einer Übersicht: Dominik bietet an, Screenshots und eine Übersicht der Projekte, Datenbanken und Cluster zu erstellen und diese als Makro-Dokument zusammenzufassen, um Transparenz zu schaffen.
	Abhängigkeiten und Mapping: Matthias wünscht sich eine Darstellung der Abhängigkeiten von Tabellen über Schemas, Datenbanken, Cluster, Projekte bis zu den Environments, um die Zusammenhänge nachvollziehen zu können.

Netzwerkanbindung und Performance-Probleme: 

Matthias schildert massive Performance-Probleme beim Zugriff auf die GCP-Anwendung durch den Hauptstakeholder, Dominik erläutert die bisherigen Maßnahmen und verweist auf die Verantwortung von Telekom und Arista für die Netzwerkkomponenten.
	Problembeschreibung und Auswirkungen: Der Hauptstakeholder kann teilweise nicht auf die GCP-Anwendung zugreifen oder erlebt lange Wartezeiten beim Login, was zu politischen Diskussionen und Verzögerungen im Projekt führt.
	Analyse und bisherige Maßnahmen: Das Problem wurde auf Netzwerkebene (SD-WAN, MTU, Paketgrößen) lokalisiert. Es wurden bereits VM-Typen gewechselt und Arista sowie Telekom sind involviert, bisher jedoch ohne nachhaltige Lösung.
	Verantwortlichkeiten und Blackbox-Charakter: Dominik sieht auf GCP-Seite wenig Handlungsspielraum, da die Netzwerkverbindung über eine VM und Arista-Appliance läuft. Die Verantwortung liegt bei Telekom und Arista, die für die Appliance zuständig sind.
	Paketverluste und weitere Schritte: Es wurde festgestellt, dass viele Pakete in der Applikation gedroppt werden. Dominik hofft auf weitere Analysen durch Telekom und Arista, sieht aber auf Anwendungsebene keine Lösungsmöglichkeiten.

Folgeaufgaben:

Makro-Dokumentation der GCP-Projektstruktur und Datenbanken: 
Erstelle und sende eine übersichtliche Dokumentation (inklusive Screenshots und Auflistung der Datenbanken und Cluster) zur aktuellen GCP-Projektstruktur und den zugehörigen Alloy-Datenbanken an Matthias. (Dominik)
Klärung des Auftragsumfangs für Workload-Aufräumarbeiten: 
Frage bei Harun nach, ob das Aufräumen und Anlegen von Workload 4 und 5 im bestehenden Maintenance-Vertrag abgedeckt ist oder ein separater Auftrag benötigt wird. (Matthias)
Netzwerkproblem GCP-Zugriff Hauptstakeholder: 
Verfolge weiterhin die Kommunikation mit Telekom und Arista bezüglich der Paketverluste und Performance-Probleme beim GCP-Zugriff des Hauptstakeholders und halte Matthias über den Status auf dem Laufenden. (Dominik)