Hi guys,
 
I have implemented pDis_transportorder.SetDriver procedure according to information we had in this sprint, but after making a PR, Joachim wrote me next.
 
Joachim: "Good Morning, Sonja! Your procedures to change the driver are not as easy as it seems. Driver is relevant for Driver Terminal. You can't change driver, if an other driver has authentified with his signature at the terminal. For this case we have to define an action in the pTA_Lib and check it with pTA.Exec. Can you please create a follow up task to harden the new procedures."
 
So I wanted to consult with you about this, how to proceed, should we implement current version of pDis_transportorder.SetDriver procedure on ABN1034 so Boyan and Krys can test this current version, or create a following PBI and test after finishing whole implementation?

## Austausch Joachim

Wenn der Fahrer bereits unterschrieben hat (unterschreibt für Ware = Gefahrenübergang), darf der Fahrer NICHT mehr geändert werden.

## Lösung

Prüfen des Transportauftrags vor dem setzen per `UPDATE`:

- `pTA_Lib`: Bibliothek mit Konstanten (PostGres-Schema, früher opracle package)
  - klassisches TMS Core Muster: Für jede Aktion gibt es eine Konstante
  - wird von Joachim übernommen: Aktion für den Driver gibt es noch nicht => Abhängigkeit für Sonja
- `pTA.Exec`
  - Wissen:
    - Prüft nicht nur, sondern würde auch den Zustand des Transport Order ändern (sofern es Einfluss hat)
    - Nutzt `CANEXECUTE`: prüft der Aktion gegen den Transport Order
    - Jede Aktion kann zusatandsänderung hervorrufen
    - ZENTRALE Komponente!
    - Wir bauen einen weiteren `ELSEIF` ein
    - Prüfen:
      - Hat der Fahrer unterschrirben (gleich bedeutend mit "abgefertigt")
  - Wird von Joachim übernommen

```sql
--
-- Name: SetDriver(numeric, numeric, varchar, varchar) ; Type: PROCEDURE; Schema: pDIS_TransportOrder; Owner: -
-- Description: Sets or updates driver data for a transport order with UPDATE/INSERT fallback pattern
--
CREATE OR REPLACE PROCEDURE pDIS_TransportOrder.SetDriver(
    TransportOrderId NUMERIC,
    DriverNo         NUMERIC,   -- Fahrer-ID from fuzzy search (NULL for manual entry)
    DriverName       VARCHAR,   -- Always required (plaintext)
    PhoneNumber      VARCHAR    -- Phone with country code (plaintext)
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validate: DriverName must always be provided
    IF DriverName IS NULL OR trim(DriverName) = '' THEN
        RAISE EXCEPTION 'DriverName is required';
    END IF;

    -- NEW CONDITION REQUIRED! PSEUDO-CODE (IF ....)
    pTa.Exec(TransportOrderId, pTA_Lib.(ACTION_TAMODDRIVER())) -- Action = pTA_Lib bereitgestellt

    -- NOTE: No manual encryption needed - BEFORE INSERT/UPDATE trigger 'trbiu_sen_frk_unt_crypt'
    -- automatically encrypts fahrer_name and mobil_tel_n for GDPR compliance

    -- Try UPDATE first (Change Driver scenario - existing sen_frk_unt record)
    UPDATE sen_frk_unt
    SET
        fahrer_n    = DriverNo,         -- Set FK if known driver, NULL for manual entry
        fahrer_name = DriverName,       -- Plaintext - encrypted by trigger
        mobil_tel_n = PhoneNumber,      -- Plaintext - encrypted by trigger
        u_version   = cal_util.getuversion(u_version),
        u_time      = pTA.gete(),
        u_user      = pTA.getuser()
    WHERE sen_tix = TransportOrderId
      AND lfd_n   = 1;

    -- Fallback INSERT if not found (Add Driver scenario - legacy data without sen_frk_unt)
    IF NOT FOUND THEN
        INSERT INTO sen_frk_unt(
            sen_tix, lfd_n, u_version, c_time, c_user, u_time, u_user,
            unt_tix, firma, nl, fahrer_n, fahrer_name, mobil_tel_n
        )
        VALUES(
            TransportOrderId, 1, '!',
            pTA.gete(), pTA.getuser(), pTA.gete(), pTA.getuser(),
            NULL, pTA.getfirma(), pTA.getnl(),
            DriverNo, DriverName, PhoneNumber  -- Plaintext - encrypted by trigger
        );
    END IF;
END;
$$;

```