-- =============================================================================
-- 02_nutrition_dashboard.sql | SQL twin of the Report + Nutrition Insights pages
-- Each block starts with "-- name: <id>" so python/run_sql.py can execute,
-- export and test it.
-- =============================================================================

-- name: nutrition_kpis
-- Same four cards as the dashboard (Power BI logic: 241 rows, Varies = 0)
SELECT COUNT(DISTINCT beverage)              AS total_beverages,
       ROUND(AVG(calories), 2)               AS avg_calories,
       ROUND(AVG(sugars_g), 2)               AS avg_sugar_g,
       ROUND(AVG(caffeine_mg_pbi), 2)        AS avg_caffeine_dashboard,
       ROUND(AVG(protein_g), 2)              AS avg_protein_g
FROM   v_beverages_pbi;

-- name: caffeine_true_average
-- Honest caffeine average: unknown ('Varies') excluded instead of counted as 0
SELECT COUNT(*)                     AS drinks_with_known_caffeine,
       ROUND(AVG(caffeine_mg), 2)   AS avg_caffeine_true_mg
FROM   v_beverages_known;

-- name: category_ranking
-- "Category Ranking & Share" table: rank + share the dashboard never had
SELECT RANK() OVER (ORDER BY AVG(sugars_g) DESC)                          AS sugar_rank,
       category,
       COUNT(DISTINCT beverage)                                           AS beverages,
       COUNT(*)                                                           AS drink_rows,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                 AS share_of_menu_pct,
       ROUND(AVG(calories), 1)                                            AS avg_calories,
       ROUND(AVG(sugars_g), 1)                                            AS avg_sugar_g,
       ROUND(AVG(protein_g), 1)                                           AS avg_protein_g,
       ROUND(AVG(caffeine_mg_pbi), 1)                                     AS avg_caffeine_dashboard,
       ROUND(AVG(caffeine_mg), 1)                                         AS avg_caffeine_true
FROM   v_beverages_pbi
GROUP  BY category
ORDER  BY sugar_rank;

-- name: prep_avg_calories
-- Column chart "Avg Calories by Beverage prep"
SELECT prep,
       COUNT(*)                 AS drink_rows,
       ROUND(AVG(calories), 1)  AS avg_calories
FROM   v_beverages_pbi
GROUP  BY prep
ORDER  BY avg_calories DESC;

-- name: sugar_threshold_counts
-- Insight text: "61% of drinks exceed 25 g sugar (146 of 241); 47 have 50 g+"
SELECT COUNT(*)                                                    AS drinks,
       SUM(CASE WHEN sugars_g >  25 THEN 1 ELSE 0 END)             AS over_25g,
       ROUND(100.0 * AVG(CASE WHEN sugars_g > 25 THEN 1.0 ELSE 0 END), 1) AS over_25g_pct,
       SUM(CASE WHEN sugars_g >= 50 THEN 1 ELSE 0 END)             AS at_least_50g
FROM   v_beverages_pbi;

-- name: correlations
-- Insight text: "r = 0.91 sugar vs calories; caffeine unrelated (r ~ 0.05)"
-- Pearson r written out, so it runs on any engine (PostgreSQL: use CORR(x, y)).
WITH s AS (
    SELECT COUNT(*) n,
           SUM(calories) sx,  SUM(calories * calories) sxx,
           SUM(sugars_g) sy,  SUM(sugars_g * sugars_g) syy, SUM(calories * sugars_g) sxy,
           SUM(caffeine_mg_pbi) sz, SUM(caffeine_mg_pbi * caffeine_mg_pbi) szz,
           SUM(calories * caffeine_mg_pbi) sxz
    FROM v_beverages_pbi
)
SELECT n AS drinks,
       ROUND((n*sxy - sx*sy) / SQRT((n*sxx - sx*sx) * (n*syy - sy*sy)), 3) AS r_calories_sugar,
       ROUND((n*sxz - sx*sz) / SQRT((n*sxx - sx*sx) * (n*szz - sz*sz)), 3) AS r_calories_caffeine
FROM s;

-- name: sugar_hotspot
-- Insight text: "Frappuccino Blended Coffee is the sugar hotspot: 57 g vs 33 g menu avg"
SELECT category,
       ROUND(AVG(sugars_g), 1)                                                      AS avg_sugar_g,
       (SELECT ROUND(AVG(sugars_g), 1) FROM v_beverages_pbi)                        AS menu_avg_sugar_g,
       ROUND(AVG(sugars_g) - (SELECT AVG(sugars_g) FROM v_beverages_pbi), 1)        AS gap_g
FROM   v_beverages_pbi
GROUP  BY category
ORDER  BY avg_sugar_g DESC
LIMIT  1;

-- name: milk_choice_classic_espresso
-- Insight text: "soymilk espresso avg 151 kcal vs 184 on 2% milk (-18%)"
WITH m AS (
    SELECT prep, AVG(calories) AS avg_cal
    FROM   v_beverages_pbi
    WHERE  category = 'Classic Espresso Drinks' AND prep IN ('Soymilk', '2% Milk')
    GROUP  BY prep
)
SELECT ROUND(MAX(CASE WHEN prep = 'Soymilk' THEN avg_cal END), 1)   AS soymilk_kcal,
       ROUND(MAX(CASE WHEN prep = '2% Milk' THEN avg_cal END), 1)   AS two_pct_kcal,
       ROUND(100.0 * (MAX(CASE WHEN prep = 'Soymilk' THEN avg_cal END)
                    / MAX(CASE WHEN prep = '2% Milk' THEN avg_cal END) - 1), 0) AS soy_vs_2pct_pct
FROM m;
