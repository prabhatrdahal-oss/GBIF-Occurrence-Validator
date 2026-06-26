# GBIF Occurrence Validator

**GBIF Ebbe Nielsen Challenge 2026 Submission**

GBIF Occurrence Validator is an open-source R Shiny platform for validating biodiversity occurrence records from GBIF. Distributed through Docker for reproducible deployment, the tool combines ecological, environmental, and expert-driven validation methods to identify suspicious records for terrestrial bird and mammal species.

---

# Screenshots

<p align="center">
  <img src="docs/screenshots/input_page.png" width="45%">
  <img src="docs/screenshots/log_page.png" width="45%">
</p>

<p align="center">
  <img src="docs/screenshots/maps.png" width="45%">
  <img src="docs/screenshots/final_table.png" width="45%">
</p>

<p align="center">
  <img src="docs/screenshots/summary_plots.png" width="45%">
  <img src="docs/screenshots/downloads.png" width="45%">
</p>

---

# Features

GBIF Occurrence Validator provides an automated and scalable framework for biodiversity occurrence validation.

* **Global coverage** — Supports terrestrial bird and mammal species across global geographic ranges
* **Automated workflow** — Minimal user input with fully automated species-specific validation
* **User-friendly interface** — Interactive maps, dashboards, and downloadable outputs
* **Real-time feedback** — Progress tracking and live processing logs
* **Scalable performance** — Handles large datasets (up to 100,000 records) through intelligent coarsening and batch processing

---

# Validation Framework

Occurrence records are evaluated across five complementary validation layers spanning habitat, land cover, environmental similarity, climate suitability, and expert range knowledge. Results from all layers are integrated into a unified suspicion score.

## Layer 1 — Copernicus Land Cover Habitat Validation

Occurrence points are evaluated using Copernicus Global Land Cover (100 m) and compared against species-specific IUCN habitat preferences using the habitat translation framework of Lumbierres et al. (2021).

## Layer 2 — ESRI 10 m Annual Land Cover Cross-Validation

Land-cover validation is refined using higher-resolution ESRI 10 m Annual Land Cover data (2017–2025) to improve detection of habitat inconsistencies. ESRI classes are mapped to corresponding Copernicus classes to ensure methodological consistency, and disagreements are resolved in favor of ESRI due to its finer spatial resolution and more recent temporal coverage.

## Layer 3 — AlphaEarth Landscape Embedding Outlier Detection

64-dimensional AlphaEarth satellite embeddings are analyzed using Isolation Forest to identify environmental anomalies relative to the species’ occurrence distribution.

## Layer 4 — Climate Suitability Scoring

An ensemble species distribution model built using biomod2 and WorldClim bioclimatic variables identifies climatically implausible records.

## Layer 5 — IUCN Expert Range Validation

Occurrence records are intersected with IUCN species range polygons to identify observations outside expert-defined geographic distributions.

---

# Suspicion Score Categories

Validation outputs from all layers are combined into a multi-tier suspicion score:

* **CLEAN** → No issues detected
* **MODERATE** → Minor concern
* **HIGH SUSPICION** → Multiple validation issues
* **CLEAR ERROR** → Strong evidence of invalid occurrence

---

# Tech Stack

GBIF Occurrence Validator combines biodiversity informatics, geospatial analysis, and machine learning through the following technologies:

* **R** — Core application logic and data processing
* **Shiny** — Interactive web interface
* **Docker** — Containerized deployment
* **Google Earth Engine** — Large-scale geospatial data extraction
* **Python (via reticulate)** — Earth Engine integration and ML workflows
* **GBIF API** — Species occurrence retrieval
* **IUCN Red List API** — Habitat and species metadata
* **biomod2** — Species distribution modelling
* **Isolation Forest** — Environmental anomaly detection

---

# Requirements

The following external credentials are required for full functionality and must be obtained separately by users:

* **Google Earth Engine service account credentials (JSON)**
* **IUCN Red List API token**

These credentials are required for:

* Copernicus land-cover extraction
* ESRI land-cover validation
* AlphaEarth embedding extraction
* IUCN habitat and range validation

---

# Installation

## Pull Docker Image

```bash
docker pull prabs330/gbif-validator:latest
```

Alternatively, clone this repository and build locally:

```bash
docker build -t gbif-validator .
```

---

# Credential Setup

Create a local folder named:

```text
credentials/
```

Place your Google Earth Engine service account JSON file inside:

```text
credentials/
└── service-account.json
```

You will also need a valid IUCN Red List API token, which is entered through the application interface at runtime.

---

# Running the App

## Windows (Recommended)

Use the provided launcher:

```bash
launch_app.bat
```

## Manual Docker Run

```bash
docker run -d -p 3838:3838 ^
-v "%CD%\credentials:/root/.config/earthengine" ^
--name gbif-validator ^
prabs330/gbif-validator:latest
```

Access the app at:

```text
http://localhost:3838
```

---

# Outputs

The application provides:

* Interactive occurrence maps
* Filterable validation tables
* Summary dashboards and visualizations
* Embedding-space anomaly plots
* Downloadable CSV outputs
* Record-level validation remarks and suspicion scores

---

# Repository Structure

```text
GBIF-Occurrence-Validator/
│
├── app_full.R
├── Dockerfile
├── docker-compose.yml
├── build.bat
├── launch_app.bat
├── restart_app.bat
├── stop_app.bat
├── README.md
├── LICENSE
├── .gitignore
│
├── docs/
│   ├── methodology.md
│   ├── screenshots/
│   └── sample_outputs/
```

---

# Citation

If you use this tool in research or applied biodiversity workflows, please cite:

**GBIF Occurrence Validator (2026)**
Prabhat Raj Dahal

---

# Acknowledgements

This tool builds upon open datasets and infrastructure from:

* GBIF
* IUCN Red List
* Copernicus Global Land Cover
* ESRI Land Cover
* WorldClim
* Google Earth Engine
* Google DeepMind AlphaEarth
