Matthias:

Hi Joachim, wie sieht Euer Migrationsprozess aus? Ihr migriert New Dispo => Oracle auf ENT1034? Dann von der ENT in Euer Oracle Repo?
 
Und wie sieht dann der Rollout in andere Instanzen aus?
 
Joachim:

Normalerweise und aktuell testen wir in unserer ENT1-Umgebung (ohne direkten Bezug zu einer Live-Umgebung).
"Schlimmstenfalls" erstellen wir ein Change Set (Freigabe) in unserem Altsystem und deployen die Änderungen in die anderen Umgebungen - wie die letzten 30 Jahre.

Matthias:

Change Set ist wie ein Pull Request? Wo liegt denn der Code der Oracle?
 
Und die ENT1 ist ein Abzug der 1034 ?
 
Joachim:

Im Azure Repo. https://dev.azure.com/caldevops/Agile/_git/CALtms
Die ENT1 ist kein Abzug der 1034. Ich bin mir nicht sicher, dass wir bei CAL eine ORA DB mit so einem Abzug einrichten. Denn dann gäbe es einen Konflikt zwischen der PGS1034 und der ORA1034 beim Datenaustausch zwischen den Niederlassungen. Das muss eine andere NL sein!

Matthias:

Hi Joachim, DU meinst dieses Unterverzeichnis? https://dev.azure.com/caldevops/Agile/_git/CALtms?path=/SQL

	
            Azure DevOps Services | Sign In
        

 
Joachim Schreiner
Im Azure Repo. https://dev.azure.com/caldevops/Agile/_git/CALtms Die ENT1 ist kein Abzug der 1034. Ich bin mir nicht sicher, dass wir bei CAL eine ORA DB mit so einem Abzug einrichten. Denn dann gäbe…
Aber wir benötigen doch eine DEV, ABN, UAT mit 1060 Bestand und Konfiguration um vorher sauber testen zu können. Dieses Instanzen müssen ja nicht mit der zentralen DB verbunden sein. Sind denn alle PostGres DEV, ABN, UAT Instanzen mit der zentralen Datenbank verlinkt?
 