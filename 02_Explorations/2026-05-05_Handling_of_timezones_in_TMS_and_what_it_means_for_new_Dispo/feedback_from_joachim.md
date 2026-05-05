# Feedback from Joachim Schreiner (2026-05-04)

**Re: TMS Timestamps — Timezone-Klärung für New Dispo**

---

Hallo zusammen,

eine Anmerkung zur Ausgangslage:
Die 4 UTC-Felder SEN_HST.C_UTC, SEN_HST.EREIGNIS_UTC, PST_HST.C_UTC, PST_HST.EREIGNIS_UTC sind sowohl in ORA als auch in PGS als TIMESTAMP WITH TIME ZONE definiert.

00_Meetings/2026-04-30_timezones/image001.png

Wie genau habt ihr getestet, dass ein Wert in Bulgarien mit der falschen Zeitzone gespeichert wird?

Aktuell wird die Zeitzone aus den aktuellen Einstellungen des Datenbank-Servers gezogen.

Eine TimeZone-Setting pro Branch bringt nichts. Bulgarien hat keine eigene Niederlassung, Kunden können aber durchaus dort beliefert oder Transportgut an einen Partnerspediteur übergeben werden.
Für unsere Target-Times, z.B. vereinbarte Liefer-Zeitfenster gilt, dass sie immer in der lokalen Zeit angegeben werden. Wenn dafür allerdings Fahrtdauern und Ankunftszeiten (in lokaler Zeit) kalkuliert werden sollen, muss die Zeitzone des Ziels bekannt sein oder ermittelt werden.
Wäre da nicht die Sommerzeit-Umstellung, könnte man die Zeitzone in Europa am Länderkennzeichen festmachen. (In Europa gibt es kein Land mit mehr als 1 Zeitzone.)
Ich pflichte euch bei: Sobald wir den ersten Transport über eine Zeitzonengrenze haben, haben wir einen Fehler in der Routenberechnung.
Deshalb schlage ich vor, wir übergeben dann bei der Routenberechnung die Zeitzone nicht mehr im DTO an den PTV-XServer, sondern überlassen dem XServer die Zeitzonen-Ermittlung anhand der Adresse und des Referenzdatums.

Zu 2.: Die Zeitzonen-Information in PGS nicht zu ergänzen war wegen der starken Bindung an die Adresse aus dem Kontext eben auch eine bewusste Design-Entscheidung. Wir hatten uns entschieden weiterhin wie in ORA nur die lokale Zeit zu speichern. Dass wir die UTC-Zeiten in die Ereignisse aufgenommen haben, hat den Grund, dass die Ereignisse (fast) ausnahmslos im Kontext einer Niederlassung entstehen und damit die Zeitzone leicht zu ergänzen ist.

Viele Grüße
Joachim
