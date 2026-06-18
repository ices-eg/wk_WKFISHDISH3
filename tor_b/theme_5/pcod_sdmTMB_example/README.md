# pcod sdmTMB Modelling Workflow

## Overview

This script implements a full modelling and reporting workflow for survey-based density data (`pcod`) using the `sdmTMB` framework. It:

- Prepares and formats survey data
- Generates prediction grids
- Fits a sequence of spatial and spatiotemporal models
- Saves fitted models and predictions
- Produces automated Quarto reports for diagnostics and outputs
- Performs model comparison using cross-validation:
  - Random CV
  - Spatial CV
  - Spatiotemporal CV

---

## ⚠️ IMPORTANT: Working Directory Requirement

This script **must be run from the local folder it is contained in**, *not from the root of the Git repository*.

The script relies on **relative paths**, such as:

    src/
    _data/
    _saved_models/
    Reports/

If you run it from another location (e.g. repo root), it may:
- Fail to find source files in `src/`
- Save outputs in incorrect locations
- Break report generation

✅ Correct usage example:

    setwd("path/to/this/script/folder")
    source("your_script_name.R")

---

## Dependencies


### Core packages (required)

- tidyverse (includes dplyr, tidyr, ggplot2, readr, etc.)
- sf
- sdmTMB
- RANN
- blockCV
- quarto
- mgcv
- glmmTMB
- splines

---

### Supporting packages (used in plotting, reporting, or utilities)

- ggpubr
- gridExtra
- ggforce
- stringr
- lubridate
- data.table
- ggspatial
- ggOceanMaps *(installed from GitHub)*
- knitr
- kableExtra
- bookdown
- readxl
- devtools

The script also depends on helper files located in `src/`:

- 0_shrimp_setup.R
- Variogram_function.R
- 1_survey_SDMfit_functions.R
- additional_quarto_funcs.R

### ⚠️ IMPORTANT: Some other packages might be called internally from scripts located in the src/ and quarto templates folders.

---

## Project Structure

The script creates and uses the following directory structure:

    src/                    # Helper scripts and Quarto templates
    _data/                  # Processed data and grids
    _saved_models/          # Fitted model objects
    _saved_preds/           # Predictions (if generated)
    _saved_cvs/             # Cross-validation results
    Reports/
      └── pcod/
            ├── Models/     # Model diagnostics reports
            ├── Preds/      # Prediction reports
            └── Compare/    # Model comparison reports

---

## Workflow Description

### 1. Data Preparation
- Reformats the `pcod` dataset
- Saves the processed dataset to:

    _data/pcod_model_input.rda

---

### 2. Grid Construction
- Builds a spatial prediction grid (`base_grid`)
- Converts coordinates to WGS84
- Saves to `_data/`

---

### 3. Model Fitting

Three models are fitted:

| Model ID | Description |
|----------|------------|
| 003 | Non-spatial Tweedie model with polynomial depth |
| 004 | Spatial model (adds spatial random field) |
| 005 | Spatiotemporal model (adds IID temporal effects) |

Each model:
- Uses formula: density ~ poly(log(depth), 2)
- Is fitted with sdmTMB
- Is saved in `_saved_models/`

---

### 4. Reporting

For each model:
- A diagnostic report (DHARMa residual checks)
- A prediction report

Reports are generated with Quarto and stored in:

    Reports/pcod/
      Models/
      Preds/

---

### 5. Model Comparison (Cross-Validation)

Three strategies are used:

#### Random CV
- Random assignment of folds

#### Spatial CV
- Spatial blocking using blockCV
- Approximate block size: 20 km

#### Spatiotemporal CV
- Combines spatial blocks with year-based grouping

Outputs:
- Saved CV objects (_saved_cvs/)
- Reports in:

    Reports/pcod/Compare/

---

## Key Functions Used

- sdm_fit() → wrapper for model fitting and prediction
- cross_validate_sdmTMB() → model evaluation
- quarto_render() → report generation
- replicate_df() → builds prediction grids across years

---

## Outputs

The script produces:

- Processed datasets (_data/)
- Prediction grids (.rds)
- Model objects (_saved_models/)
- Cross-validation results (_saved_cvs/)
- HTML reports (Reports/)

---

## Notes and Best Practices

- Run the script in a clean R session
- Ensure all required packages are installed
- Do not modify folder structure unless updating paths
- Avoid committing large intermediate files unless necessary
- Always pull latest repo changes before running (if working collaboratively)

---

## Author Notes

This workflow is designed to be reproducible but depends on:

- A consistent folder structure
- Correct working directory
- Availability of helper scripts in src/

---


