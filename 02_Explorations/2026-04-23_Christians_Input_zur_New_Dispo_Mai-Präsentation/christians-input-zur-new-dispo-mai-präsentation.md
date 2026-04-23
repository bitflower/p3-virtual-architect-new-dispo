# Christians Input zur New Dispo Mai-Präsentation

**Date:** 2026-04-23
**Status:** Exploration
**Quellen:**
- `00_Meetings/2026-04-23_Nagel x P3 _ Weekly-Christian-Input-Mai-Präso-wichtig.vtt`
- `00_Meetings/2026-04-23_Nagel x P3 _ Weekly-Christian-Input-Mai-Präso-wichtig/image.png` (Teams-Chat)

---

## Original User Input

> Was hat Christian im Detail zur New Dispo Präsentation gesagt?

---

## Kontext

Weekly-Meeting zwischen Nagel (Christian Lang, Patrick Uschmann) und P3 (Martin Dittmann, Matthias Max, Ledian Xhani) am 23.04.2026. Martin hatte die Management-Präsentation als Agenda-Punkt aufgenommen.

---

## Christians Aussagen zur Mai-Präsentation (im Detail)

### 1. Termin und Präsentator

- **Datum:** 19. Mai 2026 (Management-Präsentation)
- **Präsentator:** Max Beisheim
- Christian hat heute Mittag (23.04.) einen Austauschtermin mit Elisa, die Max Beisheim abholt/vorbereitet

> *Christian (04:26):* "Max Beisheim."
> *Christian (04:28):* "Haben wir heute Mittag nochmal 'n Austauschtermin, dann holt ihn Elisa ab."

### 2. Anforderungen an die Demo

**Was muss funktionieren:**
- Das Frontend muss per se laufen (keine roten Fehlermeldungen)
- Items auf die Tour draufziehen (links/rechts)
- Transporter bearbeiten
- Tour an `timo.com` schicken (Optimierung)
- Grundsätzlich: eine "funktionierende Testumgebung"

**Was NICHT nötig ist:**
- End-to-End-Funktionalität ist nicht erforderlich

> *Christian (04:31):* "Also wichtig wäre halt, dass das Frontend per se läuft, ne."

### 3. Warnung / Negativerfahrung

Christian verweist auf eine **frühere Vorstellung der New Dispo intern ("SteerCo")**, bei der es **nur rote Fehlermeldungen** gab. Das darf sich nicht wiederholen:

> *Christian (04:33):* "Wir hatten das schon mal vorgestellt, die [New] Dispo in der in der SteerCo intern, da gab es halt eigentlich nur rote Fehlermeldungen, das können wir da uns halt nicht erlauben."

### 4. Christians Formulierung der Mindestanforderung

> *Christian (04:45):* "Wenn wir einfach da die Items draufziehen können, links rechts, Transporter [...] bisschen editieren, dann [...] schicken et cetera, also eigentlich so ne funktionierende Testumgebung, dann ist es völlig ausreichend."

### 5. Teams-Nachricht nach dem Meeting (14:56 Uhr) -- Verschärfung

Christian hat nach dem Weekly nochmal per Teams an Martin geschrieben und die Dringlichkeit **deutlich verschärft**:

> **Christian Lang (14:56):**
> "Hi Martin, das New Dispo als klickbare Testversion ist wirklich wichtig. Nicht sicher, ob das ggf etwas unterging. Wir müssen hier mal zeigen wie die App funktionieren würde ohne ständig rote Fehlermeldungen zu bekommen. **Das wäre für Max Beisheim ein Desaster.** Wenn ihr hierzu nochmal Input braucht gerne Bescheid geben. **Es muss nicht mit dem Backend funktionieren. Wenn das Frontend klickbar ist, reicht es völlig aus.**"

**Neue / verschärfte Erkenntnisse aus der Teams-Nachricht:**

- Christian befürchtet, dass die Wichtigkeit im Meeting **untergegangen** sein könnte ("Nicht sicher, ob das ggf etwas unterging")
- Explizit: **"Das wäre für Max Beisheim ein Desaster"** -- Fehlermeldungen bei der Präsentation
- Noch klarer als im Meeting: **Backend-Anbindung ist nicht nötig** -- reines Frontend-Klicken reicht
- Angebot: Christian bietet Input an, falls P3 was braucht

> **Martin Dittmann (16:10):**
> "Hi Christian, 100% bei dir - das muss sichergestellt sein. Ich hab das auf dem Schirm und werde es am Montag auch direkt mit Max Kehder besprechen, dass wir das auch in der Sprint Planning berücksichtigen und gut vorbereiten."

**Martins Zusage:** Besprechung mit Max Kehder am Montag (28.04.), Aufnahme ins Sprint Planning.

---

## Abgeleitete Action Items

| # | Action | Owner | Deadline |
|---|--------|-------|----------|
| 1 | Deployment Freeze vor dem 19.05. koordinieren (keine neuen Deployments auf Test-Umgebung kurz vor Präsentation) | Patrick Uschmann / Max Kehler | KW 19 (nach Rückkehr Max Kehler am 28.04.) |
| 2 | Sicherstellen, dass Frontend stabil auf Test-Umgebung läuft (keine roten Fehlermeldungen) | P3 Dev-Team | vor 19.05.2026 |
| 3 | Demo-Szenario definieren und testen: Items auf Tour ziehen, Transporter editieren, Tour senden | P3 / Nagel gemeinsam | vor 19.05.2026 |
| 4 | Abstimmen mit Max Beisheim / Elisa, was genau gezeigt werden soll | Christian Lang | 23.04.2026 (heute Mittag) |

---

## Weitere relevante Themen aus dem Meeting

### Martins Ergänzung zum Freeze
Martin schlägt vor, vor der Präsentation einen kurzen **Deployment Freeze** einzubauen, damit die Umgebung stabil bleibt (es gibt aktuell nur eine Umgebung = Test):

> *Martin (04:07):* "Dass wir [...] nicht gerade vorher was Neues deployen, weil es jetzt gerade eine Umgebung ist."
> *Martin (04:16):* "Kurzzeitig mal einfach da 'n Freeze einbauen."

### Oracle Deployment Risiko (rot)
Matthias markiert den Oracle Legacy Deployment-Prozess (Dev -> ABN -> UAT -> Prod) als Risiko, weil er noch nie end-to-end miterlebt wurde. Christian relativiert:

> *Christian (06:45):* "Ja, ist ja bei uns eigentlich gang und gäbe. Also Oracle, ich glaube seit 35 Jahren."
> *Christian (06:53):* "Ja, also professionell, gerade mit Liquid Base, tatsächlich, aber da mache ich mir jetzt weniger Sorgen."
> *Christian (07:05):* "Also, ich glaub, wenn wir einmal Deployment hinbekommen haben, produktionsreif, dann werden Folge-Deployments kein Thema sein."

---

## Zusammenfassung

Christians Kernbotschaft zur Mai-Präsentation ist klar und wurde nach dem Meeting per Teams nochmal verschärft: **Das Frontend muss als klickbare Testversion stabil laufen -- rote Fehlermeldungen wären "ein Desaster für Max Beisheim".** Backend-Anbindung ist explizit nicht nötig, reines Frontend-Klicken reicht (Items zuweisen, Transporter editieren, Tour senden). Referenz auf ein früheres Debakel bei einer internen SteerCo-Vorstellung. Max Beisheim präsentiert am 19.05., Vorbereitung läuft über Elisa. Martin hat zugesagt, das am 28.04. mit Max Kehder im Sprint Planning zu berücksichtigen. Deployment Freeze vor dem Termin koordinieren.
