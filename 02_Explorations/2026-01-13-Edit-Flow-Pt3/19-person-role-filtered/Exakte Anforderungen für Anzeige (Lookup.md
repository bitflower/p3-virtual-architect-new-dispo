Exakte Anforderungen für Anzeige (Lookup) und Zuweisung von Contractor und Carrier (Product Owner Sicht)
Lookup-Anzeige (Auswahl von Contractor und Carrier):
Bei der Auswahl sollen sowohl Unternehmer Nahverkehr (UNN) als auch Unternehmer Fernverkehr (UNF) angezeigt werden, damit alle relevanten Personen auswählbar sind. 1
Wenn eine Person beide Rollen hat (UNN und UNF), soll sie nur einmal angezeigt werden, nicht doppelt. 2
Die Filterung im Frontend muss beide Rollen berücksichtigen, aktuell wird nur UNF genutzt, das muss angepasst werden. 3
Zuweisung zum Transportauftrag:
Bei der Zuweisung wird die Rolle übernommen, mit der die Person im Stamm eingetragen ist (UNN oder UNF). 4
Wenn eine Person beide Rollen hat, ist es egal, welche Rolle übernommen wird – es wird die zuerst gefundene genommen. 5
Für Carrier wird das Kürzel FRF (Frachtführer) im Transportauftrag gesetzt, unabhängig von der ursprünglichen Rolle. 6
Für Contractor wird das Kürzel UNN oder UNF entsprechend der Auswahl gesetzt. 7
Es darf bei der Zuweisung nur ein Wert pro Person gesetzt werden, keine Mehrfachzuordnung. 8
Technische Umsetzung & Hinweise:
Die Stammdaten enthalten für jede Person mehrere Datensätze, falls sie mehrere Rollen hat. Die Auswahl erfolgt über die Personen-ID und die jeweilige Rolle. 9
Die Logik ist im Frontend schnell anpassbar, da nur die Filterung erweitert werden muss. 10
Die Rollenvergabe in den Stammdaten wird perspektivisch vereinfacht, da die Unterscheidung zwischen Nah- und Fernverkehr an Bedeutung verliert. 11
Zusätzliche Anforderungen:
Bei der Vorblendung (Anzeige) dürfen Personen mit beiden Rollen nicht doppelt erscheinen. 12
Die Zuweisung muss sauber dokumentiert und an das Team kommuniziert werden. 13


https://teams.microsoft.com/l/message/19:meeting_YWVkZTU0MDgtMTVjMy00YzE0LWJlZmYtOTM5NGVhYzdlZjIw@thread.v2/1770307151477?context=%7B%22contextType%22%3A%22chat%22%7D

## Bestätigung von Joachim

Wenn wir hier also die v_pers_tb verwenden, sollte das passen? Das haben wir nämlich schon so implementiert => Ja.

## Implikation

Frontend beindet die Stack bis zu v_pers_tb berets ein. Es kann dort einfach der Filter erweitert werden auf UNF + UNN.