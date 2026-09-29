-- =============================================================================
-- 04_advanced_analytics.sql | Questions the dashboard cannot answer on its own
-- Techniques: CTEs, window functions (RANK, NTILE, ROW_NUMBER, running totals),
-- conditional aggregation, self-benchmarking, concentration (HHI).
-- =============================================================================

-- name: healthiest_drinks_scorecard
-- Composite score = average of percentile ranks (lower is healthier) for
-- calories, sugar and saturated fat. Top 10 among drinks with >= 5 g protein.
WITH scored AS (
    SELECT category, beverage, prep, calories, sugars_g, sat_fat_g, protein_g,
           PERCENT_RANK() OVER (ORDER BY calories)  AS p_cal,
           PERCENT_RANK() OVER (ORDER BY sugars_g)  AS p_sug,
           PERCENT_RANK() OVER (ORDER BY sat_fat_g) AS p_fat
    FROM   v_beverages_pbi
)
SELECT ROW_NUMBER() OVER (ORDER BY (p_cal + p_sug + p_fat) / 3.0, protein_g DESC) AS rk,
       category, beverage, prep, calories, sugars_g, sat_fat_g, protein_g,
       ROUND((p_cal + p_sug + p_fat) / 3.0, 3) AS health_risk_score
FROM   scored
WHERE  protein_g >= 5
ORDER  BY rk
LIMIT  10;

-- name: top_drink_per_category_by_sugar
-- Highest-sugar preparation inside each category (ROW_NUMBER per partition)
WITH r AS (
    SELECT category, beverage, prep, sugars_g, calories,
           ROW_NUMBER() OVER (PARTITION BY category ORDER BY sugars_g DESC, calories DESC) AS rn
    FROM   v_beverages_pbi
)
SELECT category, beverage, prep, sugars_g, calories
FROM   r WHERE rn = 1
ORDER  BY sugars_g DESC;

-- name: sugar_density_by_category
-- Sugar as share of calories (4 kcal per g of sugar) - explains WHY sugar drives calories
SELECT category,
       ROUND(AVG(sugars_g), 1)                                             AS avg_sugar_g,
       ROUND(AVG(calories), 1)                                             AS avg_calories,
       ROUND(100.0 * SUM(sugars_g * 4.0) / NULLIF(SUM(calories), 0), 1)    AS sugar_kcal_pct_of_calories
FROM   v_beverages_pbi
GROUP  BY category
HAVING AVG(calories) > 20
ORDER  BY sugar_kcal_pct_of_calories DESC;

-- name: size_step_up_cost
-- Calories added when a customer upsizes Short -> Tall -> Grande -> Venti (nonfat milk lines)
WITH sized AS (
    SELECT beverage,
           CASE prep WHEN 'Short Nonfat Milk'  THEN 1 WHEN 'Tall Nonfat Milk'  THEN 2
                     WHEN 'Grande Nonfat Milk' THEN 3 WHEN 'Venti Nonfat Milk' THEN 4 END AS size_no,
           calories
    FROM   v_beverages_pbi
    WHERE  prep IN ('Short Nonfat Milk','Tall Nonfat Milk','Grande Nonfat Milk','Venti Nonfat Milk')
)
SELECT size_no,
       CASE size_no WHEN 1 THEN 'Short' WHEN 2 THEN 'Tall' WHEN 3 THEN 'Grande' ELSE 'Venti' END AS size,
       ROUND(AVG(calories), 1)                                                       AS avg_calories,
       ROUND(AVG(calories) - LAG(AVG(calories)) OVER (ORDER BY size_no), 1)          AS added_vs_previous_size
FROM   sized
GROUP  BY size_no
ORDER  BY size_no;

-- name: market_quartiles
-- NTILE(4) segments countries by store count -> strategy tiers
WITH c AS (SELECT country, COUNT(*) AS stores FROM stores GROUP BY country)
SELECT NTILE(4) OVER (ORDER BY stores DESC)   AS tier,
       country, stores
FROM   c
ORDER  BY tier, stores DESC;

-- name: market_tier_summary
WITH c AS (SELECT country, COUNT(*) AS stores FROM stores GROUP BY country),
     t AS (SELECT country, stores, NTILE(4) OVER (ORDER BY stores DESC) AS tier FROM c)
SELECT tier,
       COUNT(*)                                             AS markets,
       SUM(stores)                                          AS stores,
       ROUND(100.0 * SUM(stores) / (SELECT SUM(stores) FROM t), 2) AS share_pct,
       MIN(stores) AS min_stores, MAX(stores) AS max_stores
FROM   t GROUP BY tier ORDER BY tier;

-- name: market_concentration_hhi
-- Herfindahl-Hirschman Index of store distribution across countries (0-10,000)
-- >2,500 = highly concentrated (antitrust rule of thumb)
WITH c AS (SELECT country, COUNT(*) * 1.0 AS n FROM stores GROUP BY country),
     s AS (SELECT n / (SELECT SUM(n) FROM c) AS share FROM c)
SELECT ROUND(SUM(share * share) * 10000, 0) AS hhi_countries,
       CASE WHEN SUM(share * share) * 10000 > 2500 THEN 'Highly concentrated'
            WHEN SUM(share * share) * 10000 > 1500 THEN 'Moderately concentrated'
            ELSE 'Unconcentrated' END        AS interpretation
FROM   s;

-- name: dominant_city_per_country
-- How dependent is each big market on one city? (share of the country held by #1 city)
WITH cc AS (
    SELECT country, city, COUNT(*) AS stores,
           ROW_NUMBER() OVER (PARTITION BY country ORDER BY COUNT(*) DESC, city) AS rn,
           SUM(COUNT(*)) OVER (PARTITION BY country)                              AS country_stores
    FROM   stores
    WHERE  city IS NOT NULL
    GROUP  BY country, city
)
SELECT country, city AS top_city, stores AS top_city_stores, country_stores,
       ROUND(100.0 * stores / country_stores, 1) AS top_city_share_pct
FROM   cc
WHERE  rn = 1 AND country_stores >= 300
ORDER  BY top_city_share_pct DESC
LIMIT  10;

-- name: ownership_model_by_market_size
-- Do small markets prefer licensing? Ownership mix by market-size band
WITH c AS (SELECT country, COUNT(*) AS n FROM stores GROUP BY country),
     band AS (SELECT country,
                     CASE WHEN n >= 1000 THEN '1) 1,000+ stores'
                          WHEN n >= 100  THEN '2) 100-999'
                          WHEN n >= 10   THEN '3) 10-99'
                          ELSE                '4) under 10' END AS size_band
              FROM c)
SELECT b.size_band,
       COUNT(DISTINCT b.country)                                                             AS markets,
       COUNT(*)                                                                              AS stores,
       ROUND(100.0 * SUM(CASE WHEN s.ownership_type = 'Company Owned' THEN 1 ELSE 0 END) / COUNT(*), 1) AS company_pct,
       ROUND(100.0 * SUM(CASE WHEN s.ownership_type = 'Licensed'      THEN 1 ELSE 0 END) / COUNT(*), 1) AS licensed_pct,
       ROUND(100.0 * SUM(CASE WHEN s.ownership_type = 'Joint Venture' THEN 1 ELSE 0 END) / COUNT(*), 1) AS jv_pct
FROM   stores s JOIN band b ON b.country = s.country
GROUP  BY b.size_band
ORDER  BY b.size_band;
