# Email Draft: TMS Timezone Klärung

**An:** Andre, Reinhardt, Joachim
**Betreff:** TMS Timestamps — Timezone-Klärung für New Dispo

---

Hallo zusammen,

Wir haben bei der Arbeit an New Dispo eine Timezone-Thematik identifiziert, bei der wir eure Bestätigung brauchen.

**Ausgangslage:**
- Joachim hatte am 09.04. bestätigt: Alle Zeitangaben in TMS sind in lokaler Zeit gespeichert (4 Ausnahmen in UTC: SEN_HST.EREIGNIS_UTC, SEN_HST_C_UTC, PST_HST.EREIGNIS_UTC). In Oracle als `TIMESTAMP WITH TIME ZONE`.
- In AlloyDB/Postgres sind diese Felder als `timestamp without time zone` gespeichert — die Timezone-Information ist dort nicht vorhanden.
- Unser Test: Eine Aktion um 12:00 Uhr bulgarischer Zeit wurde als 11:00 Uhr in der Datenbank gespeichert. Das deutet auf deutsche Zeitzone hin.

**Warum ist das relevant?**
New Dispo greift auf mehrere Branches zu, die potenziell in unterschiedlichen Zeitzonen liegen könnten. Ohne Timezone-Information können wir die Timestamps nicht zuverlässig interpretieren.

**Offene Fragen:**
1. Sind alle Branch-Datenbanken in deutscher Zeitzone gehostet? Speziell auch Branch 1060 (GoLive Branch)?
2. Ist die Speicherung ohne Timezone-Information in AlloyDB/Postgres (`timestamp without time zone`) eine bewusste Designentscheidung oder ein Übertragungsartefakt?
3. Ist die Timezone-Definition der Felder bei der Migration von Oracle zu Postgres verloren gegangen?

Falls die Antwort auf (1) "ja" ist, können wir sicher mit der Annahme `Europe/Berlin` arbeiten. Falls nicht, brauchen wir eine Lösung, um die Timezone pro Branch zu konfigurieren.

Danke & Grüße
Matthias
