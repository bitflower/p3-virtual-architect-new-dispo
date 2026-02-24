# Alignment of lead dev

## Request

Können wir nochmal über das Entfernen von Contractor, Carrier, Vehicle und Trailer sprechen? Konntest Du dies nochmal im Detail prüfen (die Pfade). Die Business-Anforderungen sind verifiziert:
 
Postconditions:
The following cascading logic applies:
Removing Contractor removes Contractor and Carrier.
Removing Carrier removes only the Carrier.
Removing Vehicle removes only the Vehicle.
Removing Trailer removes only the Trailer.
Ich war unterwegs und hatte keine Zeit hier aktiv zu werden. Wir müssen diese Fälle unterstützen. Falls Du noch fachliche Bedenken hast, bitte mit Max B. / Patrick besprechen.
 
Für uns relevant sind dann die finalen Interfaces und die Entscheidung, wer un welche Implementierung übernimmt.
 
Auch die Transaktionssicherheit interessiert uns. Falls wir z.B. Contractor und Carrier mit sep. Calls löschen und einer schlägt fehl - gibt dies Probleme?
 
Danke!

## Resposne

Nee, fachliche Bedenken hab ich keine. Ich sorge dafür, dass Vehicle/Trailer nicht zusammen mit dem Unternehmer gelöscht werden und der Trailer nicht zusammen mit dem Vehicle gelöscht wird.
Der Carrier wird - glaube ich - nicht zusammen mit dem Contractor gelöscht. Das müsstet ihr machen. Ob das jetzt die gleiche Transaktion ist, ist ziemlich unerheblich, weil die Aktionen keine inkonsistenten Zustände hinterlassen.

## Confirmation

Ok, das heißt konkret für uns: Einziges Todo ist aktiv den Carrier löschen - entweder in einem Wrapper oder mit 2 Calls aus TMS Bridge. Die restlichen Anforderungen (Erhalt Vehicle/Trailer) implementierst Du in remunt()? Wie wird das aussehen? Ein neues Flag? Oder werden Verhicle und Trailer nun pauschal behalten?

=> "Das Flag wird erst mal nicht von außen gesetzt werden können."