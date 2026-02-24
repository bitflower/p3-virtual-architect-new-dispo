-- Analysis: Distribution of sen_frk_unt records per transport order (all sendungsart)
-- Shows how many transport orders have 0, 1, 2, ... sen_frk_unt records

WITH sendung_record_counts AS (
    SELECT
        s.sendung_tix,
        COUNT(sfu.sen_tix) as num_sen_frk_unt_records
    FROM
        sendung s
    LEFT JOIN
        sen_frk_unt sfu ON s.sendung_tix = sfu.sen_tix
    GROUP BY
        s.sendung_tix
)
SELECT
    num_sen_frk_unt_records,
    COUNT(*) as count_of_transport_orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as percentage
FROM
    sendung_record_counts
GROUP BY
    num_sen_frk_unt_records
ORDER BY
    num_sen_frk_unt_records;

-- Additional detail: Show specific cases where there are multiple sen_frk_unt records
-- (Uncomment to investigate transport orders with multiple records)
/*
SELECT
    s.sendung_tix,
    s.sendung_n,
    s.sendungsart,
    COUNT(sfu.sen_tix) as num_records,
    STRING_AGG(sfu.lfd_n::text, ', ' ORDER BY sfu.lfd_n) as lfd_n_values
FROM
    sendung s
INNER JOIN
    sen_frk_unt sfu ON s.sendung_tix = sfu.sen_tix
GROUP BY
    s.sendung_tix, s.sendung_n, s.sendungsart
HAVING
    COUNT(sfu.sen_tix) > 1
ORDER BY
    num_records DESC, s.sendung_tix
LIMIT 100;
*/
