# Set Vehicle Properties

Wir wollen die Fahrzeug-Eigenschaft setzen. hierzu gibt es bereits eine Datenstruktur in der TMS Datenbank:

- Stehen im "versteckten Tourpoint", den jeder Transport order (=Tabelle `sendung`) hat in Tabelle RES_HST
- RES_HST muss immer über die API geschrieben werden
- Alle Werte stehen im Feld "T" als Liste "vorkuehl_b=T....."