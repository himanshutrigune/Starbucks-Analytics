-- =============================================================================
-- 01_schema.sql  |  Tables + views behind the Starbucks Power BI dashboard
-- Dialect: ANSI SQL, tested on SQLite 3.45. Works on PostgreSQL / MySQL 8 /
-- SQL Server with the small notes at the bottom of this file.
-- =============================================================================

DROP VIEW  IF EXISTS v_beverages_pbi;
DROP VIEW  IF EXISTS v_beverages_known;
DROP TABLE IF EXISTS beverages;
DROP TABLE IF EXISTS stores;

-- Nutrition menu: one row per drink x size/milk preparation (242 rows)
CREATE TABLE beverages (
    row_id           INTEGER PRIMARY KEY,
    category         TEXT    NOT NULL,
    beverage         TEXT    NOT NULL,
    prep             TEXT    NOT NULL,
    calories         INTEGER NOT NULL,
    total_fat_g      REAL,
    trans_fat_g      REAL,
    sat_fat_g        REAL,
    sodium_mg        INTEGER,
    carbs_g          INTEGER,
    cholesterol_mg   INTEGER,
    fibre_g          INTEGER,
    sugars_g         INTEGER,
    protein_g        REAL,
    vit_a_pct        REAL,
    vit_c_pct        REAL,
    calcium_pct      REAL,
    iron_pct         REAL,
    caffeine_mg      REAL,            -- NULL = unknown ('Varies' or blank in source)
    caffeine_status  TEXT NOT NULL CHECK (caffeine_status IN ('known','varies','blank'))
);

-- Store directory: one row per store (25,600 rows)
CREATE TABLE stores (
    store_id        INTEGER PRIMARY KEY,   -- surrogate key (store_number has 1 duplicate)
    brand           TEXT,
    store_number    TEXT,
    store_name      TEXT,
    ownership_type  TEXT,
    street_address  TEXT,
    city            TEXT,
    state_province  TEXT,
    country         TEXT NOT NULL,
    postcode        TEXT,
    phone           TEXT,
    timezone        TEXT,
    longitude       REAL,
    latitude        REAL
);

CREATE INDEX ix_stores_country   ON stores(country);
CREATE INDEX ix_stores_ownership ON stores(ownership_type);
CREATE INDEX ix_bev_category     ON beverages(category);

-- -----------------------------------------------------------------------------
-- v_beverages_pbi : EXACT replica of the Power BI 'starbucks' table
--   Power Query does: 'Varies' -> "0", then drops rows with blank caffeine.
--   => 241 rows, unknown caffeine counted as 0 (this understates Avg Caffeine).
-- -----------------------------------------------------------------------------
CREATE VIEW v_beverages_pbi AS
SELECT b.*, COALESCE(caffeine_mg, 0) AS caffeine_mg_pbi
FROM   beverages b
WHERE  caffeine_status <> 'blank';

-- -----------------------------------------------------------------------------
-- v_beverages_known : only drinks whose caffeine is actually published (219 rows)
--   Use this for an honest average caffeine.
-- -----------------------------------------------------------------------------
CREATE VIEW v_beverages_known AS
SELECT * FROM beverages WHERE caffeine_status = 'known';

-- Dialect notes ---------------------------------------------------------------
--  PostgreSQL : INTEGER PRIMARY KEY -> SERIAL/GENERATED ALWAYS AS IDENTITY; load with \copy
--  SQL Server : TEXT -> NVARCHAR(200); load with BULK INSERT; add SQRT is native
--  MySQL 8    : TEXT keys need lengths; window functions supported from 8.0
