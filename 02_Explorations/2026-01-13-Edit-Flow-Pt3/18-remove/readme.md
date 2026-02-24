## Remove functions

> **Note:** `RemoveParticipant` is only available in the NEW-DISPO branch (`release/7.0.0.8+NEW-DISPO`).

Integrate into `pDis_TransportOrder`. Align parameter names with existing names in `pdis_transportorder.sql`.

### Procedures

| Procedure                                                    | Status           | Core Function |
| ------------------------------------------------------------ | ---------------- | ------------- |
| `RemoveParticipant(TransportOrderId, ParticipantType, Mode)` | EXISTS (PR #439) | `pta.remunt`  |
| `RemoveTrailer(TransportOrderId, Mode)`                      | TO ADD           | `pta.remanh`  |
| `RemoveVehicle(TransportOrderId, Mode)`                      | TO ADD           | `pta.remlkw`  |

### Participant Types

| Type  | Description                                    |
| ----- | ---------------------------------------------- |
| `UNF` | Long-haul Contractor (Unternehmer Fernverkehr) |
| `UNN` | Local Contractor (Unternehmer Nahverkehr)      |
| `FRF` | Carrier (Frachtführer)                         |

### Cascading Behavior (after TMS Core changes by Joachim)

| Action                           | Removes         |
| -------------------------------- | --------------- |
| `RemoveParticipant('UNF'/'UNN')` | Contractor only |
| `RemoveParticipant('FRF')`       | Carrier only    |
| `RemoveVehicle`                  | Vehicle only    |
| `RemoveTrailer`                  | Trailer only    |

> **Note:** "Remove Contractor" user action requires two calls: `RemoveParticipant(id, 'UNF'/'UNN', mode)` followed by `RemoveParticipant(id, 'FRF', mode)`.

---
