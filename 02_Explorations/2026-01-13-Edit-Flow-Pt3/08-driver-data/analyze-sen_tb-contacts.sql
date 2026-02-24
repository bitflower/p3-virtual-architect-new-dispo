-- Analysis: Check contractor/carrier assignments via sen_tb
-- sen_tb stores all contacts for a transport order including:
--   ABS = Absender (Sender)
--   EMP = Empfänger (Recipient)
--   UNN = Unternehmer Nahverkehr (Local Contractor)
--   UNF = Unternehmer Fracht (Long-haul Contractor)
--   FRF = Frachtführer (Carrier)

-- Distribution of contact types (tb) in sen_tb
SELECT
    COALESCE(tb, 'NULL') as contact_type,
    CASE COALESCE(tb, 'NULL')
        WHEN 'UNN' THEN 'Unternehmer Nahverkehr (Local Contractor)'
        WHEN 'UNF' THEN 'Unternehmer Fracht (Long-haul Contractor)'
        WHEN 'FRF' THEN 'Frachtführer (Carrier)'
        WHEN 'ABS' THEN 'Absender (Sender)'
        WHEN 'EMP' THEN 'Empfänger (Recipient)'
        WHEN 'NULL' THEN 'No contact type'
        ELSE 'Other (' || tb || ')'
    END as description,
    COUNT(*) as count_records,
    COUNT(DISTINCT sen_tix) as count_transport_orders,
    ROUND(100.0 * COUNT(DISTINCT sen_tix) / (SELECT COUNT(DISTINCT sendung_tix) FROM sendung), 2) as percentage_of_all_orders
FROM
    sen_tb
GROUP BY
    tb
ORDER BY
    count_records DESC;

-- Additional: Check transport orders with both UNN/UNF and FRF
-- (Uncomment to see transport orders with both contractor and carrier)
/*
WITH contractor_carrier AS (
    SELECT
        s.sendung_tix,
        s.sendung_n,
        s.sendungsart,
        MAX(CASE WHEN st.tb IN ('UNN', 'UNF') THEN st.tb END) as contractor_type,
        MAX(CASE WHEN st.tb IN ('UNN', 'UNF') THEN p.name1 END) as contractor_name,
        MAX(CASE WHEN st.tb = 'FRF' THEN p.name1 END) as carrier_name
    FROM
        sendung s
    LEFT JOIN
        sen_tb st ON s.sendung_tix = st.sen_tix
    LEFT JOIN
        pers p ON st.pers_tix = p.tix
    WHERE
        st.tb IN ('UNN', 'UNF', 'FRF')
    GROUP BY
        s.sendung_tix, s.sendung_n, s.sendungsart
)
SELECT
    CASE
        WHEN contractor_type IS NOT NULL AND carrier_name IS NOT NULL THEN 'Both Contractor and Carrier'
        WHEN contractor_type IS NOT NULL AND carrier_name IS NULL THEN 'Only Contractor'
        WHEN contractor_type IS NULL AND carrier_name IS NOT NULL THEN 'Only Carrier'
        ELSE 'Neither'
    END as assignment_pattern,
    COUNT(*) as count_transport_orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as percentage
FROM
    contractor_carrier
GROUP BY
    CASE
        WHEN contractor_type IS NOT NULL AND carrier_name IS NOT NULL THEN 'Both Contractor and Carrier'
        WHEN contractor_type IS NOT NULL AND carrier_name IS NULL THEN 'Only Contractor'
        WHEN contractor_type IS NULL AND carrier_name IS NOT NULL THEN 'Only Carrier'
        ELSE 'Neither'
    END
ORDER BY
    count_transport_orders DESC;
*/
