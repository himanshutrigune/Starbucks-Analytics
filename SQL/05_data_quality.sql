-- =============================================================================
-- 05_data_quality.sql | Every issue found while auditing the dashboard
-- =============================================================================

-- name: dq_beverages
SELECT 'rows in source'                              AS check_name, COUNT(*) AS n FROM beverages
UNION ALL SELECT 'rows kept by Power BI filter',                   COUNT(*)   FROM v_beverages_pbi
UNION ALL SELECT 'caffeine = Varies (Power BI turns into 0)',      COUNT(*)   FROM beverages WHERE caffeine_status = 'varies'
UNION ALL SELECT 'caffeine blank (row dropped by Power BI)',       COUNT(*)   FROM beverages WHERE caffeine_status = 'blank'
UNION ALL SELECT 'negative or null calories',                      COUNT(*)   FROM beverages WHERE calories IS NULL OR calories < 0;

-- name: dq_stores
SELECT 'store rows'                                AS check_name, COUNT(*) AS n FROM stores
UNION ALL SELECT 'duplicated store_number values',  COUNT(*) FROM (SELECT store_number FROM stores GROUP BY store_number HAVING COUNT(*) > 1)
UNION ALL SELECT 'missing latitude/longitude',      COUNT(*) FROM stores WHERE latitude IS NULL OR longitude IS NULL
UNION ALL SELECT 'missing city',                    COUNT(*) FROM stores WHERE city IS NULL
UNION ALL SELECT 'missing postcode',                COUNT(*) FROM stores WHERE postcode IS NULL
UNION ALL SELECT 'coordinates outside valid range', COUNT(*) FROM stores WHERE ABS(latitude) > 90 OR ABS(longitude) > 180;

-- name: dq_caffeine_bias
-- How much does "Varies -> 0" distort Avg Caffeine per category?
SELECT category,
       ROUND(AVG(caffeine_mg_pbi), 1)                     AS dashboard_avg,
       ROUND(AVG(caffeine_mg), 1)                         AS true_avg,
       ROUND(AVG(caffeine_mg_pbi) - AVG(caffeine_mg), 1)  AS dashboard_minus_true_mg   -- negative = dashboard understates
FROM   v_beverages_pbi
GROUP  BY category
HAVING COUNT(caffeine_mg) > 0
ORDER  BY dashboard_minus_true_mg;
