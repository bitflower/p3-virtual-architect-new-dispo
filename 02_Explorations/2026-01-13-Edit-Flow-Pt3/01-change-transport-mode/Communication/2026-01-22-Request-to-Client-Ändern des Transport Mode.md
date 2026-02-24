Ändern des Transport Mode
 
Wenn wir den Transport Mode eines Transport Orders, den wir bisher in New Dispo gesehen haben, zukünftig ändern können, müssen wir die Filterung in V_DIS_TRANSPORTORDER_PICKUPPLANNING ändern:
 
Tun wir das, sehen wir aber gleichzeitig plötzlich alle Transport Order - auch solche die wir gar nicht in Pickupplanning haben wollen.
 
Somit fehlt uns eine Entscheidungsgrundlage in der Art:
"ist Transport Mode 60" ODER
"wurde von New Dispo angelegt und ist nicht Transport Mode 60"
Da TMS aber unsere Quelle und Source of Truth der Transport Order ist und unser gesamtes Filterung und Pagination darauf aufbaut, können wir dies nicht auf New Dispo Seite mit einer geführten Liste von IDs lösen.
 
Daher die Frage: Wie können wir das lösen? Wäre ein neues Flag denkbar "CreatedByNewDispo" auf Tabelle sendung?