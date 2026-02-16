/*
------------------------------------------------------------------------------------------------
Title:       UK Bat Diversity - Spatiotemporal Binning & Shannon Index Calculation
Author:      [John Sutton]
Date:        15-02-2026
Description: 
    This query aggregates raw bat occurrence data from GBIF/NBN Atlas into 
    standardized spatial and temporal bins to evaluate reporting and 
    variety/biodiversity trends.
    
    Workflow:
    1.  Exploratory Data Analysis (EDA): Check for data quality issues.
    2.  Data Cleaning: Filter out nulls and invalid taxonomy.
    3.  Aggregation: Groups data into ~80km² cells (S2 Level 10) and 5-year intervals.
    4.  Metric Calculation: Calculates Species Richness (count) and Shannon Diversity 
        Index (H'), and "Sampling Efficiency" (Richness per 100 records).

Key Tables:  `chiroptera.BatsUK.BatsUK` (Raw Occurrences)
Output:      Aggregated CSV for Tableau visualization.
------------------------------------------------------------------------------------------------
*/

-- =========================================================================================
-- STEP 1: EXPLORATORY DATA ANALYSIS (EDA)
-- Purpose: Identifying common remarks to flag automated vs. human entries.
-- Description: 
--    Initial exploration of the `occurrenceRemarks` field to detect patterns of 
--    automated data entry (e.g., "Metadata", "CVI").
--    This step informs the filtering strategy for the main analysis by identifying 
--    high-frequency, low-value text strings.
-- =========================================================================================

SELECT occurrenceRemarks, COUNT(*) as frequency
FROM `chiroptera.BatsUK.BatsUK`
WHERE occurrenceRemarks IS NOT NULL
GROUP BY occurrenceRemarks
ORDER BY frequency DESC
LIMIT 20;


-- =========================================================================================
-- STEP 2: RAW OCCURRENCES EXPORT (FINE-GRAINED SPATIAL DATA FOR INTERACTIVE MAP)
-- Purpose: Export individual occurrences for precise mapping and drill-downs.
-- Description: This query preserves individual records (not aggregated) to allow users
-- to explore specific sightings, dates, and species. 

-- Note on Multi-Resolution Analysis:
-- This query uses S2 Level 12 (~5km² cells) for high-precision mapping of individual points.
-- In contrast, the Aggregated Metrics (Step 3) uses S2 Level 10 (~80km² cells) to smooth 
-- data for regional trend analysis (Shannon Index).
-- =========================================================================================


SELECT
  gbifID,
 
  -- Clean Species Logic (replaces the raw column)
  CASE
    WHEN species IS NULL THEN 'Unidentified Bat'
    ELSE species
  END AS species,

  decimalLatitude,
  decimalLongitude,
  SAFE_CAST(eventDate AS TIMESTAMP) AS eventDate,
 
  -- The Remarks Cleaning Logic (removes metadata artifacts)
  CASE
    WHEN occurrenceRemarks LIKE '%Metadata%' THEN NULL
    WHEN occurrenceRemarks LIKE '%BCT%' THEN NULL
    WHEN occurrenceRemarks LIKE '%CVI%' THEN NULL
    ELSE occurrenceRemarks
  END AS clean_remarks,
 
  -- Species Info Link (direct GBIF lookup)
  CONCAT('https://www.gbif.org/species/', CAST(speciesKey AS STRING)) AS species_info,
 
  -- Spatial Binning (S2 Level 12 = ~5km² cells)
  S2_CELLIDFROMPOINT(ST_GEOGPOINT(decimalLongitude, decimalLatitude), level => 12) AS cell_id

FROM `chiroptera.BatsUK.BatsUK`
WHERE
  decimalLatitude IS NOT NULL
  AND decimalLongitude IS NOT NULL
  AND EXTRACT(YEAR FROM SAFE_CAST(eventDate AS TIMESTAMP)) BETWEEN 1960 AND 2026;




-- =========================================================================================
-- STEP 3: AGGREGATED METRICS (SHANNON INDEX & RICHNESS)
-- Purpose: Calculate biodiversity metrics aggregated by S2 cell and 5-year blocks.
-- Description: 
--   1. Groups data into ~80km² cells (S2 Level 10) and 5-year intervals.
--   2. Calculates 'p' (proportion of total observations) for each species.
--   3. Computes Shannon Diversity Index (H = -Σ p*ln(p)).
--   4. Derives "Reporting Efficiency" (Richness normalized by total records).
-- =========================================================================================

WITH base_data AS (
  SELECT
    species,
    EXTRACT(YEAR FROM SAFE_CAST(eventDate AS TIMESTAMP)) AS year,
    decimalLatitude,
    decimalLongitude
  FROM `chiroptera.BatsUK.BatsUK`
  WHERE decimalLatitude IS NOT NULL
    AND decimalLongitude IS NOT NULL
    AND species IS NOT NULL
    AND species != ''
    AND species NOT LIKE '%nidentified%'
    AND EXTRACT(YEAR FROM SAFE_CAST(eventDate AS TIMESTAMP)) BETWEEN 1960 AND 2026
),

-- 1. Get Species Counts Per Block (Numerator for 'p')
species_counts AS (
  SELECT
    S2_CELLIDFROMPOINT(ST_GEOGPOINT(decimalLongitude, decimalLatitude), level => 10) AS cell_id,
    CAST(FLOOR(year / 5) * 5 AS INT64) AS block_start_year,
    species,
    COUNT(*) AS n
  FROM base_data
  GROUP BY 1, 2, 3
),

-- 2. Get Block Totals (Denominator for 'p')
block_totals AS (
  SELECT
    cell_id,
    block_start_year,
    SUM(n) AS total_records_in_block
  FROM species_counts
  GROUP BY 1, 2
),

-- 3. Calculate Shannon components (p and ln(p))
shannon_calc AS (
  SELECT
    sc.cell_id,
    sc.block_start_year,
    sc.species,
    sc.n,
    bt.total_records_in_block,
    -- Calculate proportion p = (n / total)
    SAFE_DIVIDE(sc.n, bt.total_records_in_block) AS p
  FROM species_counts sc
  JOIN block_totals bt USING (cell_id, block_start_year)
),

-- 4. Final Aggregation (Summing -p * ln(p))
final_stats AS (
  SELECT
    cell_id,
    block_start_year,
    ANY_VALUE(total_records_in_block) AS total_records,
    COUNT(DISTINCT species) AS species_richness,
    -- Shannon H Formula
    ROUND(-SUM(p * LN(p)), 3) AS shannon_H
  FROM shannon_calc
  GROUP BY cell_id, block_start_year
),

-- 5. Get Cell Centers for Mapping
centers AS (
  SELECT 
    S2_CELLIDFROMPOINT(ST_GEOGPOINT(decimalLongitude, decimalLatitude), level => 10) AS cell_id,
    AVG(decimalLatitude) AS lat, 
    AVG(decimalLongitude) AS lon
  FROM base_data
  GROUP BY 1
)

-- Final Output for Visualisation
SELECT
  CONCAT(CAST(f.block_start_year AS STRING), '-', CAST(f.block_start_year + 4 AS STRING)) AS time_period,
  f.block_start_year AS sort_year,
  c.lat,
  c.lon,
  f.cell_id,
  f.total_records,
  f.species_richness,
  f.shannon_H,
  -- "Efficiency" metric: How many species do we find per 100 records?
  ROUND(SAFE_DIVIDE(f.species_richness, f.total_records) * 100, 1) AS richness_per_100
FROM final_stats f
JOIN centers c USING (cell_id)
WHERE f.total_records >= 10  -- Filter low-sample bins to reduce noise
ORDER BY sort_year DESC, species_richness DESC;

