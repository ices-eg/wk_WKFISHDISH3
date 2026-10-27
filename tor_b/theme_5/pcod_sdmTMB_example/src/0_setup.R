

#Load required packages
packages <- c("tidyverse","sf","lubridate", "quarto", "sp",
              "mapdata","marmap","mapplots","gridExtra","ggforce","stringr",
              "bookdown","dplyr", "tidyr", "ggpubr",
              "readxl","devtools","mgcv","glmmTMB","data.table",
              "ggOceanMaps","ggspatial",
              "knitr", "kableExtra","splines", "sdmTMB",
              # Model diagnostics and spatial checks
              "DHARMa","blockCV","automap","gstat","RANN",
              # Tweedie simulation and residuals
              "tweedie","statmod",
              # Helpers used in scripts and Quarto templates
              "glue","rlang","scales","gt","inlabru","rstudioapi")

# Install missing packages
missing_packages <- packages[!packages %in% rownames(installed.packages())]
if ("ggOceanMaps" %in% missing_packages) {
  devtools::install_github("MikkoVihtakari/ggOceanMaps")
  missing_packages <- setdiff(missing_packages, "ggOceanMaps")
}
if (length(missing_packages) > 0) {
  install.packages(missing_packages)
}
sapply(packages, require, character.only = TRUE)
