# =========================================================
# SET PYTHON ENVIRONMENT BEFORE LOADING ANY PACKAGES
# Must be done before reticulate or rgee are loaded
# =========================================================
VENV_PYTHON <- "/opt/venv/bin/python3"
if (file.exists(VENV_PYTHON)) {
  Sys.setenv(RETICULATE_PYTHON = VENV_PYTHON)
  reticulate::use_python(VENV_PYTHON, required = TRUE)
}

# =========================================================
# GBIF OCCURRENCE VALIDATOR - SHINY APP
# =========================================================

library(shiny)
library(shinydashboard)
library(leaflet)
library(DT)
library(ggplot2)
library(dplyr)
library(sf)
library(rgbif)
library(CoordinateCleaner)
library(rgee)
library(rredlist)
library(tibble)
library(tidyr)
library(isotree)
library(biomod2)
library(terra)
library(geodata)
library(plotly)

# =========================================================
# TRANSLATION TABLE (Lumbierres et al. 2021)
# =========================================================

translation_table <- tribble(
  ~lc_code, ~lc_name,                                           ~forest, ~savanna, ~shrubland, ~grassland, ~wetlands, ~rocky_areas, ~desert, ~art_arable_pasture, ~art_degraded_forest, ~art_urban_rural, ~art_aquatic,
  20,  "Shrubs",                                                0.309,   1.870,    2.683,      1.188,      NA,        1.383,        4.225,   NA,                  0.711,                NA,               NA,
  30,  "Herbaceous vegetation",                                 0.372,   1.180,    1.622,      2.369,      1.204,     1.506,        1.517,   1.296,               0.880,                1.262,            NA,
  40,  "Cultivated and managed vegetation / Agriculture",       0.588,   1.570,    1.395,      1.748,      1.875,     0.687,        NA,      1.743,               NA,                   1.330,            1.523,
  50,  "Urban / built-up",                                      NA,      NA,       1.362,      NA,         NA,        NA,           NA,      NA,                  NA,                   2.236,            NA,
  60,  "Bare / sparse vegetation",                              NA,      NA,       NA,         NA,         NA,        2.269,        2.278,   NA,                  NA,                   NA,               NA,
  70,  "Snow and ice",                                          NA,      NA,       NA,         NA,         NA,        NA,           NA,      NA,                  NA,                   NA,               NA,
  80,  "Permanent water bodies",                                NA,      NA,       NA,         NA,         2.381,     NA,           NA,      NA,                  NA,                   NA,               2.183,
  90,  "Herbaceous wetland",                                    NA,      NA,       NA,         1.183,      3.569,     NA,           NA,      NA,                  NA,                   NA,               NA,
  100, "Moss and lichen",                                       NA,      NA,       NA,         1.264,      NA,        1.512,        NA,      NA,                  NA,                   NA,               NA,
  111, "Closed forest, evergreen needle leaf",                  4.171,   NA,       NA,         NA,         NA,        NA,           NA,      NA,                  1.075,                NA,               NA,
  112, "Closed forest, evergreen broad leaf",                   4.682,   0.548,    NA,         NA,         1.523,     NA,           NA,      NA,                  1.699,                NA,               NA,
  113, "Closed forest, deciduous needle leaf",                  3.161,   NA,       NA,         NA,         NA,        NA,           NA,      NA,                  NA,                   NA,               NA,
  114, "Closed forest, deciduous broad leaf",                   3.245,   1.623,    NA,         NA,         1.958,     NA,           NA,      NA,                  1.133,                NA,               NA,
  115, "Closed forest, mixed",                                  3.786,   NA,       NA,         NA,         NA,        NA,           NA,      NA,                  1.406,                NA,               NA,
  116, "Closed forest, unknown",                                1.971,   NA,       NA,         NA,         1.312,     NA,           0.389,   NA,                  1.264,                NA,               1.345,
  121, "Open forest, evergreen needle leaf",                    2.171,   0.476,    NA,         NA,         NA,        1.790,        0.578,   NA,                  0.454,                NA,               NA,
  122, "Open forest, evergreen broad leaf",                     2.442,   0.801,    NA,         NA,         NA,        0.562,        0.160,   NA,                  1.566,                NA,               NA,
  124, "Open forest, deciduous broad leaf",                     1.391,   2.172,    NA,         NA,         1.658,     NA,           0.251,   NA,                  NA,                   1.398,            NA,
  125, "Open forest, mixed",                                    3.038,   NA,       NA,         NA,         NA,        NA,           NA,      NA,                  NA,                   NA,               NA,
  126, "Open forest, unknown",                                  1.138,   1.368,    1.284,      NA,         1.302,     NA,           0.673,   1.221,               1.138,                1.167,            1.341
)

# =========================================================
# HABITAT NAME MAP
# =========================================================

habitat_name_map <- tribble(
  ~iucn_name,                                                                            ~tt_column,
  "Forest",                                                                              "forest",
  "Forest - Boreal",                                                                     "forest",
  "Forest - Subarctic",                                                                  "forest",
  "Forest - Subantarctic",                                                               "forest",
  "Forest - Temperate",                                                                  "forest",
  "Forest - Subtropical/tropical dry",                                                   "forest",
  "Forest - Subtropical/tropical moist lowland",                                         "forest",
  "Forest - Subtropical/tropical mangrove vegetation above high tide level",             "forest",
  "Forest - Subtropical/tropical swamp",                                                 "forest",
  "Forest - Subtropical/tropical moist montane",                                         "forest",
  "Savanna",                                                                             "savanna",
  "Savanna - Dry",                                                                       "savanna",
  "Savanna - Moist",                                                                     "savanna",
  "Shrubland",                                                                           "shrubland",
  "Shrubland - Subarctic",                                                               "shrubland",
  "Shrubland - Subantarctic",                                                            "shrubland",
  "Shrubland - Boreal",                                                                  "shrubland",
  "Shrubland - Temperate",                                                               "shrubland",
  "Shrubland - Subtropical/tropical dry",                                                "shrubland",
  "Shrubland - Subtropical/tropical moist",                                              "shrubland",
  "Shrubland - Subtropical/tropical high altitude",                                      "shrubland",
  "Shrubland - Mediterranean-type shrubby vegetation",                                   "shrubland",
  "Grassland",                                                                           "grassland",
  "Grassland - Tundra",                                                                  "grassland",
  "Grassland - Subarctic",                                                               "grassland",
  "Grassland - Subantarctic",                                                            "grassland",
  "Grassland - Temperate",                                                               "grassland",
  "Grassland - Subtropical/tropical dry",                                                "grassland",
  "Grassland - Subtropical/tropical seasonally wet/flooded",                             "grassland",
  "Grassland - Subtropical/tropical high altitude",                                      "grassland",
  "Wetlands (inland)",                                                                   "wetlands",
  "Wetlands (inland) - Permanent rivers/streams/creeks (includes waterfalls)",           "wetlands",
  "Wetlands (inland) - Seasonal/intermittent/irregular rivers/streams/creeks",           "wetlands",
  "Wetlands (inland) - Shrub dominated wetlands",                                        "wetlands",
  "Wetlands (inland) - Bogs, marshes, swamps, fens, peatlands",                         "wetlands",
  "Wetlands (inland) - Permanent freshwater lakes (over 8 ha)",                         "wetlands",
  "Wetlands (inland) - Seasonal/intermittent freshwater lakes (over 8 ha)",              "wetlands",
  "Wetlands (inland) - Permanent freshwater marshes/pools (under 8 ha)",                "wetlands",
  "Wetlands (inland) - Seasonal/intermittent freshwater marshes/pools (under 8 ha)",    "wetlands",
  "Wetlands (inland) - Freshwater springs and oases",                                   "wetlands",
  "Wetlands (inland) - Tundra wetlands (inc. pools and temporary waters from snowmelt)","wetlands",
  "Wetlands (inland) - Alpine wetlands (inc. temporary waters from snowmelt)",          "wetlands",
  "Wetlands (inland) - Geothermal wetlands",                                            "wetlands",
  "Wetlands (inland) - Permanent inland deltas",                                        "wetlands",
  "Wetlands (inland) - Permanent saline, brackish or alkaline lakes",                   "wetlands",
  "Wetlands (inland) - Seasonal/intermittent saline, brackish or alkaline lakes and flats","wetlands",
  "Wetlands (inland) - Permanent saline, brackish or alkaline marshes/pools",           "wetlands",
  "Wetlands (inland) - Seasonal/intermittent saline, brackish or alkaline marshes/pools","wetlands",
  "Wetlands (inland) - Karst and other subterranean hydrological systems (inland)",     "wetlands",
  "Rocky Areas (e.g., inland cliffs, mountain peaks)",                                  "rocky_areas",
  "Caves & Subterranean Habitats (non-aquatic)",                                        "rocky_areas",
  "Caves and Subterranean Habitats (non-aquatic) - Caves",                              "rocky_areas",
  "Caves and Subterranean Habitats (non-aquatic) - Other subterranean habitats",        "rocky_areas",
  "Desert",                                                                              "desert",
  "Desert - Hot",                                                                        "desert",
  "Desert - Temperate",                                                                  "desert",
  "Desert - Cold",                                                                       "desert",
  "Artificial - Terrestrial",                                                            NA,
  "Arable Land",                                                                         "art_arable_pasture",
  "Pastureland",                                                                         "art_arable_pasture",
  "Plantations",                                                                         "art_degraded_forest",
  "Rural Gardens",                                                                       "art_urban_rural",
  "Urban Areas",                                                                         "art_urban_rural",
  "Subtropical/Tropical Heavily Degraded Former Forest",                                 "art_degraded_forest",
  "Artificial/Terrestrial - Arable Land",                                                "art_arable_pasture",
  "Artificial/Terrestrial - Pastureland",                                                "art_arable_pasture",
  "Artificial/Terrestrial - Plantations",                                                "art_degraded_forest",
  "Artificial/Terrestrial - Rural Gardens",                                              "art_urban_rural",
  "Artificial/Terrestrial - Urban Areas",                                                "art_urban_rural",
  "Artificial/Terrestrial - Subtropical/Tropical Heavily Degraded Former Forest",        "art_degraded_forest",
  "Artificial - Aquatic",                                                                NA,
  "Water Storage Areas [over 8 ha]",                                                     "art_aquatic",
  "Ponds [below 8 ha]",                                                                  "art_aquatic",
  "Aquaculture Ponds",                                                                   "art_aquatic",
  "Salt Exploitation Sites",                                                             "art_aquatic",
  "Excavations (open)",                                                                  "art_aquatic",
  "Wastewater Treatment Areas",                                                          "art_aquatic",
  "Irrigated Land [includes irrigation channels]",                                       "art_aquatic",
  "Seasonally Flooded Agricultural Land",                                                "art_aquatic",
  "Canals and Drainage Channels, Ditches",                                               "art_aquatic",
  "Karst and Other Subterranean Hydrological Systems [human-made]",                      "art_aquatic",
  "Marine Anthropogenic Structures",                                                     NA,
  "Mariculture Cages",                                                                   NA,
  "Mari/Brackish-culture Ponds",                                                         NA,
  "Marine Neritic",                                                                      NA,
  "Marine Neritic - Pelagic",                                                            NA,
  "Marine Oceanic",                                                                      NA,
  "Marine Intertidal",                                                                   NA,
  "Marine Coastal/Supratidal",                                                           NA,
  "Marine Coastal/Supratidal - Coastal Brackish/Saline Lagoons/Marine Lakes",            NA,
  "Introduced Vegetation",                                                               NA,
  "Other",                                                                               NA,
  "Unknown",                                                                             NA
)

# =========================================================
# COPERNICUS LC LOOKUP
# =========================================================

lc_lookup <- data.frame(
  lc_value = c(20,30,40,50,60,70,80,90,100,
               111,112,113,114,115,116,
               121,122,123,124,125,126,200),
  lc_name  = c("Shrubs","Herbaceous vegetation",
               "Cultivated and managed vegetation / Agriculture",
               "Urban / built-up","Bare / sparse vegetation",
               "Snow and ice","Permanent water bodies",
               "Herbaceous wetland","Moss and lichen",
               "Closed forest, evergreen needle leaf",
               "Closed forest, evergreen broad leaf",
               "Closed forest, deciduous needle leaf",
               "Closed forest, deciduous broad leaf",
               "Closed forest, mixed","Closed forest, unknown",
               "Open forest, evergreen needle leaf",
               "Open forest, evergreen broad leaf",
               "Open forest, deciduous needle leaf",
               "Open forest, deciduous broad leaf",
               "Open forest, mixed","Open forest, unknown","Ocean")
)

# =========================================================
# ESRI LC LOOKUP
# =========================================================

esri_lc_lookup <- data.frame(
  lc_value = c(1, 2, 4, 5, 7, 8, 9, 10, 11),
  lc_name  = c("Water","Trees","Flooded vegetation","Crops",
               "Built area","Bare ground","Snow / ice","Clouds","Rangeland")
)

# =========================================================
# COPERNICUS TO ESRI CROSSWALK TABLE
# =========================================================

copernicus_to_esri <- tribble(
  ~copernicus_name,                                    ~esri_name,
  "Shrubs",                                            "Rangeland",
  "Herbaceous vegetation",                             "Rangeland",
  "Cultivated and managed vegetation / Agriculture",   "Crops",
  "Urban / built-up",                                  "Built area",
  "Bare / sparse vegetation",                          "Bare ground",
  "Snow and ice",                                      "Snow / ice",
  "Permanent water bodies",                            "Water",
  "Herbaceous wetland",                                "Flooded vegetation",
  "Moss and lichen",                                   "Rangeland",
  "Closed forest, evergreen needle leaf",              "Trees",
  "Closed forest, evergreen broad leaf",               "Trees",
  "Closed forest, deciduous needle leaf",              "Trees",
  "Closed forest, deciduous broad leaf",               "Trees",
  "Closed forest, mixed",                              "Trees",
  "Closed forest, unknown",                            "Trees",
  "Open forest, evergreen needle leaf",                "Trees",
  "Open forest, evergreen broad leaf",                 "Trees",
  "Open forest, deciduous needle leaf",                "Trees",
  "Open forest, deciduous broad leaf",                 "Trees",
  "Open forest, mixed",                                "Trees",
  "Open forest, unknown",                              "Trees",
  "Ocean",                                             "Water"
)

# Create lookup vectors for faster mapping
cop_to_esri_vec <- setNames(
  copernicus_to_esri$esri_name,
  copernicus_to_esri$copernicus_name
)

esri_to_cop_vec <- setNames(
  copernicus_to_esri$copernicus_name,
  copernicus_to_esri$esri_name
)

# =========================================================
# ESRI HABITAT -> LC MAP
# =========================================================

esri_habitat_to_lc <- list(
  forest              = c(2),
  savanna             = c(11),
  shrubland           = c(11),
  grassland           = c(11),
  wetlands            = c(1, 4),
  rocky_areas         = c(8),
  desert              = c(8),
  art_arable_pasture  = c(5, 11),
  art_degraded_forest = c(2),
  art_urban_rural     = c(7),
  art_aquatic         = c(1)
)


# =========================================================
# HABITAT NAME MAPPING FOR DISPLAY
# =========================================================

habitat_display_names <- c(
  "forest" = "Forest",
  "savanna" = "Savanna",
  "shrubland" = "Shrubland",
  "grassland" = "Grassland",
  "wetlands" = "Wetlands",
  "rocky_areas" = "Rocky Areas",
  "desert" = "Desert",
  "art_arable_pasture" = "Arable Land / Pasture",
  "art_degraded_forest" = "Degraded Forest",
  "art_urban_rural" = "Urban / Rural Areas",
  "art_aquatic" = "Aquatic / Water Bodies",
  "art_degraded_forest" = "Plantations / Degraded Forest"
)


# =========================================================
# HELPER FUNCTIONS
# =========================================================

get_valid_lc <- function(habitats_df, habitat_name_map,
                         translation_table, threshold = 1.743) {
  mapped <- habitats_df %>%
    mutate(description_lower = tolower(description)) %>%
    left_join(
      habitat_name_map %>% mutate(iucn_name_lower = tolower(iucn_name)),
      by = c("description_lower" = "iucn_name_lower")
    ) %>%
    filter(!is.na(tt_column))
  if (nrow(mapped) == 0) return(NULL)
  tt_columns <- unique(mapped$tt_column)
  valid_lc <- translation_table %>%
    select(lc_code, lc_name, all_of(tt_columns)) %>%
    pivot_longer(cols = all_of(tt_columns),
                 names_to  = "tt_column",
                 values_to = "odds_ratio") %>%
    filter(!is.na(odds_ratio), odds_ratio >= threshold) %>%
    pull(lc_code) %>%
    unique()
  return(valid_lc)
}

get_valid_lc_esri <- function(habitats_df, habitat_name_map,
                              esri_habitat_to_lc) {
  mapped <- habitats_df %>%
    mutate(description_lower = tolower(description)) %>%
    left_join(
      habitat_name_map %>% mutate(iucn_name_lower = tolower(iucn_name)),
      by = c("description_lower" = "iucn_name_lower")
    ) %>%
    filter(!is.na(tt_column))
  if (nrow(mapped) == 0) return(NULL)
  tt_cols     <- unique(mapped$tt_column)
  valid_codes <- unlist(esri_habitat_to_lc[tt_cols], use.names = FALSE)
  unique(valid_codes[!is.na(valid_codes)])
}

# =========================================================
# FUNCTION TO GET ODDS RATIOS FOR SPECIES
# =========================================================

get_odds_ratios <- function(habitats, translation_table, habitat_name_map) {
  mapped_habitats <- habitats %>%
    mutate(description_lower = tolower(description)) %>%
    left_join(
      habitat_name_map %>% mutate(iucn_name_lower = tolower(iucn_name)),
      by = c("description_lower" = "iucn_name_lower")
    ) %>%
    filter(!is.na(tt_column))
  
  if (nrow(mapped_habitats) == 0) return(NULL)
  
  tt_columns <- unique(mapped_habitats$tt_column)
  
  odds_ratios <- translation_table %>%
    select(lc_code, lc_name, all_of(tt_columns)) %>%
    pivot_longer(cols = all_of(tt_columns),
                 names_to = "tt_column",
                 values_to = "odds_ratio") %>%
    filter(!is.na(odds_ratio)) %>%
    group_by(lc_code, lc_name, tt_column) %>%
    summarise(max_odds = max(odds_ratio, na.rm = TRUE), .groups = "drop")
  
  return(odds_ratios)
}

# =========================================================
# FUNCTION TO GET RED LIST HABITATS FOR A SPECIES
# =========================================================

get_redlist_habitats <- function(habitats, habitat_name_map) {
  mapped <- habitats %>%
    mutate(description_lower = tolower(description)) %>%
    left_join(
      habitat_name_map %>% mutate(iucn_name_lower = tolower(iucn_name)),
      by = c("description_lower" = "iucn_name_lower")
    ) %>%
    filter(!is.na(tt_column)) %>%
    pull(tt_column) %>%
    unique()
  
  return(mapped)
}



# =========================================================
# FUNCTION TO COARSEN POINTS BY GRID CELL
# =========================================================

coarsen_points <- function(df, res = 0.0417) {
  
  # Remove add_log calls - they'll be handled in the calling code
  
  # Round coordinates to grid cell resolution
  df_coarse <- df %>%
    mutate(
      lon_grid = round(decimalLongitude / res) * res,
      lat_grid = round(decimalLatitude / res) * res
    ) %>%
    group_by(lon_grid, lat_grid) %>%
    # Keep the first point in each grid cell
    slice(1) %>%
    ungroup() %>%
    dplyr::select(-lon_grid, -lat_grid)
  
  return(df_coarse)
}


# =========================================================
# FUNCTION TO GET ALL RED LIST HABITATS FOR ESRI TYPE (WITH THRESHOLD)
# =========================================================

get_habitats_for_esri <- function(esri_type, redlist_habitats, odds_ratios, threshold = 1.743) {
  
  # Define mapping from ESRI type to possible Copernicus classes
  esri_to_cop_mapping <- list(
    "Trees" = c("Closed forest, evergreen needle leaf", "Closed forest, evergreen broad leaf",
                "Closed forest, deciduous needle leaf", "Closed forest, deciduous broad leaf",
                "Closed forest, mixed", "Closed forest, unknown",
                "Open forest, evergreen needle leaf", "Open forest, evergreen broad leaf",
                "Open forest, deciduous needle leaf", "Open forest, deciduous broad leaf",
                "Open forest, mixed", "Open forest, unknown"),
    
    "Rangeland" = c("Shrubs", "Herbaceous vegetation", "Moss and lichen"),
    
    "Crops" = c("Cultivated and managed vegetation / Agriculture"),
    
    "Built area" = c("Urban / built-up"),
    
    "Bare ground" = c("Bare / sparse vegetation"),
    
    "Snow / ice" = c("Snow and ice"),
    
    "Water" = c("Permanent water bodies"),
    
    "Flooded vegetation" = c("Herbaceous wetland"),
    
    "Clouds" = c()
  )
  
  # Get possible Copernicus classes for this ESRI type
  possible_cops <- esri_to_cop_mapping[[esri_type]]
  
  if (is.null(possible_cops) || length(possible_cops) == 0) {
    return(data.frame(habitat = character(), odds_ratio = numeric(), 
                      copernicus_class = character(), stringsAsFactors = FALSE))
  }
  
  # Map Copernicus classes to their associated habitats
  cop_to_habitat <- list(
    "Shrubs" = c("shrubland", "desert", "savanna"),
    "Herbaceous vegetation" = c("grassland", "shrubland", "savanna", "wetlands", "rocky_areas", "desert"),
    "Moss and lichen" = c("grassland", "rocky_areas"),
    "Cultivated and managed vegetation / Agriculture" = c("art_arable_pasture", "wetlands", "savanna", "grassland"),
    "Urban / built-up" = c("art_urban_rural", "shrubland"),
    "Bare / sparse vegetation" = c("rocky_areas", "desert"),
    "Snow and ice" = c(),
    "Permanent water bodies" = c("art_aquatic", "wetlands"),
    "Herbaceous wetland" = c("wetlands", "grassland"),
    "Closed forest, evergreen needle leaf" = c("forest"),
    "Closed forest, evergreen broad leaf" = c("forest"),
    "Closed forest, deciduous needle leaf" = c("forest"),
    "Closed forest, deciduous broad leaf" = c("forest"),
    "Closed forest, mixed" = c("forest"),
    "Closed forest, unknown" = c("forest"),
    "Open forest, evergreen needle leaf" = c("forest", "rocky_areas"),
    "Open forest, evergreen broad leaf" = c("forest"),
    "Open forest, deciduous needle leaf" = c("forest"),
    "Open forest, deciduous broad leaf" = c("forest", "savanna"),
    "Open forest, mixed" = c("forest"),
    "Open forest, unknown" = c("forest", "savanna", "shrubland", "rocky_areas"),
    "Ocean" = c()
  )
  
  # Collect all habitats with their odds ratios - only those >= threshold
  result <- data.frame(habitat = character(), odds_ratio = numeric(), 
                       copernicus_class = character(), stringsAsFactors = FALSE)
  
  for (cop in possible_cops) {
    cop_habitats <- cop_to_habitat[[cop]]
    if (!is.null(cop_habitats)) {
      for (hab in cop_habitats) {
        if (hab %in% redlist_habitats) {
          odds_row <- odds_ratios %>%
            filter(lc_name == cop, tt_column == hab)
          
          if (nrow(odds_row) > 0) {
            odds_val <- odds_row$max_odds[1]
            if (odds_val >= threshold) {
              result <- rbind(result, data.frame(
                habitat = hab,
                odds_ratio = odds_val,
                copernicus_class = cop,
                stringsAsFactors = FALSE
              ))
            }
          }
        }
      }
    }
  }
  
  # If no Red List habitats found, return the ESRI type with odds ratio 0
  if (nrow(result) == 0) {
    return(data.frame(
      habitat = tolower(esri_type),
      odds_ratio = 0,
      copernicus_class = esri_type,
      stringsAsFactors = FALSE
    ))
  }
  
  # Remove duplicates and sort by odds ratio
  result <- result %>%
    distinct(habitat, copernicus_class, .keep_all = TRUE) %>%
    arrange(desc(odds_ratio))
  
  return(result)
}
# =========================================================
# COLOUR PALETTE
# =========================================================

suspicion_colours <- c(
  # CLEAN — same green
  "CLEAN: Inside extant range + passes all checks"              = "#2E8B57",
  "CLEAN: Inside extant range — one flag likely sampling bias"  = "#2E8B57",
  "CLEAN: Passes all checks"                                    = "#2E8B57",
  "CLEAN: One flag likely sampling bias"                        = "#2E8B57",
  
  # INVESTIGATE — same orange
  "INVESTIGATE: Inside extant range but two checks failed"      = "#F28E2B",
  "INVESTIGATE: Inside extant range but multiple checks failed" = "#F28E2B",
  "INVESTIGATE: Historically extinct range"                     = "#F28E2B",
  "INVESTIGATE: Presence uncertain range"                       = "#F28E2B",
  "INVESTIGATE: Outside IUCN range but passes all checks"       = "#F28E2B",
  "INVESTIGATE: Two checks failed"                              = "#F28E2B",
  "INVESTIGATE: Outside range + one check failed"               = "#F28E2B",
  
  # HIGH SUSPICION — same red
  "HIGH SUSPICION: Outside range + two checks failed"           = "#D62728",
  "HIGH SUSPICION: Multiple checks failed"                      = "#D62728",
  "HIGH SUSPICION: Extinct range + environmental flags"         = "#D62728",
  "HIGH SUSPICION: Uncertain range + environmental flags"       = "#D62728",
  
  # CLEAR ERROR — same dark red / navy
  "CLEAR ERROR: Outside range + multiple checks failed"         = "#800000",
  "CLEAR ERROR: Ocean — impossible location"                    = "#08306B",
  
  # REVIEW
  "REVIEW: Manual check required"                               = "#BDBDBD"
)

flag_icon <- function(level) {
  dplyr::case_when(
    grepl("CLEAN",          level) ~ "\u2705",
    grepl("INVESTIGATE",    level) ~ "\u26a0\ufe0f",
    grepl("HIGH SUSPICION", level) ~ "\U0001f534",
    grepl("CLEAR ERROR",    level) ~ "\u274c",
    TRUE                           ~ "\u2753"
  )
}

# =========================================================
# UI
# =========================================================

# =========================================================
# UI
# =========================================================

ui <- dashboardPage(
  skin = "green",
  
  dashboardHeader(title = "GBIF Occurrence Validator", titleWidth = 180),
  
  dashboardSidebar(
    width = 180,
    sidebarMenu(
      menuItem("Run Validation", tabName = "run",       icon = icon("play")),
      menuItem("Map",            tabName = "map",       icon = icon("map")),
      menuItem("Results Table",  tabName = "table",     icon = icon("table")),
      menuItem("Dashboard",      tabName = "dashboard", icon = icon("chart-bar")),
      menuItem("PCA Embeddings", tabName = "pca",       icon = icon("project-diagram")),
      menuItem("About",          tabName = "about",     icon = icon("info-circle"))
    )
  ),
  
  dashboardBody(
    tags$head(
      tags$style(HTML("
        .content-wrapper { background-color: #f4f6f7; }
        .box { border-radius: 8px; }
        .log-box { 
          background: #1e1e1e; 
          color: #00ff00; 
          font-family: monospace;
          font-size: 12px; 
          padding: 10px; 
          border-radius: 6px;
          height: 300px; 
          overflow-y: scroll; 
        }
        /* Only log box should be green */
        .log-box, .log-box pre, .log-box code, .log-box .shiny-text-output, #log {
          color: #000000 !important;
        }
        /* Make all other text dark */
        body, .content-wrapper, .box, .shiny-text-output, 
        .form-control, .control-label, .dataTables_wrapper,
        .dataTables_info, .dataTables_length, .dataTables_filter,
        .selectize-input, .selectize-dropdown, .btn, .btn-default,
        .checkbox, .radio, .value-box, .info-box, .info-box-text {
          color: #333333 !important;
        }
        /* Sidebar width - 180px */
        .main-sidebar {
          width: 180px !important;
        }
        .main-header .logo {
          width: 180px !important;
        }
        .main-header .navbar {
          margin-left: 180px !important;
        }
        .content-wrapper, .right-side {
          margin-left: 180px !important;
        }
        .content {
          padding: 15px !important;
        }
        /* Make boxes and table full width */
        .box {
          width: 100% !important;
        }
        .dataTables_wrapper {
          width: 100% !important;
          overflow-x: auto !important;
          padding: 5px !important;
        }
        .dataTable {
          width: 100% !important;
          table-layout: auto !important;
        }
        .dataTable td, .dataTable th {
          vertical-align: middle !important;
        }
        /* Fix sort icon overlap */
        .dataTable thead th {
          padding: 8px 20px 8px 4px !important;
        }
        .dataTable tbody td {
          padding: 6px 4px !important;
        }
      ")),
      
      # =========================================================
      # JAVASCRIPT FOR REAL-TIME UPDATES
      # =========================================================
      tags$script(HTML("
        Shiny.addCustomMessageHandler('log_update', function(message) {
          var logDiv = document.getElementById('log');
          if (logDiv) {
            var time = new Date().toLocaleTimeString();
            var newLine = document.createElement('div');
            newLine.textContent = '[' + time + '] ' + message.message;
            logDiv.appendChild(newLine);
            logDiv.scrollTop = logDiv.scrollHeight;
          }
        });
        
        Shiny.addCustomMessageHandler('progress_update', function(message) {
          var progressBar = document.getElementById('download_progress');
          if (progressBar) {
            var value = Math.min(message.value, 100);
            progressBar.style.width = value + '%';
            progressBar.setAttribute('aria-valuenow', value);
            progressBar.textContent = value + '%';
            if (value < 30) {
              progressBar.style.backgroundColor = '#F39C12';
            } else if (value < 70) {
              progressBar.style.backgroundColor = '#3498DB';
            } else {
              progressBar.style.backgroundColor = '#2ECC71';
            }
          }
        });
      "))
    ),  # Close tags$head
    
    # =========================================================
    # TAB ITEMS
    # =========================================================
    tabItems(
      
      # ===================================================
      # TAB 1: RUN
      # ===================================================
      tabItem(tabName = "run",
              fluidRow(
                box(width = 4, title = "Species & Settings",
                    status = "success", solidHeader = TRUE,
                    
                    textInput("species_name", "Species name (binomial)",
                              value = "Panthera tigris",
                              placeholder = "e.g. Panthera tigris"),
                    
                    textInput("iucn_token", "IUCN Red List API token",
                              value = "", placeholder = "Paste your token here"),
                    
                    numericInput("year_from", "Records from year",
                                 value = 2015, min = 2000, max = 2024),
                    
                    actionButton("search_btn", "Check Total Records",
                                 icon = icon("search"),
                                 class = "btn-info btn-block"),
                    br(),
                    
                    fluidRow(
                      valueBoxOutput("vbox_gbif_total", width = 12)
                    ),
                    
                    numericInput("gbif_limit", "Max GBIF records to validate",
                                 value = 5000, min = 100, max = 100000, step = 1000),
                    
                    # Conditional panel for large downloads
                    conditionalPanel(
                      condition = "input.gbif_limit > 30000",
                      wellPanel(
                        style = "background-color: #fff3cd; border: 1px solid #ffc107;",
                        tags$strong("⚠️ For large downloads (>30,000 records), consider using GBIF Download API"),
                        p("You'll need a free GBIF account (register at gbif.org)"),
                        textInput("gbif_user", "GBIF Username", 
                                  value = "", placeholder = "Your GBIF username"),
                        passwordInput("gbif_pwd", "GBIF Password", 
                                      value = "", placeholder = "Your GBIF password"),
                        textInput("gbif_email", "GBIF Email", 
                                  value = "", placeholder = "Your email address"),
                        helpText("Your credentials are only used for downloading and are not stored.")
                      )
                    ),
                    
                    fileInput("range_file",
                              "IUCN range shapefile (.shp + .shx + .dbf + .prj)",
                              multiple = TRUE,
                              accept   = c(".shp",".dbf",".shx",".prj")),
                    
                    hr(),
                    h4("Modules to run"),
                    checkboxInput("run_copernicus",  "Copernicus LC validation",     value = TRUE),
                    checkboxInput("run_esri",        "ESRI LC validation",           value = TRUE),
                    checkboxInput("run_embeddings",  "Satellite embeddings",         value = TRUE),
                    checkboxInput("run_sdm",         "Climate SDM (biomod2)",        value = TRUE),
                    checkboxInput("run_range",       "IUCN range intersection",      value = TRUE),
                    hr(),
                    
                    actionButton("run_btn", "Run Validation",
                                 icon = icon("play"),
                                 class = "btn-success btn-lg btn-block"),
                    br(),
                    downloadButton("download_full",    "Download full results (.csv)"),
                    br(), br(),
                    downloadButton("download_flagged", "Download flagged points (.csv)"),
                    br(), br(),
                    downloadButton("download_clean", "Download clean points (.csv)"),
                    br(), br(),
                    downloadButton("download_summary", "Download summary statistics (.csv)")
                ),
                
                box(width = 8, title = "Progress Log",
                    status = "primary", solidHeader = TRUE,
                    div(class = "log-box", id = "log", verbatimTextOutput("log")),
                    br(),
                    
                    # Progress Bar
                    fluidRow(
                      column(12,
                             tags$div(
                               style = "padding: 10px; background-color: #f8f9fa; border-radius: 4px;",
                               tags$p("Download Progress:", style = "font-weight: bold; margin-bottom: 5px;"),
                               div(class = "progress",
                                   div(id = "download_progress",
                                       class = "progress-bar progress-bar-striped active",
                                       role = "progressbar",
                                       style = "width: 0%; background-color: #2ECC71;",
                                       `aria-valuenow` = 0,
                                       `aria-valuemin` = 0,
                                       `aria-valuemax` = 100,
                                       "0%")
                               )
                             )
                      )
                    ),
                    br(),
                    
                    fluidRow(
                      valueBoxOutput("vbox_total",   width = 3),
                      valueBoxOutput("vbox_clean",   width = 3),
                      valueBoxOutput("vbox_suspect", width = 3),
                      valueBoxOutput("vbox_error",   width = 3)
                    )
                )
              )
      ),  # Close TAB 1
      
      # ===================================================
      # TAB 2: MAP
      # ===================================================
      tabItem(tabName = "map",
              fluidRow(
                box(width = 12, title = "Occurrence Map",
                    status = "success", solidHeader = TRUE,
                    fluidRow(
                      column(3, selectInput("map_filter",  "Filter by suspicion level",
                                            choices = c("All"="all"), multiple = TRUE)),
                      column(3, selectInput("map_country", "Filter by country",
                                            choices = c("All"="all"), multiple = TRUE)),
                      column(3, selectInput("map_lc",      "Filter by LC class",
                                            choices = c("All"="all"), multiple = TRUE)),
                      column(3, checkboxInput("map_flagged_only",
                                              "Show flagged only", value = FALSE))
                    ),
                    fluidRow(
                      column(6, checkboxInput("map_show_range", "Show IUCN Range", value = TRUE)),
                      column(6, checkboxInput("map_show_sdm", "Show SDM Prediction", value = FALSE))
                    ),
                    leafletOutput("map", height = 600)
                )
              )
      ),
      
      # ===================================================
      # TAB 3: TABLE
      # ===================================================
      tabItem(tabName = "table",
              fluidRow(
                box(width = 12, title = "Validation Results Summary",
                    status = "primary", solidHeader = TRUE,
                    fluidRow(
                      column(4, selectInput("tbl_filter", "Filter by suspicion level",
                                            choices = c("All"="all"), multiple = TRUE)),
                      column(4, selectInput("tbl_flags",  "Minimum number of flags",
                                            choices  = c("Any (0+)"=0,"1+"=1,"2+"=2,
                                                         "3+"=3,"4+"=4,"5"=5),
                                            selected = 0)),
                      column(4, 
                             br(),
                             p("Download full detailed data using buttons below the table")
                      )
                    ),
                    br(),
                    DTOutput("results_table")
                )
              )
      ),
      
      # ===================================================
      # TAB 4: DASHBOARD
      # ===================================================
      tabItem(tabName = "dashboard",
              fluidRow(
                box(width = 6, title = "Suspicion Level Breakdown",
                    status = "success", solidHeader = TRUE,
                    plotlyOutput("plot_suspicion", height = 350)),
                box(width = 6, title = "Flags per Validation Method",
                    status = "primary", solidHeader = TRUE,
                    plotlyOutput("plot_flags", height = 350))
              ),
              fluidRow(
                box(width = 6, title = "Flagged Records by Country",
                    status = "warning", solidHeader = TRUE,
                    plotlyOutput("plot_country", height = 350)),
                box(width = 6, title = "Land Cover Class Distribution",
                    status = "info", solidHeader = TRUE,
                    plotlyOutput("plot_lc", height = 350))
              ),
              fluidRow(
                box(width = 6, title = "Clean Points — Land Cover Distribution",
                    status = "success", solidHeader = TRUE,
                    plotlyOutput("plot_clean_lc", height = 380)),
                box(width = 6, title = "Flagged Points (≥2 flags) — Land Cover Distribution",
                    status = "danger", solidHeader = TRUE,
                    plotlyOutput("plot_flagged_lc", height = 380))
              ),
              fluidRow(
                box(width = 6, title = "Clean Points — IUCN Habitat Distribution",
                    status = "success", solidHeader = TRUE,
                    plotlyOutput("plot_clean_hab", height = 380)),
                box(width = 6, title = "Flagged Points (≥2 flags) — IUCN Habitat Distribution",
                    status = "danger", solidHeader = TRUE,
                    plotlyOutput("plot_flagged_hab", height = 380))
              ),
              fluidRow(
                box(width = 12, title = "Summary Statistics",
                    status = "primary", solidHeader = TRUE,
                    tableOutput("summary_table"))
              )
      ),
      
      # ===================================================
      # TAB 5: PCA
      # ===================================================
      tabItem(tabName = "pca",
              fluidRow(
                box(width = 6, title = "PCA \u2014 Coloured by LC Class",
                    status = "success", solidHeader = TRUE,
                    plotlyOutput("pca_lc", height = 450)),
                box(width = 6, title = "PCA \u2014 Embedding Outliers",
                    status = "danger", solidHeader = TRUE,
                    plotlyOutput("pca_outliers", height = 450))
              ),
              fluidRow(
                box(width = 12, title = "Outlier Score Distribution",
                    status = "primary", solidHeader = TRUE,
                    plotlyOutput("hist_scores", height = 300))
              )
      ),
      
      # ===================================================
      # TAB 6: ABOUT
      # ===================================================
      tabItem(tabName = "about",
              fluidRow(
                box(width = 12, status = "success", solidHeader = TRUE,
                    title = "About This Tool",
                    h3("GBIF Occurrence Validator"),
                    h4("Ebbe Nielsen Challenge 2026"),
                    p("Validates GBIF occurrence records using five independent layers:"),
                    tags$ol(
                      tags$li(strong("Copernicus LC:"),
                              "100m land cover \u2014 Lumbierres et al. (2021) translation table."),
                      tags$li(strong("ESRI LC:"),
                              "10m annual land cover 2017-2025 \u2014 deterministic IUCN mapping."),
                      tags$li(strong("Satellite embeddings:"),
                              "AlphaEarth 64-dim embeddings + Isolation Forest."),
                      tags$li(strong("Climate SDM:"),
                              "biomod2 ensemble SDM with WorldClim variables."),
                      tags$li(strong("IUCN range intersection:"),
                              "Expert range polygon overlay.")
                    ),
                    hr(),
                    h4("References"),
                    tags$ul(
                      tags$li("Lumbierres et al. (2021). Conservation Biology."),
                      tags$li("Dahal et al. (2022). Geoscientific Model Development."),
                      tags$li("GBIF.org"),
                      tags$li("Google DeepMind AlphaEarth Satellite Embeddings V1"),
                      tags$li("ESRI Annual Land Cover 10m (2017-2025)")
                    )
                )
              )
      )
      
    ) # end tabItems
  )   # end dashboardBody
)     # end dashboardPage
# =========================================================
# SERVER
# =========================================================

server <- function(input, output, session) {
  
  log_text  <- reactiveVal("")
  
  # Persistent log — written to /srv/logs (mounted volume) so logs survive restarts
  log_dir  <- "/srv/logs"
  if (!dir.exists(log_dir)) dir.create(log_dir, recursive = TRUE)
  log_file <- file.path(log_dir,
                        paste0("occurscan_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log"))
  results   <- reactiveVal(NULL)
  pca_data  <- reactiveVal(NULL)
  emb_flags <- reactiveVal(NULL)
  
  # Reactive values for storing spatial data
  map_data <- reactiveValues(
    range_sf = NULL,
    sdm_rast = NULL
  )
  
  # Reactive values for GBIF preview
  gbif_preview <- reactiveValues(
    total = NULL,
    searched = FALSE   # <-- REMOVED gbif_data = NULL
  )
  
  # =========================================================
  # ADD THIS - Benchmark reactive values
  # =========================================================
  benchmark <- reactiveValues(
    start = NULL,
    steps = list()
  )
  
  add_log <- function(msg) {
    stamped <- paste0("[", format(Sys.time(), "%H:%M:%S"), "] ", msg)
    log_text(paste0(log_text(), "\n", stamped))
    cat(stamped, "\n", file = log_file, append = TRUE)
  }
  
  output$log <- renderText({ log_text() })
  
  # =========================================================
  # Search button observer - only shows total records
  # =========================================================
  observeEvent(input$search_btn, {
    req(input$species_name)
    
    add_log(paste("Searching GBIF for", input$species_name, "from", input$year_from, "onwards..."))
    
    tryCatch({
      # Search with year filter
      total <- occ_search(
        scientificName = input$species_name,
        hasCoordinate  = TRUE,
        year           = paste0(input$year_from, "," , format(Sys.Date(), "%Y")),
        limit          = 1
      )$meta$count
      
      gbif_preview$total <- total
      gbif_preview$searched <- TRUE
      
      add_log(paste("Total GBIF records available from", input$year_from, "onwards:", format(total, big.mark = ",")))
      
      showNotification(
        paste("Found", format(total, big.mark = ","), "records for", input$species_name, 
              "from", input$year_from, "onwards"),
        type = "message"
      )
      
    }, error = function(e) {
      add_log(paste("ERROR - GBIF search:", e$message))
      showNotification(
        paste("GBIF search error:", e$message),
        type = "error"
      )
      gbif_preview$total <- NULL
      gbif_preview$searched <- FALSE
    })
  })
  
  # -------------------------------------------------------
  # RUN BUTTON
  # -------------------------------------------------------
  
  observeEvent(input$run_btn, {
    
    req(input$species_name, input$iucn_token)
    results(NULL)
    log_text("")
    add_log(paste("Starting validation for:", input$species_name))
    
    # =========================================================
    # ADD THIS - Start benchmark
    # =========================================================
    benchmark$start <- Sys.time()
    benchmark$steps <- list()
    
    withProgress(message = paste("Validating", input$species_name), value = 0, {
      
      species_name       <- trimws(input$species_name)
      species_name_clean <- gsub(" ", "_", species_name)
      api_token          <- trimws(input$iucn_token)
      genus_name         <- strsplit(species_name, " ")[[1]][1]
      sp_epithet         <- strsplit(species_name, " ")[[1]][2]
      
      # -------------------------------------------------
      # STEP 1: GBIF DOWNLOAD (Hybrid Approach)
      # -------------------------------------------------
      
      incProgress(0.05, detail = "Downloading GBIF records...")
      add_log(paste("Querying GBIF for", species_name, "from", input$year_from, "onwards..."))
      session$sendCustomMessage("log_update", list(
        message = paste("Starting download for", species_name, "...")
      ))
      
      gbif_raw <- NULL
      
      tryCatch({
        # Get total count first
        add_log("Getting total record count...")
        session$sendCustomMessage("log_update", list(message = "Getting total record count..."))
        
        total <- occ_search(
          scientificName = species_name,
          hasCoordinate  = TRUE,
          year           = paste0(input$year_from, "," , format(Sys.Date(), "%Y")),
          limit          = 1
        )$meta$count
        
        add_log(paste("Total GBIF records available:", format(total, big.mark = ",")))
        session$sendCustomMessage("log_update", list(
          message = paste("Total records:", format(total, big.mark = ","))
        ))
        
        total_fetch <- min(input$gbif_limit, total)
        
        # =========================================================
        # DECIDE WHICH DOWNLOAD METHOD TO USE
        # =========================================================
        use_download <- total_fetch > 30000 && 
          input$gbif_user != "" && 
          input$gbif_pwd != "" && 
          input$gbif_email != ""
        
        if (use_download) {
          # =========================================================
          # METHOD 1: occ_download() - FOR LARGE DATASETS (>30,000 records)
          # =========================================================
          add_log("========================================")
          add_log("Using GBIF Download API for large dataset...")
          session$sendCustomMessage("log_update", list(
            message = "🚀 Using GBIF Download API (faster for large datasets)"
          ))
          
          # Set credentials
          options(gbif_user = input$gbif_user)
          options(gbif_pwd = input$gbif_pwd)
          options(gbif_email = input$gbif_email)
          
          tryCatch({
            # Create download request
            add_log("Creating download request...")
            session$sendCustomMessage("log_update", list(message = "Creating download request..."))
            
            download_key <- occ_download(
              pred("scientificName", species_name),
              pred("hasCoordinate", TRUE),
              pred("year", paste0(input$year_from, "," , format(Sys.Date(), "%Y"))),
              format = "SIMPLE_CSV"
            )
            
            add_log(paste("Download key:", download_key))
            session$sendCustomMessage("log_update", list(
              message = paste("Download key:", download_key)
            ))
            
            # Monitor download status
            add_log("Waiting for download to complete (this may take several minutes)...")
            session$sendCustomMessage("log_update", list(
              message = "⏳ Processing download request..."
            ))
            
            # Update progress bar
            session$sendCustomMessage("progress_update", list(value = 30))
            
            # This will show progress as it runs
            occ_download_wait(download_key, status_ping = 10)
            
            # Update progress bar
            session$sendCustomMessage("progress_update", list(value = 60))
            
            # Import the data
            add_log("Download complete. Importing data...")
            session$sendCustomMessage("log_update", list(
              message = "📥 Download complete. Importing data..."
            ))
            
            gbif_raw <- occ_download_get(download_key) %>% 
              occ_download_import()
            
            # Update progress bar
            session$sendCustomMessage("progress_update", list(value = 80))
            
            add_log(paste("Downloaded", format(nrow(gbif_raw), big.mark = ","), "records"))
            session$sendCustomMessage("log_update", list(
              message = paste("✅ Downloaded", format(nrow(gbif_raw), big.mark = ","), "records")
            ))
            session$sendCustomMessage("progress_update", list(value = 100))
            
            # Delete the downloaded file to save space
            unlink(paste0(download_key, ".zip"))
            
          }, error = function(e) {
            add_log(paste("ERROR - occ_download:", e$message))
            session$sendCustomMessage("log_update", list(
              message = paste("❌ Download error:", e$message)
            ))
            showNotification(paste("Download error:", e$message), type = "error")
            # Fallback to occ_search if download fails
            add_log("Falling back to occ_search...")
            session$sendCustomMessage("log_update", list(
              message = "⚠️ Falling back to standard download..."
            ))
            use_download <- FALSE
          })
        }
        
        # =========================================================
        # METHOD 2: occ_search() - FOR SMALLER DATASETS OR FALLBACK
        # =========================================================
        if (!use_download || is.null(gbif_raw) || nrow(gbif_raw) == 0) {
          
          if (total_fetch > 30000) {
            add_log("WARNING: occ_download recommended for >30,000 records")
            add_log("Please provide GBIF credentials for faster download")
            session$sendCustomMessage("log_update", list(
              message = "⚠️ For >30,000 records, please provide GBIF credentials"
            ))
          }
          
          add_log("Using occ_search for download...")
          session$sendCustomMessage("log_update", list(
            message = "📥 Using standard download method..."
          ))
          
          # Use 5,000 batch size (balanced for performance)
          batch_size <- 5000
          total_batches <- ceiling(total_fetch / batch_size)
          
          add_log(paste("Downloading", format(total_fetch, big.mark = ","), 
                        "records in", total_batches, "batches (5,000 per batch)"))
          session$sendCustomMessage("log_update", list(
            message = paste("Downloading", format(total_fetch, big.mark = ","), 
                            "records in", total_batches, "batches...")
          ))
          
          all_batches <- list()
          start_time <- Sys.time()
          
          # Initialize progress bar
          session$sendCustomMessage("progress_update", list(value = 0))
          
          for (i in seq_len(total_batches)) {
            offset <- (i - 1) * batch_size
            current_limit <- min(batch_size, total_fetch - offset)
            
            # Log batch start
            batch_msg <- paste("Batch", i, "of", total_batches, 
                               "- downloading", format(current_limit, big.mark = ","), "records...")
            add_log(batch_msg)
            
            if (i %% 5 == 0 || i == total_batches) {
              session$sendCustomMessage("log_update", list(
                message = paste("Batch", i, "of", total_batches, "...")
              ))
            }
            
            # Download without withTimeout
            batch <- tryCatch({
              occ_search(
                scientificName = species_name,
                hasCoordinate  = TRUE,
                year           = paste0(input$year_from, "," , format(Sys.Date(), "%Y")),
                limit          = current_limit,
                start          = offset,
                fields = c("key","species","decimalLongitude","decimalLatitude",
                           "year","countryCode","basisOfRecord")
              )$data
            }, error = function(e) {
              add_log(paste("  ❌ Batch", i, "failed:", e$message))
              session$sendCustomMessage("log_update", list(
                message = paste("❌ Batch", i, "failed")
              ))
              NULL
            })
            
            if (!is.null(batch) && nrow(batch) > 0) {
              all_batches[[i]] <- batch
              
              # Calculate progress
              records_so_far <- sum(sapply(all_batches, nrow), na.rm = TRUE)
              percent_complete <- round(records_so_far / total_fetch * 100, 1)
              
              # Update progress bar
              session$sendCustomMessage("progress_update", list(value = percent_complete))
              
              # Log progress every 5 batches
              if (i %% 5 == 0 || i == total_batches) {
                elapsed <- round(as.numeric(difftime(Sys.time(), start_time, units = "secs")), 1)
                speed <- if (elapsed > 0) round(records_so_far / elapsed, 1) else 0
                progress_msg <- paste("  ✓ Batch", i, "done -", 
                                      format(records_so_far, big.mark = ","), 
                                      "records (", percent_complete, "%) -", speed, "rec/sec")
                add_log(progress_msg)
                session$sendCustomMessage("log_update", list(
                  message = paste("✓", format(records_so_far, big.mark = ","), 
                                  "records (", percent_complete, "%)")
                ))
              }
            } else {
              add_log(paste("  ⚠️ Batch", i, "returned no data"))
            }
          }
          
          gbif_raw <- bind_rows(all_batches)
          
          total_time <- round(as.numeric(difftime(Sys.time(), start_time, units = "secs")), 1)
          avg_speed <- if (total_time > 0) round(nrow(gbif_raw) / total_time, 1) else 0
          
          final_msg <- paste("✅ Downloaded", format(nrow(gbif_raw), big.mark = ","), 
                             "records in", total_time, "seconds (", avg_speed, "rec/sec)")
          add_log(final_msg)
          session$sendCustomMessage("log_update", list(message = final_msg))
          session$sendCustomMessage("progress_update", list(value = 100))
        }
        
      }, error = function(e) {
        error_msg <- paste("❌ ERROR - GBIF:", e$message)
        add_log(error_msg)
        session$sendCustomMessage("log_update", list(message = error_msg))
        showNotification(paste("GBIF error:", e$message), type = "error")
      })
      
      if (is.null(gbif_raw) || nrow(gbif_raw) == 0) {
        add_log("ERROR: No GBIF records. Stopping.")
        session$sendCustomMessage("log_update", list(message = "❌ No GBIF records found"))
        showNotification("No GBIF records found.", type = "error")
        return()
      }  # -------------------------------------------------
      # -------------------------------------------------
      # STEP 2: COORDINATE CLEANING
      # -------------------------------------------------
      
      incProgress(0.05, detail = "Cleaning coordinates...")
      add_log("Cleaning coordinates...")
      
      gbif <- gbif_raw %>%
        dplyr::select(key, species, decimalLongitude, decimalLatitude,
                      year, countryCode, basisOfRecord) %>%
        filter(!is.na(decimalLongitude), !is.na(decimalLatitude), !is.na(year))
      
      clean_flags <- clean_coordinates(
        x = gbif, lon = "decimalLongitude", lat = "decimalLatitude",
        species = "species",
        tests   = c("capitals","centroids","equal","gbif","institutions","zeros")
      )
      
      gbif_clean <- gbif[clean_flags$.summary, ] %>%
        distinct(species, decimalLongitude, decimalLatitude, year,
                 .keep_all = TRUE) %>%
        filter(year >= input$year_from)
      
      add_log(paste("After cleaning:", nrow(gbif_clean), "records"))
      
      # =========================================================
      # BENCHMARK: Coordinate Cleaning
      # =========================================================
      benchmark$steps[[length(benchmark$steps) + 1]] <- list(
        step = "Coordinate Cleaning",
        time = round(as.numeric(difftime(Sys.time(), benchmark$start, units = "secs")), 1)
      )
      
      # =========================================================
      # CREATE COARSENED DATA FOR SDM TRAINING ONLY
      # =========================================================
      if (nrow(gbif_clean) > 10000) {
        add_log(paste("Creating coarsened dataset for SDM training (", nrow(gbif_clean), "→", sep = ""))
        set.seed(42)
        gbif_clean_sdm <- coarsen_points(gbif_clean, res = 0.0417)
        add_log(paste("  SDM training set:", nrow(gbif_clean_sdm), "points (coarsened)"))
        add_log(paste("  Full validation set:", nrow(gbif_clean), "points (all other layers)"))
      } else {
        gbif_clean_sdm <- gbif_clean
        add_log(paste("SDM training set:", nrow(gbif_clean_sdm), "points (all points)"))
      }
      # -------------------------------------------------
      # STEP 3: GEE INIT
      # -------------------------------------------------
      
      incProgress(0.03, detail = "Initialising GEE...")
      tryCatch({
        # Use service account JSON key — shiny server runs as shiny user
        cred_dir  <- "/home/shiny/.config/earthengine"
        json_keys <- list.files(cred_dir, pattern = ".json$", full.names = TRUE)
        
        if (length(json_keys) > 0) {
          key_file <- json_keys[1]
          key_data <- jsonlite::fromJSON(key_file)
          sa_email <- key_data$client_email
          # Authenticate via service account — no browser/stdin needed
          ee  <- reticulate::import("ee")
          creds <- ee$ServiceAccountCredentials(sa_email, key_file)
          ee$Initialize(credentials = creds)
          
          # rgee's ee_as_sf() / ee_exist_credentials() hardcode the lookup path
          # to ~/.config/earthengine (i.e. /root when run as root, but our creds
          # live under /home/shiny). Write a session info file to BOTH possible
          # locations so rgee's internal helpers can always find it.
          for (rgee_dir in c("/root/.config/earthengine", "/home/shiny/.config/earthengine")) {
            tryCatch({
              if (!dir.exists(rgee_dir)) dir.create(rgee_dir, recursive = TRUE)
              session_file <- file.path(rgee_dir, "rgee_sessioninfo.txt")
              if (!file.exists(session_file)) {
                writeLines(
                  paste("user", sa_email, sep = "\t"),
                  session_file
                )
              }
            }, error = function(e) NULL)
          }
          
          add_log(paste("GEE initialised successfully (service account:", sa_email, ")"))
        } else {
          stop("No service account JSON key found in credentials folder.")
        }
      }, error = function(e) {
        add_log(paste("GEE ERROR:", e$message))
      })
      
      # -------------------------------------------------
      # STEP 4: COPERNICUS LC (2015-2019 ONLY)
      # -------------------------------------------------
      
      final_table_cop <- NULL
      habitats        <- NULL
      
      if (input$run_copernicus) {
        incProgress(0.1, detail = "Extracting Copernicus land cover...")
        add_log("Extracting Copernicus land cover (2015-2019 only)...")
        
        tryCatch({
          
          lc_collection <- ee$ImageCollection(
            "COPERNICUS/Landcover/100m/Proba-V-C3/Global"
          )
          
          results_list <- list()
          for (yr in sort(unique(gbif_clean$year))) {
            yr_pts <- gbif_clean %>% filter(year == yr)
            if (nrow(yr_pts) == 0) next
            
            if (yr >= 2015 && yr <= 2019) {
              yr_sf  <- st_as_sf(yr_pts,
                                 coords = c("decimalLongitude","decimalLatitude"),
                                 crs = 4326)
              lc_img <- lc_collection$
                filterDate(paste0(yr,"-01-01"), paste0(yr,"-12-31"))$first()
              samp   <- lc_img$select("discrete_classification")$sampleRegions(
                collection = sf_as_ee(yr_sf), scale = 100, geometries = TRUE
              )
              # Drop geometry so all years bind as plain data frames
              results_list[[as.character(yr)]] <- ee_as_sf(samp, maxFeatures = 10000) %>%
                st_drop_geometry()
            } else {
              add_log(paste("Copernicus: No data available for year", yr, "(outside 2015-2019 range)"))
              # Plain data frame with NA code only — lc_name comes from join below
              yr_pts$discrete_classification <- NA_integer_
              results_list[[as.character(yr)]] <- yr_pts
            }
          }
          
          # Combine results - properly handle sf objects
          cop_results <- bind_rows(results_list) %>%
            left_join(lc_lookup, by = c("discrete_classification" = "lc_value"))
          
          # Fetch IUCN habitats (shared with ESRI step)
          tiger_api  <- rl_species(genus = genus_name, species = sp_epithet,
                                   key = api_token)
          latest_id  <- tiger_api$assessments %>%
            filter(latest == TRUE) %>% slice(1) %>% pull(assessment_id)
          assessment <- rl_assessment(id = latest_id, key = api_token)
          habitats   <- assessment$habitats %>%
            mutate(description = description$en)
          
          valid_lc <- get_valid_lc(habitats, habitat_name_map,
                                   translation_table, threshold = 1.743)
          
          # For years with actual data, calculate flags
          cop_results <- cop_results %>%
            mutate(
              flag_habitat_cop = ifelse(
                is.na(discrete_classification),
                NA,
                !(discrete_classification %in% valid_lc)
              ),
              remark_cop = case_when(
                is.na(discrete_classification) ~ "No Copernicus data (only 2015-2019)",
                flag_habitat_cop == TRUE        ~ paste0("FLAGGED: LC '", coalesce(lc_name, "Unknown"), "' not valid for ", species_name),
                TRUE                            ~ paste0("CLEAN: Valid habitat (Copernicus) \u2014 ", coalesce(lc_name, "Unknown"))
              )
            )
          
          # Convert to data frame
          final_table_cop <- cop_results %>%
            rename(lc_name_cop                 = lc_name,
                   discrete_classification_cop = discrete_classification)
          
          add_log(paste("Copernicus: flagged",
                        sum(final_table_cop$flag_habitat_cop == TRUE, na.rm = TRUE), "of",
                        nrow(final_table_cop), "points"))
          add_log(paste("Copernicus: no data for",
                        sum(is.na(final_table_cop$discrete_classification_cop)), "points (years outside 2015-2019)"))
          benchmark$steps[[length(benchmark$steps) + 1]] <- list(
            step = "Copernicus LC",
            time = round(as.numeric(difftime(Sys.time(), benchmark$start, units = "secs")), 1)
          )
          
        }, error = function(e) {
          add_log(paste("ERROR - Copernicus:", e$message))
        })
      }
      # -------------------------------------------------
      # STEP 4b: ESRI LC (2017-2025)
      # -------------------------------------------------
      
      final_table_esri <- NULL
      
      if (input$run_esri) {
        incProgress(0.1, detail = "Extracting ESRI land cover...")
        add_log("Extracting ESRI 10m land cover (2017-2025)...")
        
        tryCatch({
          
          esri_col     <- ee$ImageCollection(
            "projects/sat-io/open-datasets/landcover/ESRI_Global-LULC_10m_TS"
          )
          
          esri_list <- list()
          for (yr in sort(unique(gbif_clean$year))) {
            yr_pts <- gbif_clean %>% filter(year == yr)
            if (nrow(yr_pts) == 0) next
            
            # ESRI data available from 2017-2025
            esri_year <- pmax(pmin(yr, 2025), 2017)
            
            yr_sf  <- st_as_sf(yr_pts,
                               coords = c("decimalLongitude","decimalLatitude"),
                               crs = 4326)
            
            lc_img <- esri_col$
              filter(ee$Filter$calendarRange(esri_year, esri_year, "year"))$mosaic()
            
            samp   <- lc_img$select("b1")$sampleRegions(
              collection = sf_as_ee(yr_sf), scale = 10, geometries = TRUE
            )
            esri_list[[as.character(yr)]] <- ee_as_sf(samp, maxFeatures = 10000)
          }
          
          esri_results <- do.call(rbind, esri_list) %>%
            left_join(esri_lc_lookup, by = c("b1" = "lc_value"))
          
          # Reuse habitats from Copernicus if available
          hab_esri <- if (!is.null(habitats)) habitats else {
            api2  <- rl_species(genus = genus_name, species = sp_epithet,
                                key = api_token)
            id2   <- api2$assessments %>%
              filter(latest == TRUE) %>% slice(1) %>% pull(assessment_id)
            rl_assessment(id = id2, key = api_token)$habitats %>%
              mutate(description = description$en)
          }
          
          valid_esri <- get_valid_lc_esri(hab_esri, habitat_name_map,
                                          esri_habitat_to_lc)
          
          final_table_esri <- esri_results %>%
            mutate(
              flag_habitat_esri = !(b1 %in% valid_esri),
              remark_esri = if_else(
                flag_habitat_esri,
                paste0("FLAGGED: ESRI LC '", lc_name,
                       "' not valid for ", species_name),
                paste0("CLEAN: Valid habitat \u2014 ", lc_name, " (ESRI)"))
            ) %>%
            st_drop_geometry() %>%
            rename(esri_lc_code = b1,
                   lc_name_esri = lc_name)
          
          add_log(paste("ESRI LC: flagged",
                        sum(final_table_esri$flag_habitat_esri), "of",
                        nrow(final_table_esri), "points"))
          # =========================================================
          # BENCHMARK: ESRI LC
          # =========================================================
          benchmark$steps[[length(benchmark$steps) + 1]] <- list(
            step = "ESRI LC",
            time = round(as.numeric(difftime(Sys.time(), benchmark$start, units = "secs")), 1)
          )
          
        }, error = function(e) add_log(paste("ERROR - ESRI:", e$message)))
      }
      
      # -------------------------------------------------
      # STEP 5: SATELLITE EMBEDDINGS
      # -------------------------------------------------
      
      emb_result <- NULL
      
      if (input$run_embeddings) {
        incProgress(0.1, detail = "Extracting satellite embeddings...")
        add_log("Extracting satellite embeddings...")
        
        tryCatch({
          
          emb_col <- ee$ImageCollection("GOOGLE/SATELLITE_EMBEDDING/V1/ANNUAL")
          pts_emb <- gbif_clean %>%
            mutate(emb_year = pmax(pmin(as.integer(year), 2024), 2017))
          emb_list <- list()
          
          for (yr in sort(unique(pts_emb$emb_year))) {
            yr_pts  <- pts_emb %>% filter(emb_year == yr)
            yr_sf   <- st_as_sf(yr_pts,
                                coords = c("decimalLongitude","decimalLatitude"),
                                crs = 4326)
            emb_img <- emb_col$
              filter(ee$Filter$calendarRange(yr, yr, "year"))$mosaic()
            bands   <- emb_img$bandNames()$getInfo()
            samp    <- emb_img$select(bands)$sampleRegions(
              collection = sf_as_ee(yr_sf), scale = 10, geometries = FALSE
            )
            emb_list[[as.character(yr)]] <- ee_as_sf(samp, maxFeatures = 10000)
          }
          
          emb_all  <- do.call(rbind, emb_list)
          emb_df   <- st_drop_geometry(emb_all)
          emb_cols <- grep("^A", names(emb_df), value = TRUE)
          X        <- scale(as.matrix(emb_df[, emb_cols]))
          
          iso    <- isolation.forest(X, ntrees = 200, sample_size = 256)
          scores <- predict(iso, X, type = "score")
          thr    <- quantile(scores, 0.95)
          
          emb_df$outlier_score  <- scores
          emb_df$flag_embedding <- as.integer(scores >= thr)
          emb_df$emb_year       <- pts_emb$emb_year[
            match(emb_df$key, pts_emb$key)]
          
          emb_result <- emb_df %>%
            dplyr::select(key, emb_year, outlier_score, flag_embedding)
          
          pca_obj <- prcomp(X)
          # Join LC names for PCA colouring — emb_df only has GEE bands + key
          pca_lc <- emb_df %>%
            dplyr::select(key) %>%
            left_join(
              if (!is.null(final_table_cop))
                final_table_cop %>% dplyr::select(key, lc_name_cop)
              else
                data.frame(key = character(0), lc_name_cop = character(0)),
              by = "key"
            ) %>%
            left_join(
              if (!is.null(final_table_esri))
                final_table_esri %>% dplyr::select(key, lc_name_esri)
              else
                data.frame(key = character(0), lc_name_esri = character(0)),
              by = "key"
            ) %>%
            mutate(lc_label = coalesce(lc_name_esri, "Unknown"))
          pca_data(list(
            scores     = pca_obj$x,
            lc_names   = pca_lc$lc_label,
            outlier    = emb_df$flag_embedding,
            emb_scores = scores,
            keys       = emb_df$key
          ))
          emb_flags(emb_df)
          
          add_log(paste("Embeddings: flagged",
                        sum(emb_df$flag_embedding), "outliers"))
          # =========================================================
          # BENCHMARK: Satellite Embeddings
          # =========================================================
          benchmark$steps[[length(benchmark$steps) + 1]] <- list(
            step = "Satellite Embeddings",
            time = round(as.numeric(difftime(Sys.time(), benchmark$start, units = "secs")), 1)
          )
          
        }, error = function(e) add_log(paste("ERROR - Embeddings:", e$message)))
      }
      
      # -------------------------------------------------
      # STEP 6: CLIMATE SDM
      # -------------------------------------------------
      
      sdm_result <- NULL
      
      if (input$run_sdm) {
        incProgress(0.15, detail = "Running climate SDM (biomod2)...")
        add_log("Running biomod2 climate SDM...")
        
        tryCatch({
          
          # =========================================================
          # PART 1: SDM TRAINING - USE COARSENED DATA
          # =========================================================
          
          add_log(paste("SDM training using", nrow(gbif_clean_sdm), "coarsened points"))
          
          occ_xy_train <- gbif_clean_sdm %>%
            rename(longitude = decimalLongitude,
                   latitude  = decimalLatitude) %>%
            dplyr::select(key, longitude, latitude)
          
          {
            clim_path <- "/srv/climate_cache"
            if (!dir.exists(clim_path)) {
              clim_path <- file.path(tempdir(), "climate_cache")
              dir.create(clim_path, recursive = TRUE, showWarnings = FALSE)
            }
            bio_data <- worldclim_global(var = "bio", res = 2.5, path = clim_path)
          }
          bio_data <- bio_data
          
          occ_ext  <- ext(min(occ_xy_train$longitude) - 2, max(occ_xy_train$longitude) + 2,
                          min(occ_xy_train$latitude)  - 2, max(occ_xy_train$latitude)  + 2)
          bio_crop <- crop(bio_data, occ_ext)
          
          vals <- values(bio_crop, na.rm = TRUE)
          if (nrow(vals) > 10000) vals <- vals[sample(nrow(vals), 10000), ]
          cor_mat <- cor(vals, use = "pairwise.complete.obs")
          nms <- rownames(cor_mat)
          keep <- nms[1]
          for (v in nms[-1]) {
            if (max(abs(cor_mat[v, keep]), na.rm = TRUE) < 0.7)
              keep <- c(keep, v)
          }
          bio_sel <- bio_crop[[keep]]
          
          resp_xy <- occ_xy_train %>%
            dplyr::select(longitude, latitude) %>%
            as.data.frame()
          
          # biomod2 writes model files to working dir — use a writable temp dir
          biomod_wd <- file.path(tempdir(), "biomod2_runs")
          dir.create(biomod_wd, recursive = TRUE, showWarnings = FALSE)
          old_wd <- setwd(biomod_wd)
          on.exit(setwd(old_wd), add = TRUE)
          
          bm_data <- BIOMOD_FormatingData(
            resp.name      = species_name_clean,
            resp.var       = rep(1, nrow(resp_xy)),
            resp.xy        = as.matrix(resp_xy),
            expl.var       = bio_sel,
            PA.strategy    = "random",
            PA.nb.rep      = 2,
            PA.nb.absences = nrow(resp_xy),
            na.rm          = TRUE
          )
          
          bm_out <- BIOMOD_Modeling(
            bm.format       = bm_data,
            modeling.id     = species_name_clean,
            models          = c("GLM","RF"),
            CV.strategy     = "random",
            CV.nb.rep       = 2,
            CV.perc         = 0.8,
            metric.eval     = c("TSS","AUCroc"),
            seed.val        = 42
          )
          
          bm_em <- BIOMOD_EnsembleModeling(
            bm.mod               = bm_out,
            models.chosen        = "all",
            em.by                = "all",
            em.algo              = c("EMmean"),
            metric.select        = "TSS",
            metric.select.thresh = 0.4,
            metric.eval          = c("TSS","AUCroc"),
            seed.val             = 42
          )
          
          bm_proj <- BIOMOD_EnsembleForecasting(
            bm.em         = bm_em,
            proj.name     = "current",
            new.env       = bio_sel,
            models.chosen = "all",
            metric.binary = "TSS",
            metric.filter = "TSS"
          )
          
          suit_rast_all <- get_predictions(bm_proj)
          layer_names   <- names(suit_rast_all)
          cont_layers   <- layer_names[
            grepl("EMmean", layer_names, ignore.case = TRUE) &
              !grepl("bin|filt|binary|filtered", layer_names, ignore.case = TRUE)
          ]
          
          suit_rast <- if (length(cont_layers) > 0) {
            add_log(paste("SDM: using layer:", cont_layers[1]))
            suit_rast_all[[cont_layers[1]]]
          } else {
            na_counts  <- sapply(seq_len(nlyr(suit_rast_all)), function(i)
              sum(is.na(values(suit_rast_all[[i]]))))
            best_layer <- which.min(na_counts)
            add_log(paste("SDM: fallback to layer:", layer_names[best_layer]))
            suit_rast_all[[best_layer]]
          }
          
          # Store SDM raster for mapping
          if (exists("suit_rast")) {
            map_data$sdm_rast <- suit_rast
            add_log("SDM raster stored for mapping")
          }
          
          # =========================================================
          # PART 2: SDM EXTRACTION - USE ALL POINTS
          # =========================================================
          
          add_log(paste("SDM extracting for", nrow(gbif_clean), "points (full dataset)"))
          
          occ_xy_all <- gbif_clean %>%
            rename(longitude = decimalLongitude,
                   latitude  = decimalLatitude) %>%
            dplyr::select(key, longitude, latitude)
          
          pts_v <- vect(occ_xy_all, geom = c("longitude","latitude"),
                        crs = "EPSG:4326")
          if (!same.crs(pts_v, suit_rast))
            pts_v <- project(pts_v, crs(suit_rast))
          
          suit_vals <- terra::extract(suit_rast, pts_v)
          names(suit_vals)[2] <- "suitability_score"
          suit_vals$key <- occ_xy_all$key
          
          valid_n <- sum(!is.na(suit_vals$suitability_score))
          add_log(paste("SDM: valid extractions:", valid_n, "of", nrow(gbif_clean), "points"))
          
          if (valid_n > 0) {
            thr_sdm <- quantile(suit_vals$suitability_score, 0.1, na.rm = TRUE)
            sdm_result <- suit_vals %>%
              mutate(
                flag_climate_sdm = case_when(
                  is.na(suitability_score) ~ FALSE,
                  suitability_score < thr_sdm ~ TRUE,
                  TRUE ~ FALSE
                ),
                sdm_remark = case_when(
                  is.na(suitability_score) ~ "UNKNOWN: No suitability data",
                  flag_climate_sdm ~ paste0("FLAGGED: Low suitability (",
                                            round(suitability_score,1),")"),
                  TRUE ~ paste0("CLEAN: Suitable (",
                                round(suitability_score,1),")")
                )
              ) %>%
              dplyr::select(key, suitability_score, flag_climate_sdm, sdm_remark)
            add_log(paste("SDM: flagged", sum(sdm_result$flag_climate_sdm), "points"))
            
            # =========================================================
            # BENCHMARK: Climate SDM
            # =========================================================
            benchmark$steps[[length(benchmark$steps) + 1]] <- list(
              step = "Climate SDM",
              time = round(as.numeric(difftime(Sys.time(), benchmark$start, units = "secs")), 1)
            )
          }
          
        }, error = function(e) add_log(paste("ERROR - SDM:", e$message)))
      }
      # =========================================================
      # STEP 7: IUCN RANGE - CASE-INSENSITIVE VERSION
      # =========================================================
      
      range_result <- NULL
      
      if (input$run_range) {
        incProgress(0.05, detail = "IUCN range intersection...")
        add_log("Running IUCN range intersection...")
        
        tryCatch({
          
          shp_files <- input$range_file
          add_log(paste("Uploaded files:", paste(shp_files$name, collapse = ", ")))
          
          range_path <- if (!is.null(shp_files))
            shp_files$datapath[grepl("\\.shp$", shp_files$name)] else NULL
          
          add_log(paste("Range path:", range_path))
          add_log(paste("File exists:", file.exists(range_path)))
          
          if (!is.null(range_path) && length(range_path) > 0 &&
              file.exists(range_path)) {
            
            tmp_dir   <- dirname(range_path)
            base_name <- tools::file_path_sans_ext(basename(range_path))
            
            add_log(paste("Temp dir:", tmp_dir))
            add_log(paste("Base name:", base_name))
            
            for (ext_i in c(".shx",".dbf",".prj")) {
              src <- shp_files$datapath[grepl(paste0("\\", ext_i, "$"),
                                              shp_files$name)]
              if (length(src) > 0) {
                file.copy(src, file.path(tmp_dir, paste0(base_name, ext_i)),
                          overwrite = TRUE)
                add_log(paste("Copied:", src, "to", file.path(tmp_dir, paste0(base_name, ext_i))))
              } else {
                add_log(paste("Warning: No", ext_i, "file found"))
              }
            }
            
            add_log("Reading shapefile...")
            iucn_range <- st_read(range_path, quiet = TRUE)
            add_log(paste("Shapefile loaded:", nrow(iucn_range), "rows"))
            add_log(paste("Columns:", paste(names(iucn_range), collapse = ", ")))
            
            # =========================================================
            # CRITICAL FIX: Case-insensitive column name handling
            # =========================================================
            
            # Get all column names
            col_names <- names(iucn_range)
            
            # Find columns case-insensitively
            presence_col <- col_names[grepl("^presence$", col_names, ignore.case = TRUE)]
            origin_col <- col_names[grepl("^origin$", col_names, ignore.case = TRUE)]
            seasonal_col <- col_names[grepl("^seasonal$|^seasonality$", col_names, ignore.case = TRUE)]
            legend_col <- col_names[grepl("^legend$", col_names, ignore.case = TRUE)]
            sci_name_col <- col_names[grepl("^sci_name$|^scientific_name$|^sciname$", col_names, ignore.case = TRUE)]
            
            add_log(paste("Found columns - PRESENCE:", 
                          if (length(presence_col) > 0) presence_col[1] else "NONE"))
            add_log(paste("Found columns - ORIGIN:", 
                          if (length(origin_col) > 0) origin_col[1] else "NONE"))
            add_log(paste("Found columns - SEASONAL:", 
                          if (length(seasonal_col) > 0) seasonal_col[1] else "NONE"))
            add_log(paste("Found columns - LEGEND:", 
                          if (length(legend_col) > 0) legend_col[1] else "NONE"))
            
            # =========================================================
            # CRITICAL: Handle case-insensitive column selection
            # =========================================================
            
            # Select columns that exist (using the actual column names)
            select_cols <- character()
            if (length(presence_col) > 0) select_cols <- c(select_cols, presence_col[1])
            if (length(origin_col) > 0) select_cols <- c(select_cols, origin_col[1])
            if (length(seasonal_col) > 0) select_cols <- c(select_cols, seasonal_col[1])
            if (length(legend_col) > 0) select_cols <- c(select_cols, legend_col[1])
            
            # If no columns found, try a different approach
            if (length(select_cols) == 0) {
              add_log("WARNING: No standard columns found. Using all columns.")
              select_cols <- col_names
            }
            
            add_log(paste("Selecting columns:", paste(select_cols, collapse = ", ")))
            
            # Get CRS
            range_crs <- st_crs(iucn_range)
            add_log(paste("Shapefile CRS:", if (!is.na(range_crs$epsg)) 
              paste0("EPSG:", range_crs$epsg) else range_crs$input))
            
            # Create points with WGS84
            pts_sf <- gbif_clean %>%
              st_as_sf(coords = c("decimalLongitude", "decimalLatitude"),
                       crs = 4326)
            
            add_log(paste("Points CRS: EPSG:4326 (WGS84)"))
            
            # Transform if needed
            if (!is.na(range_crs$epsg) && range_crs$epsg != 4326) {
              add_log(paste("Transforming points to", 
                            if (!is.na(range_crs$epsg)) paste0("EPSG:", range_crs$epsg) else range_crs$input))
              pts_sf <- st_transform(pts_sf, range_crs)
            }
            
            # =========================================================
            # Perform spatial join
            # =========================================================
            
            add_log("Performing spatial join...")
            
            # Try with a small buffer for edge cases
            pts_buffered <- st_buffer(pts_sf, dist = 1)
            
            # Join with the selected columns
            pts_joined <- st_join(
              pts_sf,
              iucn_range %>% dplyr::select(all_of(select_cols)),
              join = st_intersects,
              left = TRUE
            )
            
            # Also try with buffer to catch edge cases
            pts_joined_buffered <- st_join(
              pts_buffered,
              iucn_range %>% dplyr::select(all_of(select_cols)),
              join = st_intersects,
              left = TRUE
            )
            
            # Check which gave more intersections
            n_intersect <- sum(!is.na(pts_joined[[presence_col[1]]]))
            n_intersect_buf <- sum(!is.na(pts_joined_buffered[[presence_col[1]]]))
            
            add_log(paste("Standard intersect:", n_intersect, "points"))
            add_log(paste("With buffer:", n_intersect_buf, "points"))
            
            # Use the one with more intersections
            if (n_intersect_buf > n_intersect) {
              add_log("Using buffered result (caught edge cases)")
              pts_joined <- pts_joined_buffered
            }
            
            # =========================================================
            # Create result with consistent column names
            # =========================================================
            
            # Get the actual values using the found column names
            presence_vals <- if (length(presence_col) > 0) pts_joined[[presence_col[1]]] else NA_integer_
            origin_vals <- if (length(origin_col) > 0) pts_joined[[origin_col[1]]] else NA_integer_
            seasonal_vals <- if (length(seasonal_col) > 0) pts_joined[[seasonal_col[1]]] else NA_integer_
            legend_vals <- if (length(legend_col) > 0) pts_joined[[legend_col[1]]] else NA_character_
            
            range_result <- pts_joined %>%
              st_drop_geometry() %>%
              mutate(
                # Use the found columns or NA
                PRESENCE = presence_vals,
                ORIGIN = origin_vals,
                SEASONAL = seasonal_vals,
                LEGEND = legend_vals,
                
                # Create LEGEND if missing
                LEGEND = case_when(
                  is.na(LEGEND) & PRESENCE == 1 ~ "Extant (resident)",
                  is.na(LEGEND) & PRESENCE == 2 ~ "Probably Extant",
                  is.na(LEGEND) & PRESENCE == 3 ~ "Possibly Extant",
                  is.na(LEGEND) & PRESENCE == 4 ~ "Possibly Extinct",
                  is.na(LEGEND) & PRESENCE == 5 ~ "Extinct",
                  is.na(LEGEND) & PRESENCE == 6 ~ "Presence Uncertain",
                  is.na(LEGEND) & PRESENCE == 7 ~ "Expected Additional Range",
                  TRUE ~ LEGEND
                ),
                
                presence_priority = case_when(
                  PRESENCE == 1  ~ 1,
                  PRESENCE == 2  ~ 2,
                  PRESENCE == 3  ~ 3,
                  PRESENCE == 7  ~ 4,
                  PRESENCE == 6  ~ 5,
                  PRESENCE == 4  ~ 6,
                  PRESENCE == 5  ~ 7,
                  is.na(PRESENCE)~ 8
                ),
                
                in_iucn_range = PRESENCE %in% c(1, 2, 3, 7),
                
                origin_desc = case_when(
                  ORIGIN == 1 ~ "Native",
                  ORIGIN == 2 ~ "Reintroduced",
                  ORIGIN == 3 ~ "Introduced",
                  ORIGIN == 4 ~ "Vagrant",
                  ORIGIN == 5 ~ "Origin uncertain",
                  ORIGIN == 6 ~ "Assisted Colonisation",
                  TRUE ~ "Unknown"
                ),
                
                seasonal_desc = case_when(
                  SEASONAL == 1 ~ "Resident",
                  SEASONAL == 2 ~ "Breeding season",
                  SEASONAL == 3 ~ "Non-breeding season",
                  SEASONAL == 4 ~ "Passage",
                  SEASONAL == 5 ~ "Seasonal Occurrence Uncertain",
                  TRUE ~ "Unknown"
                ),
                
                range_remark = case_when(
                  PRESENCE == 1  ~ paste0("INSIDE: Extant (", origin_desc, ", ", seasonal_desc, ")"),
                  PRESENCE == 2  ~ paste0("INSIDE: Probably Extant (", origin_desc, ", ", seasonal_desc, ")"),
                  PRESENCE == 3  ~ paste0("INSIDE: Possibly Extant (", origin_desc, ", ", seasonal_desc, ")"),
                  PRESENCE == 7  ~ "INSIDE: Expected Additional Range",
                  PRESENCE == 6  ~ paste0("UNCERTAIN: Presence uncertain (", origin_desc, ")"),
                  PRESENCE == 4  ~ paste0("CAUTION: Possibly Extinct (", origin_desc, ", ", seasonal_desc, ")"),
                  PRESENCE == 5  ~ paste0("CAUTION: Extinct (post 1500) (", origin_desc, ", ", seasonal_desc, ")"),
                  is.na(PRESENCE) ~ "OUTSIDE: Point outside IUCN range",
                  TRUE ~ paste0("RANGE: Unknown status (PRESENCE=", PRESENCE, ")")
                ),
                
                range_status = case_when(
                  PRESENCE == 1  ~ "Extant",
                  PRESENCE == 2  ~ "Probably Extant",
                  PRESENCE == 3  ~ "Possibly Extant",
                  PRESENCE == 7  ~ "Expected",
                  PRESENCE == 6  ~ "Uncertain",
                  PRESENCE == 4  ~ "Possibly Extinct",
                  PRESENCE == 5  ~ "Extinct",
                  is.na(PRESENCE) ~ "Outside",
                  TRUE ~ "Unknown"
                ),
                
                range_suspicion = case_when(
                  PRESENCE == 1 & ORIGIN == 1 & SEASONAL == 1 ~ "CLEAN",
                  PRESENCE == 1 & ORIGIN == 1 ~ "CLEAN",
                  PRESENCE == 2 ~ "CLEAN",
                  PRESENCE == 7 ~ "CLEAN",
                  PRESENCE == 3 ~ "INVESTIGATE",
                  PRESENCE == 6 ~ "INVESTIGATE",
                  PRESENCE == 4 ~ "HIGH SUSPICION",
                  PRESENCE == 5 ~ "HIGH SUSPICION",
                  is.na(PRESENCE) ~ "OUTSIDE",
                  TRUE ~ "REVIEW"
                )
              ) %>%
              group_by(key) %>%
              slice_min(presence_priority, n = 1, with_ties = FALSE) %>%
              ungroup() %>%
              dplyr::select(
                key, 
                in_iucn_range, 
                PRESENCE, 
                LEGEND, 
                SEASONAL,
                ORIGIN,
                range_remark,
                range_status,
                range_suspicion,
                origin_desc,
                seasonal_desc
              )
            
            add_log(paste("Range: checked", nrow(range_result), "points"))
            add_log(paste("  Inside extant range (in_iucn_range == TRUE):",
                          sum(range_result$in_iucn_range == TRUE, na.rm = TRUE)))
            add_log(paste("  Outside range (in_iucn_range == FALSE):",
                          sum(range_result$in_iucn_range == FALSE, na.rm = TRUE)))
            add_log(paste("  Unknown (in_iucn_range == NA):",
                          sum(is.na(range_result$in_iucn_range))))
            
            # Store range for mapping
            map_data$range_sf <- iucn_range
            
            # =========================================================
            # BENCHMARK: IUCN Range
            # =========================================================
            benchmark$steps[[length(benchmark$steps) + 1]] <- list(
              step = "IUCN Range",
              time = round(as.numeric(difftime(Sys.time(), benchmark$start, units = "secs")), 1)
            )
            
          } else {
            add_log("No range shapefile provided — skipping range check")
          }
          
        }, error = function(e) {
          add_log(paste("ERROR - Range:", e$message))
          add_log(paste("Error details:", capture.output(print(e))))
        })
      }     
      
      # -------------------------------------------------
      # STEP 8: MERGE WITH UNIFIED LAND COVER
      # -------------------------------------------------
      
      incProgress(0.05, detail = "Merging results...")
      add_log("Merging all validation results...")
      
      coords <- gbif_clean %>%
        dplyr::select(key,
                      longitude = decimalLongitude,
                      latitude  = decimalLatitude)
      
      merged <- gbif_clean %>%
        dplyr::select(key, species, year, countryCode, basisOfRecord)
      
      # First merge Copernicus and ESRI data with unified land cover
      if (!is.null(final_table_cop) && !is.null(final_table_esri)) {
        
        # Get valid Copernicus codes and odds ratios
        valid_lc_codes <- get_valid_lc(habitats, habitat_name_map, translation_table, threshold = 1.743)
        odds_ratios <- get_odds_ratios(habitats, translation_table, habitat_name_map)
        redlist_habitats <- get_redlist_habitats(habitats, habitat_name_map)
        
        add_log(paste("Red List habitats:", paste(redlist_habitats, collapse = ", ")))

        
        # Pre-compute habitat lists for each ESRI type
        esri_types <- unique(final_table_esri$lc_name_esri)
        esri_habitat_list <- list()
        esri_best_habitat <- list()
        esri_unique_habitats <- list()
        
        for (esri_type in esri_types) {
          if (!is.na(esri_type) && esri_type != "Unknown" && esri_type != "Clouds") {
            habs <- get_habitats_for_esri(esri_type, redlist_habitats, odds_ratios)
            if (nrow(habs) > 0) {
              # Full list with odds ratios
              esri_habitat_list[[esri_type]] <- paste(
                paste0(habs$habitat, " (", round(habs$odds_ratio, 2), ")"), 
                collapse = ", "
              )
              # Best habitat
              esri_best_habitat[[esri_type]] <- paste0(habs$habitat[1], " (", round(habs$odds_ratio[1], 2), ")")
              
              # UNIQUE HABITATS (with display names and suitability)
              unique_hab_names <- unique(gsub(" \\(.*\\)$", "", habs$habitat))
              # Get display names
              display_names <- sapply(unique_hab_names, function(x) {
                if (x %in% names(habitat_display_names)) {
                  habitat_display_names[x]
                } else {
                  paste0(toupper(substr(x, 1, 1)), substr(x, 2, nchar(x)))
                }
              })
              # Add suitability indicator
              suitability_status <- sapply(unique_hab_names, function(x) {
                hab_odds <- habs %>% filter(habitat == x) %>% pull(odds_ratio) %>% max()
                if (hab_odds >= 1.743) "✅" else "❌"
              })
              formatted_habitats <- paste(suitability_status, display_names)
              esri_unique_habitats[[esri_type]] <- paste(formatted_habitats, collapse = ", ")
              
            } else {
              esri_habitat_list[[esri_type]] <- "None"
              esri_best_habitat[[esri_type]] <- "None"
              esri_unique_habitats[[esri_type]] <- "None"
            }
          }
        }
        # Join the two tables
        land_cover_joined <- final_table_cop %>%
          dplyr::select(key, lc_name_cop, discrete_classification_cop, flag_habitat_cop, remark_cop) %>%
          left_join(
            final_table_esri %>%
              dplyr::select(key, lc_name_esri, esri_lc_code, flag_habitat_esri, remark_esri),
            by = "key"
          ) %>%
          left_join(
            copernicus_to_esri %>% 
              rename(mapped_esri_name = esri_name),
            by = c("lc_name_cop" = "copernicus_name")
          )
        
        # Add pre-computed habitat lists
        land_cover_joined <- land_cover_joined %>%
          rowwise() %>%
          mutate(
            associated_habitats = esri_habitat_list[[lc_name_esri]] %||% "Unknown",
            best_habitat_for_esri = esri_best_habitat[[lc_name_esri]] %||% "Unknown",
            unique_habitats = esri_unique_habitats[[lc_name_esri]] %||% "Unknown",
            
            # ADD THIS - Clean habitat display (no odds ratios, no duplicates)
            # =========================================================
            habitat_display = {
              habs <- esri_habitat_list[[lc_name_esri]] %||% "Unknown"
              
              if (is.null(habs) || length(habs) == 0 || habs == "Unknown" || habs == "None") {
                "Unknown"
              } else {
                # Split by comma
                hab_list <- strsplit(as.character(habs), ", ")[[1]]
                # Extract habitat names (remove odds ratios)
                clean_names <- unique(gsub(" \\(.*\\)$", "", hab_list))
                # Remove empty or NA
                clean_names <- clean_names[!is.na(clean_names) & clean_names != ""]
                
                if (length(clean_names) == 0) {
                  "Unknown"
                } else {
                  # Use display names if available
                  display_names <- sapply(clean_names, function(x) {
                    if (x %in% names(habitat_display_names)) {
                      habitat_display_names[x]
                    } else {
                      paste0(toupper(substr(x, 1, 1)), substr(x, 2, nchar(x)))
                    }
                  })
                  paste(display_names, collapse = ", ")
                }
              }
            }
          ) %>%
          ungroup() %>%
          
          # =========================================================
        # ADD THIS - Handle any remaining NA values
        # =========================================================
        mutate(
          associated_habitats = ifelse(is.na(associated_habitats) | associated_habitats == "", "Unknown", associated_habitats),
          unique_habitats = ifelse(is.na(unique_habitats) | unique_habitats == "", "Unknown", unique_habitats),
          habitat_display = ifelse(is.na(habitat_display) | habitat_display == "", "Unknown", habitat_display)
        ) %>%
          mutate(
            # Check agreement
            lc_agreement = !is.na(mapped_esri_name) & mapped_esri_name == lc_name_esri,
            unified_lc_name = lc_name_esri,
            
            # Get Copernicus code for the best habitat
            unified_cop_code = case_when(
              lc_name_esri == "Trees" ~ {
                habs <- get_habitats_for_esri("Trees", redlist_habitats, odds_ratios)
                if (nrow(habs) > 0) {
                  cop_class <- habs$copernicus_class[1]
                  case_when(
                    cop_class == "Shrubs" ~ 20,
                    cop_class == "Herbaceous vegetation" ~ 30,
                    cop_class == "Cultivated and managed vegetation / Agriculture" ~ 40,
                    cop_class == "Urban / built-up" ~ 50,
                    cop_class == "Bare / sparse vegetation" ~ 60,
                    cop_class == "Snow and ice" ~ 70,
                    cop_class == "Permanent water bodies" ~ 80,
                    cop_class == "Herbaceous wetland" ~ 90,
                    cop_class == "Moss and lichen" ~ 100,
                    cop_class == "Closed forest, evergreen needle leaf" ~ 111,
                    cop_class == "Closed forest, evergreen broad leaf" ~ 112,
                    cop_class == "Closed forest, deciduous needle leaf" ~ 113,
                    cop_class == "Closed forest, deciduous broad leaf" ~ 114,
                    cop_class == "Closed forest, mixed" ~ 115,
                    cop_class == "Closed forest, unknown" ~ 116,
                    cop_class == "Open forest, evergreen needle leaf" ~ 121,
                    cop_class == "Open forest, evergreen broad leaf" ~ 122,
                    cop_class == "Open forest, deciduous needle leaf" ~ 123,
                    cop_class == "Open forest, deciduous broad leaf" ~ 124,
                    cop_class == "Open forest, mixed" ~ 125,
                    cop_class == "Open forest, unknown" ~ 126,
                    cop_class == "Ocean" ~ 200,
                    TRUE ~ NA_integer_
                  )
                } else {
                  NA_integer_
                }
              },
              lc_name_esri == "Rangeland" ~ {
                habs <- get_habitats_for_esri("Rangeland", redlist_habitats, odds_ratios)
                if (nrow(habs) > 0) {
                  cop_class <- habs$copernicus_class[1]
                  case_when(
                    cop_class == "Shrubs" ~ 20,
                    cop_class == "Herbaceous vegetation" ~ 30,
                    cop_class == "Moss and lichen" ~ 100,
                    TRUE ~ NA_integer_
                  )
                } else {
                  NA_integer_
                }
              },
              lc_name_esri == "Crops" ~ 40,
              lc_name_esri == "Built area" ~ 50,
              lc_name_esri == "Bare ground" ~ 60,
              lc_name_esri == "Snow / ice" ~ 70,
              lc_name_esri == "Water" ~ 80,
              lc_name_esri == "Flooded vegetation" ~ 90,
              lc_name_esri == "Clouds" ~ NA_integer_,
              TRUE ~ NA_integer_
            ),
            
            # Flag based on unified land cover
            flag_habitat_final = !(unified_cop_code %in% valid_lc_codes),
            flag_habitat_cop_orig = flag_habitat_cop,
            flag_habitat_esri_orig = flag_habitat_esri,
            
            # Create unified remark
            remark_final = case_when(
              lc_agreement == TRUE ~ paste0("✅ AGREED: ", lc_name_cop, " (Cop) = ", lc_name_esri, " (ESRI) → ", unified_lc_name),
              lc_agreement == FALSE ~ paste0("ℹ️ ESRI-mapped: ", lc_name_cop, " (Cop) ≠ ", lc_name_esri, " (ESRI) → ", unified_lc_name),
              TRUE ~ paste0("INFO: Using unified: ", unified_lc_name)
            )
          )
        
        # Add to merged
        merged <- merged %>%
          left_join(
            land_cover_joined %>%
              dplyr::select(key, 
                            lc_name_cop,
                            lc_name_esri,
                            unified_lc_name,
                            unified_cop_code,
                            lc_agreement,
                            flag_habitat_final,
                            flag_habitat_cop_orig,
                            flag_habitat_esri_orig,
                            remark_final,
                            discrete_classification_cop,
                            esri_lc_code,
                            mapped_esri_name,
                            associated_habitats,
                            unique_habitats,
                            habitat_display,  # <-- ADD THIS
                            best_habitat_for_esri),
            by = "key"
          ) %>%
          rename(
            lc_name = unified_lc_name,
            flag_habitat = flag_habitat_final,
            remark_lc = remark_final
          )
        
        add_log(paste("Land cover unified:", 
                      sum(merged$lc_agreement == TRUE, na.rm = TRUE), "agreements,", 
                      sum(merged$lc_agreement == FALSE, na.rm = TRUE), "disagreements"))
        
      } else if (!is.null(final_table_cop)) {
        # Only Copernicus available
        merged <- merged %>%
          left_join(
            final_table_cop %>%
              dplyr::select(key, lc_name_cop, discrete_classification_cop, flag_habitat_cop, remark_cop),
            by = "key"
          ) %>%
          rename(
            lc_name = lc_name_cop,
            flag_habitat = flag_habitat_cop,
            remark_lc = remark_cop
          )
        merged$lc_agreement <- NA
        merged$lc_name_esri <- NA
        merged$associated_habitats <- NA
        merged$best_habitat_for_esri <- NA
        
      } else if (!is.null(final_table_esri)) {
        # Only ESRI available
        merged <- merged %>%
          left_join(
            final_table_esri %>%
              dplyr::select(key, lc_name_esri, esri_lc_code, flag_habitat_esri, remark_esri),
            by = "key"
          ) %>%
          rename(
            lc_name = lc_name_esri,
            flag_habitat = flag_habitat_esri,
            remark_lc = remark_esri
          )
        merged$lc_agreement <- NA
        merged$lc_name_cop <- NA
        merged$associated_habitats <- NA
        merged$best_habitat_for_esri <- NA
      }
      
      # Add remaining modules
      if (!is.null(emb_result))
        merged <- merged %>% left_join(emb_result, by = "key")
      
      if (!is.null(sdm_result))
        merged <- merged %>% left_join(sdm_result, by = "key")
      
      if (!is.null(range_result))
        merged <- merged %>% left_join(range_result, by = "key")
      
      merged <- merged %>% left_join(coords, by = "key")
      
      # Ensure all flag columns exist
      if (!"flag_habitat"     %in% names(merged)) merged$flag_habitat     <- FALSE
      if (!"flag_habitat_cop" %in% names(merged)) merged$flag_habitat_cop <- FALSE
      if (!"flag_habitat_esri"%in% names(merged)) merged$flag_habitat_esri<- FALSE
      if (!"flag_embedding"   %in% names(merged)) merged$flag_embedding   <- 0L
      if (!"flag_climate_sdm" %in% names(merged)) merged$flag_climate_sdm <- FALSE
      if (!"in_iucn_range"    %in% names(merged)) merged$in_iucn_range    <- NA
      if (!"LEGEND"           %in% names(merged)) merged$LEGEND           <- NA_character_
      if (!"lc_name"          %in% names(merged)) merged$lc_name          <- NA_character_
      if (!"lc_name_cop"      %in% names(merged)) merged$lc_name_cop      <- NA_character_
      if (!"lc_name_esri"     %in% names(merged)) merged$lc_name_esri     <- NA_character_
      if (!"lc_agreement"     %in% names(merged)) merged$lc_agreement     <- NA
      if (!"associated_habitats" %in% names(merged)) merged$associated_habitats <- NA_character_
      if (!"best_habitat_for_esri" %in% names(merged)) merged$best_habitat_for_esri <- NA_character_
      
      # Ensure in_iucn_range is logical
      if ("in_iucn_range" %in% names(merged)) {
        merged$in_iucn_range <- as.logical(merged$in_iucn_range)
      }
      
      # Coalesce NAs
      merged$flag_habitat     <- coalesce(merged$flag_habitat,     FALSE)
      merged$flag_habitat_cop <- coalesce(merged$flag_habitat_cop, FALSE)
      merged$flag_habitat_esri<- coalesce(merged$flag_habitat_esri,FALSE)
      merged$flag_embedding   <- coalesce(merged$flag_embedding,   0L)
      merged$flag_climate_sdm <- coalesce(merged$flag_climate_sdm, FALSE)
      
      # Count flags (excluding LC outlier)
      merged$n_flags <- (
        as.integer(merged$flag_habitat) +
          as.integer(merged$flag_embedding == 1) +
          as.integer(merged$flag_climate_sdm) +
          as.integer(!coalesce(merged$in_iucn_range, TRUE))
      )
      
      # Suspicion level
      merged$suspicion_level_final <- case_when(
        coalesce(merged$LEGEND,"") == "Extant (resident)" & merged$n_flags == 0 ~
          "CLEAN: Inside extant range + passes all checks",
        coalesce(merged$LEGEND,"") == "Extant (resident)" & merged$n_flags == 1 ~
          "CLEAN: Inside extant range \u2014 one flag likely sampling bias",
        coalesce(merged$LEGEND,"") == "Extant (resident)" & merged$n_flags == 2 ~
          "INVESTIGATE: Inside extant range but two checks failed",
        coalesce(merged$LEGEND,"") == "Extant (resident)" & merged$n_flags >= 3 ~
          "INVESTIGATE: Inside extant range but multiple checks failed",
        coalesce(merged$LEGEND,"") == "Extinct" & merged$n_flags == 0 ~
          "INVESTIGATE: Historically extinct range",
        coalesce(merged$LEGEND,"") == "Extinct" & merged$n_flags > 1 ~
          "HIGH SUSPICION: Extinct range + environmental flags",
        coalesce(merged$LEGEND,"") == "Presence Uncertain" & merged$n_flags == 0 ~
          "INVESTIGATE: Presence uncertain range",
        coalesce(merged$LEGEND,"") == "Presence Uncertain" & merged$n_flags > 1 ~
          "HIGH SUSPICION: Uncertain range + environmental flags",
        coalesce(merged$lc_name,"") == "Ocean" ~
          "CLEAR ERROR: Ocean \u2014 impossible location",
        is.na(merged$LEGEND) & merged$n_flags == 0 ~
          "INVESTIGATE: Outside IUCN range but passes all checks",
        is.na(merged$LEGEND) & merged$n_flags == 1 ~
          "INVESTIGATE: Outside range + one check failed",
        is.na(merged$LEGEND) & merged$n_flags == 2 ~
          "HIGH SUSPICION: Outside range + two checks failed",
        is.na(merged$LEGEND) & merged$n_flags >= 3 ~
          "CLEAR ERROR: Outside range + multiple checks failed",
        merged$n_flags == 0 ~ "CLEAN: Passes all checks",
        merged$n_flags == 1 ~ "CLEAN: One flag likely sampling bias",
        merged$n_flags == 2 ~ "INVESTIGATE: Two checks failed",
        merged$n_flags >= 3 ~ "HIGH SUSPICION: Multiple checks failed",
        TRUE                ~ "REVIEW: Manual check required"
      )
      
      results(merged)
      # =========================================================
      # BENCHMARK: Merging Results
      # =========================================================
      benchmark$steps[[length(benchmark$steps) + 1]] <- list(
        step = "Merging Results",
        time = round(as.numeric(difftime(Sys.time(), benchmark$start, units = "secs")), 1)
      )
      
      # Update dropdowns
      levs <- unique(merged$suspicion_level_final)
      updateSelectInput(session, "map_filter",
                        choices = c("All"="all", setNames(levs, levs)))
      updateSelectInput(session, "tbl_filter",
                        choices = c("All"="all", setNames(levs, levs)))
      
      if ("countryCode" %in% names(merged)) {
        ccs <- sort(unique(merged$countryCode))
        updateSelectInput(session, "map_country",
                          choices = c("All"="all", setNames(ccs, ccs)))
      }
      if ("lc_name" %in% names(merged)) {
        lcs <- sort(unique(merged$lc_name))
        updateSelectInput(session, "map_lc",
                          choices = c("All"="all", setNames(lcs, lcs)))
      }
      
      # =========================================================
      # BENCHMARK: Final Summary
      # =========================================================
      total_time <- round(as.numeric(difftime(Sys.time(), benchmark$start, units = "mins")), 1)
      
      add_log("========================================")
      add_log("BENCHMARK SUMMARY")
      for (step in benchmark$steps) {
        add_log(paste(step$step, ":", step$time, "seconds"))
      }
      add_log(paste("Total time:", total_time, "minutes"))
      add_log("========================================")
      
      add_log("========================================")
      add_log("VALIDATION COMPLETE")
      add_log(paste("Total points:    ", nrow(merged)))
      add_log(paste("Clean:           ",
                    sum(grepl("CLEAN",          merged$suspicion_level_final))))
      add_log(paste("Investigate:     ",
                    sum(grepl("INVESTIGATE",    merged$suspicion_level_final))))
      add_log(paste("High suspicion:  ",
                    sum(grepl("HIGH SUSPICION", merged$suspicion_level_final))))
      add_log(paste("Clear errors:    ",
                    sum(grepl("CLEAR ERROR",    merged$suspicion_level_final))))
      add_log("========================================")
      
      incProgress(1, detail = "Done!")
      
    }) # end withProgress
  })   # end observeEvent
  # -------------------------------------------------------
  # VALUE BOXES
  # -------------------------------------------------------
  # Display total records
  output$vbox_gbif_total <- renderValueBox({
    if (gbif_preview$searched && !is.null(gbif_preview$total)) {
      valueBox(
        format(gbif_preview$total, big.mark = ","),
        paste("Total GBIF Records (", input$year_from, "-", format(Sys.Date(), "%Y"), ")", sep = ""),
        icon = icon("database"),
        color = "blue"
      )
    } else {
      valueBox(
        "Search first",
        "Click 'Check Total Records'",
        icon = icon("search"),
        color = "yellow"
      )
    }
  })
  
  output$vbox_total <- renderValueBox({
    df <- results()
    valueBox(if (is.null(df)) "\u2014" else nrow(df),
             "Total records", icon = icon("database"), color = "blue")
  })
  
  output$vbox_clean <- renderValueBox({
    df <- results()
    n  <- if (is.null(df)) "\u2014" else
      sum(grepl("CLEAN", df$suspicion_level_final))
    valueBox(n, "Clean", icon = icon("check-circle"), color = "green")
  })
  
  output$vbox_suspect <- renderValueBox({
    df <- results()
    n  <- if (is.null(df)) "\u2014" else
      sum(grepl("INVESTIGATE|HIGH SUSPICION", df$suspicion_level_final))
    valueBox(n, "Investigate / Suspicious",
             icon = icon("exclamation-triangle"), color = "orange")
  })
  
  output$vbox_error <- renderValueBox({
    df <- results()
    n  <- if (is.null(df)) "\u2014" else
      sum(grepl("CLEAR ERROR", df$suspicion_level_final))
    valueBox(n, "Clear errors", icon = icon("times-circle"), color = "red")
  })
  
  # -------------------------------------------------------
  # MAP
  # -------------------------------------------------------
  
  filtered_map <- reactive({
    df <- results(); req(df)
    if (!"latitude" %in% names(df)) return(df)
    if (!is.null(input$map_filter)  && !"all" %in% input$map_filter) {
      df <- df %>% filter(suspicion_level_final %in% input$map_filter)
    }
    if (!is.null(input$map_country) && !"all" %in% input$map_country) {
      df <- df %>% filter(countryCode %in% input$map_country)
    }
    if (!is.null(input$map_lc) && !"all" %in% input$map_lc &&
        "lc_name" %in% names(df)) {
      df <- df %>% filter(lc_name %in% input$map_lc)
    }
    if (input$map_flagged_only) {
      df <- df %>% filter(n_flags > 0)
    }
    df
  })
  
  output$map <- renderLeaflet({
    df <- filtered_map(); req(df, "latitude" %in% names(df))
    
    pal_vals <- unique(df$suspicion_level_final)
    pal_cols <- suspicion_colours[pal_vals]
    pal_cols[is.na(pal_cols)] <- "#BDC3C7"
    pal <- colorFactor(palette = unname(pal_cols), domain = pal_vals)
    
    popup_text <- paste0(
      "<b>", df$species, "</b><br>",
      "Key: ", df$key, "<br>",
      "Year: ", df$year, "<br>",
      "Country: ", df$countryCode, "<br><br>",
      
      "<b>Land Cover:</b><br>",
      "Copernicus: ", ifelse(is.na(df$lc_name_cop), "No data", df$lc_name_cop), "<br>",
      "ESRI: ", ifelse(is.na(df$lc_name_esri), "No data", df$lc_name_esri), "<br>",
      "Final: ", ifelse(is.na(df$lc_name), "No data", df$lc_name), "<br>",
      "LC Status: ", ifelse(df$lc_agreement == TRUE, "✅ Agreed", 
                            ifelse(df$lc_agreement == FALSE, "ℹ️ ESRI-mapped", "Only one source")), "<br><br>",
      
      "<b>Validation Results:</b><br>",
      ifelse(df$flag_habitat == TRUE,
             paste0("<span style='color:red;font-weight:bold'>❌ Habitat: Unsuitable (",
                    coalesce(df$habitat_display, "Unknown"), ")</span><br>"),
             paste0("✅ Habitat: Suitable (", coalesce(df$habitat_display, "Unknown"), ")<br>")),
      
      ifelse(df$flag_embedding == 1, 
             paste0("<span style='color:red;font-weight:bold'>⚠️ Embedding: Outlier</span><br>"),
             paste0("✅ Embedding: Normal<br>")),
      
      ifelse(df$flag_climate_sdm == TRUE, 
             paste0("<span style='color:red;font-weight:bold'>⚠️ Climate: Low suitability (", ifelse(is.na(df$suitability_score), "—", round(df$suitability_score, 1)), ")</span><br>"),
             paste0("✅ Climate: Suitable (", ifelse(is.na(df$suitability_score), "—", round(df$suitability_score, 1)), ")<br>")),
      
      ifelse(df$in_iucn_range == TRUE, 
             "✅ IUCN Range: Inside<br>",
             paste0("<span style='color:red;font-weight:bold'>❌ IUCN Range: Outside</span><br>")),
      
      "<br><b>Overall: </b>",
      flag_icon(df$suspicion_level_final), " ",
      df$suspicion_level_final
    )
    
    m <- leaflet(df, options = leafletOptions(zoomControl = TRUE)) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      addCircleMarkers(
        lng = ~longitude, lat = ~latitude,
        radius = 6,
        color = ~pal(suspicion_level_final),
        fillOpacity = 0.8,
        stroke = TRUE,
        weight = 1,
        opacity = 0.5,
        popup = popup_text,
        popupOptions = popupOptions(maxWidth = 450, closeOnClick = TRUE),
        group = "Occurrence Points",
        layerId = ~key
      ) %>%
      addLegend(
        position = "bottomright", 
        pal = pal,
        values = ~suspicion_level_final,
        title = "Suspicion level", 
        opacity = 0.9,
        labFormat = labelFormat(prefix = "● ")
      )
    
    # Add IUCN Range layer
    if (!is.null(input$map_show_range) && isTRUE(input$map_show_range)) {
      if (!is.null(map_data$range_sf)) {
        tryCatch({
          range_plot <- map_data$range_sf
          if (!st_crs(range_plot) == st_crs(4326)) {
            range_plot <- st_transform(range_plot, 4326)
          }
          
          m <- m %>%
            addPolygons(
              data = range_plot,
              fillColor = "#2ECC71",
              fillOpacity = 0.15,
              weight = 2,
              color = "#2ECC71",
              opacity = 0.8,
              label = "IUCN Range",
              group = "IUCN Range",
              popup = if ("LEGEND" %in% names(range_plot)) {
                paste0("<b>IUCN Range</b><br>Status: ", range_plot$LEGEND)
              } else {
                "<b>IUCN Range</b>"
              },
              options = pathOptions(clickable = FALSE, pointerEvents = FALSE)
            )
        }, error = function(e) {
          # Silent fail
        })
      }
    }
    
    # Add SDM Prediction layer
    if (!is.null(input$map_show_sdm) && isTRUE(input$map_show_sdm)) {
      if (!is.null(map_data$sdm_rast)) {
        tryCatch({
          # Reproject to WGS84 and ensure correct alignment for leaflet
          sdm_proj <- tryCatch({
            r <- map_data$sdm_rast
            # If already WGS84, just resample to a clean grid to avoid misalignment
            if (!is.na(crs(r)) && grepl("4326", crs(r, describe=TRUE)$code)) {
              r
            } else {
              project(r, "EPSG:4326", method = "bilinear")
            }
          }, error = function(e) project(map_data$sdm_rast, "EPSG:4326", method = "bilinear"))
          
          if (!is.null(sdm_proj)) {
            sdm_vals <- values(sdm_proj, na.rm = TRUE)
            
            if (length(sdm_vals) > 0 && !all(is.na(sdm_vals))) {
              sdm_pal <- colorNumeric(
                palette = c("#E74C3C", "#F39C12", "#2ECC71"),
                domain = sdm_vals,
                na.color = "transparent"
              )
              
              m <- m %>%
                addRasterImage(
                  sdm_proj,
                  colors = sdm_pal,
                  opacity = 0.6,
                  group = "SDM Prediction",
                  project = TRUE
                ) %>%
                addLegend(
                  position = "bottomleft",
                  pal = sdm_pal,
                  values = sdm_vals,
                  title = "SDM Suitability",
                  opacity = 0.6,
                  labFormat = labelFormat(digits = 2)
                )
            }
          }
        }, error = function(e) {
          # Silent fail
        })
      }
    }
    
    m <- m %>%
      addLayersControl(
        overlayGroups = c("IUCN Range", "SDM Prediction"),
        options = layersControlOptions(collapsed = FALSE)
      ) %>%
      addScaleBar(position = "bottomleft")
    
    m
  })
  
  # -------------------------------------------------------
  # RESULTS TABLE - SUMMARY TABLE
  # -------------------------------------------------------
  
  filtered_tbl <- reactive({
    df <- results(); req(df)
    df <- df %>% filter(n_flags >= as.integer(input$tbl_flags))
    if (!is.null(input$tbl_filter) && !"all" %in% input$tbl_filter)
      df <- df %>% filter(suspicion_level_final %in% input$tbl_filter)
    df
  })
  
  output$results_table <- renderDT({
    df <- filtered_tbl(); req(df)
    
    summary_df <- df %>%
      mutate(
        copernicus_lc = as.character(coalesce(lc_name_cop, "Unknown")),
        esri_lc = as.character(coalesce(lc_name_esri, "Unknown")),
        final_lc = as.character(coalesce(lc_name_esri, "Unknown")),
        
        lc_status = case_when(
          lc_agreement == TRUE ~ "Agreed",
          lc_agreement == FALSE ~ "ESRI-mapped",
          is.na(lc_agreement) ~ "Only one source",
          TRUE ~ "Unknown"
        ),
        
        # USE habitat_display - already clean and processed!
        habitat_suitability_iucn = case_when(
          flag_habitat == TRUE ~ paste0("❌ ", coalesce(habitat_display, "Unknown")),
          flag_habitat == FALSE ~ paste0("✅ ", coalesce(habitat_display, "Unknown")),
          TRUE ~ paste0("❓ ", coalesce(habitat_display, "Unknown"))
        ),
        climate = case_when(
          flag_climate_sdm == TRUE ~ paste0("⚠️ ", round(suitability_score, 1)),
          TRUE ~ paste0("✅ ", round(suitability_score, 1))
        ),
        
        range_status = case_when(
          in_iucn_range == TRUE ~ "✅ Inside",
          in_iucn_range == FALSE ~ "❌ Outside",
          is.na(in_iucn_range) ~ "❓ Unknown",
          TRUE ~ "❓ Unknown"
        ),
        
        embedding = case_when(
          flag_embedding == 1 ~ "⚠️ Outlier",
          TRUE ~ "✅ Normal"
        )
      )
    
    summary_cols <- c(
      "n_flags",
      "species",
      "key",
      "year",
      "countryCode",
      "copernicus_lc",
      "esri_lc",
      "final_lc",
      "lc_status",
      "habitat_suitability_iucn",
      "climate",
      "range_status",
      "embedding"
    )
    
    summary_cols <- summary_cols[summary_cols %in% names(summary_df)]
    
    display_df <- summary_df[, summary_cols, drop = FALSE]
    
    # Simple conversion to character
    for (col in names(display_df)) {
      display_df[[col]] <- as.character(display_df[[col]])
      display_df[[col]][is.na(display_df[[col]])] <- "Unknown"
    }
    
    col_names <- c(
      "# Flags",
      "Species",
      "GBIF ID",
      "Year",
      "Country",
      "Copernicus LC",
      "ESRI LC",
      "Final LC",
      "LC Status",
      "Habitat Suitability",
      "Climate",
      "IUCN Range",
      "Embedding"
    )
    
    col_names <- col_names[1:length(summary_cols)]
    
    datatable(
      display_df,
      colnames = col_names,
      options = list(
        pageLength = 25,
        scrollX = TRUE,
        dom = 'Bfrtip',
        buttons = list(
          list(extend = 'copy', text = 'Copy', title = NULL),
          list(extend = 'csv', text = 'CSV', title = NULL, 
               exportOptions = list(modifier = list(page = 'all'))),
          list(extend = 'excel', text = 'Excel', title = NULL,
               exportOptions = list(modifier = list(page = 'all')))
        ),
        autoWidth = TRUE,
        columnDefs = list(
          list(targets = 0, className = 'dt-center', width = '30px'),
          list(targets = 1, width = '80px'),
          list(targets = 2, width = '60px'),
          list(targets = 3, width = '30px', className = 'dt-center'),
          list(targets = 4, width = '40px', className = 'dt-center'),
          list(targets = 5, width = '100px'),
          list(targets = 6, width = '80px'),
          list(targets = 7, width = '80px'),
          list(targets = 8, width = '60px'),
          list(targets = 9, width = '150px'),
          list(targets = 10, width = '50px'),
          list(targets = 11, width = '50px'),
          list(targets = 12, width = '50px')
        )
      ),
      extensions = 'Buttons',
      rownames = FALSE
    ) %>%
      formatStyle(
        "n_flags",
        backgroundColor = styleEqual(
          c(0, 1, 2, 3, 4, 5),
          c("#2ECC71", "#A9DFBF", "#F39C12", "#E67E22", "#E74C3C", "#C0392B")
        ),
        color = styleEqual(c(4, 5), c("white")),
        fontWeight = 'bold'
      ) %>%
      formatStyle(
        "lc_status",
        backgroundColor = styleEqual(
          c("Agreed", "ESRI-mapped", "Only one source"),
          c("#2ECC71", "#85C1E9", "#F8C471")
        ),
        fontWeight = 'bold'
      )
  })
  # -------------------------------------------------------
  # DASHBOARD PLOTS
  # -------------------------------------------------------
  
  output$plot_suspicion <- renderPlotly({
    df <- results(); req(df)
    counts <- df %>% count(suspicion_level_final) %>%
      arrange(desc(n)) %>%
      mutate(colour = suspicion_colours[suspicion_level_final])
    counts$colour[is.na(counts$colour)] <- "#BDC3C7"
    plot_ly(counts, x = ~n, y = ~reorder(suspicion_level_final, n),
            type = "bar", orientation = "h",
            marker = list(color = ~colour)) %>%
      layout(xaxis = list(title = "Number of points"),
             yaxis = list(title = ""), margin = list(l = 280))
  })
  
  output$plot_flags <- renderPlotly({
    df <- results(); req(df)
    flag_counts <- data.frame(
      Method = c("Unified Land Cover","Copernicus LC","ESRI LC",
                 "Embeddings","Climate SDM","Outside IUCN range"),
      Count  = c(
        if ("flag_habitat" %in% names(df)) sum(df$flag_habitat, na.rm=TRUE) else 0,
        if ("flag_habitat_cop" %in% names(df)) sum(df$flag_habitat_cop, na.rm=TRUE) else 0,
        if ("flag_habitat_esri" %in% names(df)) sum(df$flag_habitat_esri, na.rm=TRUE) else 0,
        if ("flag_embedding" %in% names(df)) sum(df$flag_embedding == 1, na.rm=TRUE) else 0,
        if ("flag_climate_sdm" %in% names(df)) sum(df$flag_climate_sdm, na.rm=TRUE) else 0,
        if ("in_iucn_range" %in% names(df)) sum(!df$in_iucn_range, na.rm=TRUE) else 0
      )
    )
    plot_ly(flag_counts, x = ~Method, y = ~Count, type = "bar",
            marker = list(color = c("#2ECC71","#E74C3C","#E67E22",
                                    "#F39C12","#3498DB","#8E44AD"))) %>%
      layout(xaxis = list(title = ""),
             yaxis = list(title = "Flagged points"))
  })
  
  output$plot_country <- renderPlotly({
    df <- results(); req(df, "countryCode" %in% names(df))
    flagged <- df %>% filter(n_flags > 0) %>%
      count(countryCode, sort = TRUE) %>% head(15)
    plot_ly(flagged, x = ~reorder(countryCode, n), y = ~n,
            type = "bar", marker = list(color = "#E74C3C")) %>%
      layout(xaxis = list(title = "Country"),
             yaxis = list(title = "Flagged points"))
  })
  
  output$plot_lc <- renderPlotly({
    df <- results(); req(df, "lc_name" %in% names(df))
    lc_counts <- df %>% count(lc_name, sort = TRUE) %>% head(15)
    plot_ly(lc_counts, x = ~n, y = ~reorder(lc_name, n),
            type = "bar", orientation = "h",
            marker = list(color = "#2ECC71")) %>%
      layout(xaxis = list(title = "Count"),
             yaxis = list(title = ""), margin = list(l = 200))
  })
  
  # Helper: donut pie with percentages in hover
  make_pie <- function(counts_df, palette_start) {
    counts_df <- counts_df %>%
      arrange(desc(n_pts)) %>%
      mutate(pct = round(100 * n_pts / sum(n_pts), 1),
             hover = paste0(label, "<br>", n_pts, " pts (", pct, "%)"))
    n     <- nrow(counts_df)
    pal   <- colorRampPalette(c(palette_start, "#ECF0F1"))(n)
    plot_ly(counts_df,
            labels  = ~label,
            values  = ~n_pts,
            type    = "pie",
            hole    = 0.4,
            text    = ~hover,
            hovertemplate = "%{text}<extra></extra>",
            textinfo      = "percent",
            marker  = list(colors = pal,
                           line   = list(color = "#ffffff", width = 1))) %>%
      layout(showlegend = TRUE,
             legend     = list(orientation = "v", x = 1, y = 0.5),
             margin     = list(l = 10, r = 10, t = 10, b = 10))
  }

  # Land cover counts
  lc_counts <- function(df) {
    df %>%
      filter(!is.na(lc_name_esri), lc_name_esri != "Unknown") %>%
      count(lc_name_esri, sort = TRUE) %>%
      rename(label = lc_name_esri, n_pts = n)
  }

  # Habitat counts — expand comma-separated habitat_display
  hab_counts <- function(df) {
    df %>%
      filter(!is.na(habitat_display), habitat_display != "Unknown") %>%
      mutate(hab_list = strsplit(as.character(habitat_display), ", ")) %>%
      tidyr::unnest(hab_list) %>%
      count(hab_list, sort = TRUE) %>%
      rename(label = hab_list, n_pts = n)
  }

  output$plot_clean_lc <- renderPlotly({
    df <- results(); req(df)
    d <- lc_counts(df %>% filter(n_flags == 0)); req(nrow(d) > 0)
    make_pie(d, "#2ECC71")
  })

  output$plot_flagged_lc <- renderPlotly({
    df <- results(); req(df)
    d <- lc_counts(df %>% filter(n_flags >= 2)); req(nrow(d) > 0)
    make_pie(d, "#E74C3C")
  })

  output$plot_clean_hab <- renderPlotly({
    df <- results(); req(df)
    d <- hab_counts(df %>% filter(n_flags == 0)); req(nrow(d) > 0)
    make_pie(d, "#27AE60")
  })

  output$plot_flagged_hab <- renderPlotly({
    df <- results(); req(df)
    d <- hab_counts(df %>% filter(n_flags >= 2)); req(nrow(d) > 0)
    make_pie(d, "#C0392B")
  })
  
  output$summary_table <- renderTable({
    df <- results(); req(df)
    data.frame(
      Metric = c("Total records","Clean (no flags)",
                 "Flagged by Unified LC","Flagged by embeddings","Flagged by climate SDM",
                 "Outside IUCN range","Flagged by 2+ methods","Clear errors",
                 "LC Agreements","LC Disagreements"),
      Count  = c(
        nrow(df),
        sum(df$n_flags == 0, na.rm = TRUE),
        if ("flag_habitat" %in% names(df)) sum(df$flag_habitat, na.rm=TRUE) else NA,
        if ("flag_embedding" %in% names(df)) sum(df$flag_embedding == 1, na.rm=TRUE) else NA,
        if ("flag_climate_sdm" %in% names(df)) sum(df$flag_climate_sdm, na.rm=TRUE) else NA,
        if ("in_iucn_range" %in% names(df)) sum(!df$in_iucn_range, na.rm=TRUE) else NA,
        sum(df$n_flags >= 2, na.rm = TRUE),
        sum(grepl("CLEAR ERROR", df$suspicion_level_final)),
        if ("lc_agreement" %in% names(df)) sum(df$lc_agreement == TRUE, na.rm=TRUE) else NA,
        if ("lc_agreement" %in% names(df)) sum(df$lc_agreement == FALSE, na.rm=TRUE) else NA
      )
    )
  })
  
  # -------------------------------------------------------
  # PCA PLOTS
  # -------------------------------------------------------
  
  output$pca_lc <- renderPlotly({
    pca <- pca_data(); req(pca)
    df  <- data.frame(PC1     = pca$scores[,1],
                      PC2     = pca$scores[,2],
                      lc_name = coalesce(pca$lc_names, "Unknown"))
    plot_ly(df, x = ~PC1, y = ~PC2, color = ~lc_name,
            type = "scatter", mode = "markers",
            marker = list(size = 5, opacity = 0.7)) %>%
      layout(title  = "PCA \u2014 Land Cover Classes",
             legend = list(title = list(text = "LC Class")))
  })
  
  output$pca_outliers <- renderPlotly({
    pca <- pca_data(); req(pca)
    
    df <- data.frame(
      PC1     = pca$scores[, 1],
      PC2     = pca$scores[, 2],
      outlier = factor(pca$outlier, levels = c(0, 1),
                       labels = c("Normal", "Outlier")),
      key     = pca$keys,
      stringsAsFactors = FALSE
    )
    
    # Join validation columns from merged results if available
    res <- results()
    if (!is.null(res) && "key" %in% names(res)) {
      hover_cols <- intersect(
        c("key","lc_name_esri","habitat_display","flag_habitat",
          "suitability_score","flag_climate_sdm","in_iucn_range"),
        names(res)
      )
      df <- df %>%
        left_join(res %>% dplyr::select(all_of(hover_cols)), by = "key")
    }
    
    # Build hover text
    df <- df %>% mutate(
      hover = paste0(
        "<b>", outlier, "</b><br>",
        "LC: ",      coalesce(lc_name_esri,   "—"), "<br>",
        "Habitat: ", coalesce(habitat_display, "—"), " — ", ifelse(
          !is.na(flag_habitat) & flag_habitat,
          "\u274c Unsuitable", "\u2705 Suitable"
        ), "<br>",
        "Climate: ", ifelse(
          !is.na(flag_climate_sdm) & flag_climate_sdm,
          paste0("\u26a0\ufe0f Low (", round(coalesce(suitability_score, NA_real_), 1), ")"),
          paste0("\u2705 Suitable (", round(coalesce(suitability_score, NA_real_), 1), ")")
        ), "<br>",
        "Range: ", case_when(
          !is.na(in_iucn_range) & in_iucn_range  ~ "\u2705 Inside",
          !is.na(in_iucn_range) & !in_iucn_range ~ "\u274c Outside",
          TRUE                                    ~ "\u2753 Unknown"
        )
      )
    )
    
    plot_ly(df, x = ~PC1, y = ~PC2,
            color  = ~outlier,
            colors = c("Normal" = "#95A5A6", "Outlier" = "#E74C3C"),
            text   = ~hover,
            hovertemplate = "%{text}<extra></extra>",
            type = "scatter", mode = "markers",
            marker = list(size = 5, opacity = 0.7)) %>%
      layout(title = "PCA \u2014 Embedding Outliers")
  })
  
  output$hist_scores <- renderPlotly({
    pca <- pca_data(); req(pca)
    plot_ly(x = ~pca$emb_scores, type = "histogram", nbinsx = 40,
            marker = list(color = "#3498DB",
                          line  = list(color = "white", width = 0.5))) %>%
      layout(title  = "Isolation Forest Score Distribution",
             xaxis  = list(title = "Anomaly score"),
             yaxis  = list(title = "Count"),
             shapes = list(list(
               type = "line",
               x0 = quantile(pca$emb_scores, 0.95),
               x1 = quantile(pca$emb_scores, 0.95),
               y0 = 0, y1 = 1, yref = "paper",
               line = list(color = "red", dash = "dash")
             )))
  })
  
  # -------------------------------------------------------
  # DOWNLOADS
  # -------------------------------------------------------
  
  output$download_full <- downloadHandler(
    filename = function()
      paste0(gsub(" ","_", input$species_name),
             "_full_validation_", Sys.Date(), ".csv"),
    content = function(file) {
      df <- results(); req(df)
      write.csv(df, file, row.names = FALSE)
    }
  )
  
  output$download_flagged <- downloadHandler(
    filename = function()
      paste0(gsub(" ","_", input$species_name),
             "_flagged_points_", Sys.Date(), ".csv"),
    content = function(file) {
      df <- results(); req(df)
      write.csv(df %>% filter(n_flags > 0), file, row.names = FALSE)
    }
  )
  
  output$download_clean <- downloadHandler(
    filename = function()
      paste0(gsub(" ","_", input$species_name),
             "_clean_points_", Sys.Date(), ".csv"),
    content = function(file) {
      df <- results(); req(df)
      write.csv(df %>% filter(n_flags == 0), file, row.names = FALSE)
    }
  )
  
  output$download_summary <- downloadHandler(
    filename = function()
      paste0(gsub(" ","_", input$species_name),
             "_summary_stats_", Sys.Date(), ".csv"),
    content = function(file) {
      df <- results(); req(df)
      
      summary_stats <- data.frame(
        Metric = c(
          "Species",
          "Total records",
          "Clean (no flags)",
          "Investigate",
          "High suspicion",
          "Clear errors",
          "Flagged by Unified LC",
          "Flagged by Copernicus LC",
          "Flagged by ESRI LC",
          "Flagged by embeddings",
          "Flagged by climate SDM",
          "Outside IUCN range",
          "Flagged by 2+ methods",
          "LC Agreements",
          "LC Disagreements"
        ),
        Value = c(
          input$species_name,
          nrow(df),
          sum(grepl("CLEAN", df$suspicion_level_final)),
          sum(grepl("INVESTIGATE", df$suspicion_level_final)),
          sum(grepl("HIGH SUSPICION", df$suspicion_level_final)),
          sum(grepl("CLEAR ERROR", df$suspicion_level_final)),
          if ("flag_habitat" %in% names(df)) sum(df$flag_habitat, na.rm=TRUE) else NA,
          if ("flag_habitat_cop" %in% names(df)) sum(df$flag_habitat_cop, na.rm=TRUE) else NA,
          if ("flag_habitat_esri" %in% names(df)) sum(df$flag_habitat_esri, na.rm=TRUE) else NA,
          if ("flag_embedding" %in% names(df)) sum(df$flag_embedding == 1, na.rm=TRUE) else NA,
          if ("flag_climate_sdm" %in% names(df)) sum(df$flag_climate_sdm, na.rm=TRUE) else NA,
          if ("in_iucn_range" %in% names(df)) sum(!df$in_iucn_range, na.rm=TRUE) else NA,
          sum(df$n_flags >= 2, na.rm = TRUE),
          if ("lc_agreement" %in% names(df)) sum(df$lc_agreement == TRUE, na.rm=TRUE) else NA,
          if ("lc_agreement" %in% names(df)) sum(df$lc_agreement == FALSE, na.rm=TRUE) else NA
        )
      )
      
      write.csv(summary_stats, file, row.names = FALSE)
    }
  )
  
} # end server

shinyApp(ui = ui, server = server)