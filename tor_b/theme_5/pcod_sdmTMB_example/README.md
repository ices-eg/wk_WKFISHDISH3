# pcod sdmTMB Modelling Workflow

## Main product: the DHARMa diagnostics report

The main product of this folder is the Quarto template
[`src/qmd_reports_templates/DHARMa_report.qmd`](src/qmd_reports_templates/DHARMa_report.qmd).
It is a **parameterised, general-purpose model diagnostics report** that anyone can
use with their own fitted model and survey data. The `pcod` workflow below is only
an example of how to call it.

Given a saved model and the survey data it was fitted to, the report produces:

- A report summary (model, data, description, number of simulations)
- Input validation, with clear errors if required objects or columns are missing
- Model summary and conventional residual checks
- DHARMa simulation-based diagnostics: example observations, a "Turing test"
  (can you spot the observed data among simulated datasets?), simulated vs
  observed means and distributions, QQ, dispersion, outlier and homoscedasticity
  tests, zero inflation, and residuals vs fitted values and vs covariates
- Spatial diagnostics: residual maps by year, Moran's I, yearly and combined
  variograms, estimated ranges (optional)
- Additional checks: GAM check and an sdmTMB self-test (both optional)

### What you need to use it with your own model

1. A fitted model saved as `.rds` (or `.rda` / `.RData`), loaded with `load_object()`.
   `sdmTMB` models use `dharma_residuals()`; any other model class is passed to
   `DHARMa::simulateResiduals()` (for example `glmmTMB`).
2. The survey data as a saved file (`m_input_data_file`) with at least these
   columns: `startyear`, `serialnumber`, `latitudestart`, `longitudestart`.
3. The helper scripts `additional_quarto_funcs.R` and `Variogram_function.R`,
   in the folder given by the `src_folder` parameter.

### Calling the report

```r
quarto::quarto_render(
  input = "src/qmd_reports_templates/DHARMa_report.qmd",
  execute_dir = getwd(),   # the report runs from here, see src_folder below
  execute_params = list(
    model_name = "my_model",
    m_file = "_saved_models/my_model.rds",
    m_description = "Short description of the model",
    m_input_data_file = "_data/my_data.rda",
    m_pos_covariates = list("depth", "fYear")
  ),
  output_file = "my_model_DHARMa.html"
)
```

### Report parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `model_name` | `NULL` | Name shown in the report |
| `m_file` | `NULL` | Path to the saved model |
| `m_description` | `NULL` | Free-text model description |
| `m_input_data_file` | `NULL` | Path to the survey data |
| `m_pos_covariates` | `NULL` | Covariates to plot residuals against |
| `n_simulations` | `250` | Number of DHARMa simulations |
| `run_spatial_chunks` | `true` | Run the spatial diagnostics section |
| `save_dharma_residuals` | `false` | Save the DHARMa residuals next to the model |
| `save_dharma_simulations` | `false` | Save the DHARMa simulations next to the model |
| `run_gam_chunk` | `false` | Run the GAM check |
| `run_sdmtmb_selftest_chunk` | `false` | Run the sdmTMB self-test |
| `selftest_nsims` | `10` | Number of simulations for the self-test |
| `meshcutoff` | `10` | Mesh cutoff used by the self-test |
| `src_folder` | `"src/"` | Folder with the helper scripts (see below) |

### `src_folder` and the working directory

The report loads its helper scripts with `source()` from `src_folder`. That path is
**relative to the render's working directory (`execute_dir`), not to the `.qmd` file**.
The default `"src/"` works when you render from this folder, as the `pcod` workflow
does. If you render from somewhere else, pass the path explicitly, including the
trailing slash:

```r
execute_params = list(
  ...,
  src_folder = "../src/"
)
```

---

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

- 0_setup.R (loads, and installs if missing, all required packages)
- Variogram_function.R
- 1_survey_SDMfit_functions.R
- additional_quarto_funcs.R

`additional_quarto_funcs.R` and `Variogram_function.R` are also required by
`DHARMa_report.qmd` (see `src_folder` above).

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


