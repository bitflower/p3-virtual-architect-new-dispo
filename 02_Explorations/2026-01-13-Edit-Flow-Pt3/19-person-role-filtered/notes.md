CAUTION! `person` as look up must be filtered according to the "roles" of a person record. These are stored in `person_special`. Reference: `v_unt_eqm`.

## Problem

Currently the backend / TMS Bridge are connected to the `person` table directly leaving out any role assignment completely. This is used for fuzzy search.

## 2026-01-29

Pseudo Code: z.B. `v_unt` für `UNN` / `UNF` filter

```sql
CREATE VIEW v_unt AS
 SELECT p.pers_tix,
    p.kz_transportbeteil AS tb,
    p.firmennummer AS firma,
    p.niederlassung AS nl,
    p.personennummer AS pers_n,
    p.personen_index AS pers_i,
    p2.name_1 AS pers_name1,
    p2.info_t AS pers_info_t,
    p2.name_alp_sortierun AS pers_match,
        CASE p2.kto_nr_fibu_spezi
            WHEN 'NA'::bpchar THEN 'NL'::text
            WHEN 'NL'::bpchar THEN 'NL'::text
            WHEN 'VU'::bpchar THEN 'VU'::text
            ELSE NULL::text
        END AS pers_art
   FROM (((person_special p
   JOIN person p2)
   WHERE ((p.kz_transportbeteil = ANY (ARRAY['UNN'::bpchar, 'UNF'::bpchar])) AND (p.pers_tix = p2.pers_tix) AND ((p.del_flag <> '1'::bpchar) OR (p.del_flag IS NULL)) AND ((p2.del_flag <> '1'::bpchar) OR (p2.del_flag IS NULL)));
```

Maybe we can include kz_transportbeteil as "role" and then let the backend put "WHERE role = 'UNF'".

Important:

- Return all person columns as if we were SELECTing `person`