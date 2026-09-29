-- =============================================================================
-- 03_footprint_dashboard.sql | SQL twin of the Global Footprint page
-- =============================================================================

-- name: footprint_kpis
SELECT COUNT(*)                        AS stores,
       COUNT(DISTINCT country)         AS countries,
       COUNT(DISTINCT city)            AS cities,
       COUNT(DISTINCT brand)           AS brands,
       COUNT(DISTINCT ownership_type)  AS ownership_types
FROM   stores;

-- name: market_ranking_share
-- "Market Ranking & Share" table: rank, stores, share, cumulative share (Pareto)
SELECT RANK() OVER (ORDER BY COUNT(*) DESC)                                        AS market_rank,
       country,
       COUNT(*)                                                                    AS stores,
       COUNT(DISTINCT city)                                                        AS cities,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)                          AS share_pct,
       ROUND(100.0 * SUM(COUNT(*)) OVER (ORDER BY COUNT(*) DESC, country
                                         ROWS UNBOUNDED PRECEDING)
                   / SUM(COUNT(*)) OVER (), 2)                                     AS cumulative_share_pct
FROM   stores
GROUP  BY country
ORDER  BY market_rank, country;

-- name: concentration_top_markets
-- Insight text: "US = 53%, top 5 markets = 78%"
WITH c AS (
    SELECT country, COUNT(*) AS n,
           ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC, country) AS rk
    FROM stores GROUP BY country
)
SELECT ROUND(100.0 * SUM(CASE WHEN rk = 1 THEN n END) / SUM(n), 1) AS top1_share_pct,
       ROUND(100.0 * SUM(CASE WHEN rk <= 5 THEN n END) / SUM(n), 1) AS top5_share_pct,
       ROUND(100.0 * SUM(CASE WHEN rk <= 10 THEN n END) / SUM(n), 1) AS top10_share_pct
FROM c;

-- name: ownership_mix
-- Donut chart + insight "Company 46.6% / Licensed 36.6% / JV 15.5% / Franchise 1.2%"
SELECT ownership_type,
       COUNT(*)                                             AS stores,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)   AS share_pct
FROM   stores
GROUP  BY ownership_type
ORDER  BY stores DESC;

-- name: ownership_by_country
-- 100% stacked bar + insight "Japan 86% JV; Korea & Taiwan 100% JV; Mexico 100% licensed"
SELECT country,
       COUNT(*)                                                                   AS stores,
       ROUND(100.0 * SUM(CASE WHEN ownership_type = 'Company Owned' THEN 1 ELSE 0 END) / COUNT(*), 1) AS company_pct,
       ROUND(100.0 * SUM(CASE WHEN ownership_type = 'Licensed'      THEN 1 ELSE 0 END) / COUNT(*), 1) AS licensed_pct,
       ROUND(100.0 * SUM(CASE WHEN ownership_type = 'Joint Venture' THEN 1 ELSE 0 END) / COUNT(*), 1) AS joint_venture_pct,
       ROUND(100.0 * SUM(CASE WHEN ownership_type = 'Franchise'     THEN 1 ELSE 0 END) / COUNT(*), 1) AS franchise_pct
FROM   stores
GROUP  BY country
HAVING COUNT(*) >= 100
ORDER  BY stores DESC;

-- name: top_cities
-- "City-led growth: Shanghai leads with 542 stores" (Chinese city names are kept as in source)
SELECT RANK() OVER (ORDER BY COUNT(*) DESC) AS city_rank,
       city, country, COUNT(*) AS stores
FROM   stores
WHERE  city IS NOT NULL
GROUP  BY city, country
ORDER  BY city_rank, city
LIMIT  10;

-- name: small_markets
-- Recommendation: "review the 18 markets with under 10 stores"
SELECT country, COUNT(*) AS stores
FROM   stores
GROUP  BY country
HAVING COUNT(*) < 10
ORDER  BY stores, country;
