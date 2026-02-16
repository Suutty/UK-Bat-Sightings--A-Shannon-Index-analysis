# UK Chiroptera Sightings - A Shannon Index analysis
Spatio-temporal analysis of 973k+ UK bat records (1960–2026) using BigQuery, SQL, and Tableau to evaluate species richness and reporting trends

# 🦇 Spatio-temporal Dynamics of UK Bat variety recordings (1960–2026)

## 📌 Project Overview
This project analyses **973,232 verified bat occurrence records** from the NBN Atlas (via GBIF) databse to evaluate long-term trends in UK bat sightings and recordings. 

By applying **S2 geometry spatial binning** and **Shannon Diversity Index** calculations, the analysis works to recognise ecological reporting hotspots and trends in sampling efforts.

**[🔴 View Interactive Dashboard on Tableau Public](https://public.tableau.com/app/profile/john.sutton8198/viz/UKBatSightingsAShannonIndexAnalysis/Varietydensityindex)**

---

## 🔍 Key Objectives
1.  **Visualise** the spatial distribution of all 18 UK breeding bat species over the last 60 years.
2.  **Quantify** variety of sightings complexity using the **Shannon Index (H')** to correct for species richness bias.
3.  **Evaluate** the relationship between **sampling effort** (total records) and **ecological yield** (species found).
4.  **Identify** "cold spots" where high sampling effort yields low diversity (potential urban monocultures).

---

## 🛠️ Tech Stack & Methodology
*   **Data Source:** Global Biodiversity Information Facility (GBIF) / NBN Atlas (Occurrences of *Chiroptera* in UK, 1960–2026).
*   **Data Engineering (Google BigQuery & SQL):**
    *   **Cleaning:** Filtered 973k raw records to 916k verified occurrences (removed null coordinates, unresolved taxonomy).
    *   **Spatial Binning:** Aggregated data into **S2 Level 11 (~20km²) and Level 10 (~80km²)** grid cells to normalize spatial precision.
    *   **Temporal Binning:** Grouped records into **5-year intervals** to smooth irregular reporting spikes.
    *   **Metrics:** Calculated **Species Richness**, **Shannon Diversity Index**, and **Records per Species** using window functions.
*   **Visualization (Tableau):**
    *   **Dual-Map Strategy:** 
        1.  **Exploratory Map:** Interactive yearly observation history.
        2.  **Analytical Map:** Binned density map visualizing the **Sampling Effort vs. Reported Biodiversity** relationship.

---

## 📊 Key Insights
1.  **The "Smartphone Effect":** A massive exponential spike in records post-2005 correlates with the rise of digital recording apps, not a population boom or correlation with species variety.
2.  **Efficiency Paradox:** Areas with the highest sampling effort often show **moderate diversity**, suggesting sampling trends / social phenomona. 
3.  **Hidden Strongholds?:** The highest **Shannon Diversity** scores found in areas with moderate-high sampling effort (rural Wales/South West/ South West Scotland), indicating true ecological richness rather than just surveyor density/expertise.

---

## 📂 Repository Structure
*   `/sql`: Raw SQL queries used for data cleaning and aggregation in BigQuery.
*   `/docs`: Methodology notes and data dictionary.

---

## 📜 Citation
*   **Data Citation:** NBN Atlas occurrence download at Global Biodiversity Information Facility. [GBIF.org (12 February 2026) GBIF Occurrence Download https://doi.org/10.15468/dl.33a2xx]
