# Developer Chat

## Ivailo

I've executed a request to the v_dis_tp_client_comm and I got ORA-00972: identifier is too long. I am guessing this is because of the field names of the view.

## Matthias

Exactly what the TMS Verifier brought up.

From the report:

```markdown
L5 — Column Failures (MEDIUM)

v_dis_tp_client_comm (View, TMS1060)

Missing columns (2): loadinglocationgloballocationnumber, shippingunitsquantitypalletplacesquantity

Live probe error: ORA-00904: “SHIPPINGUNITSQUANTITYPALLETPLACESQUANTITY”: invalid identifier
https://docs.oracle.com/error-help/db/ora-00904/
```