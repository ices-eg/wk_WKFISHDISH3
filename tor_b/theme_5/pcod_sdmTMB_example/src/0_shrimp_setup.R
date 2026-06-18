

#Load required packages
packages <- c("tidyverse","sf","lubridate", "quarto", "sp",
              "mapdata","marmap","mapplots","gridExtra","ggforce","stringr",
              "bookdown","dplyr", "tidyr", "ggpubr",
              "readxl","devtools","mgcv","glmmTMB","data.table",
              "ggOceanMaps","ggspatial",
              "knitr", "kableExtra","splines", "quarto", "sdmTMB")

# Install missing packages
installed_packages <- packages %in% rownames(installed.packages())
if (any(installed_packages == FALSE)) {
  if ("ggOceanMaps" %in% packages[!installed_packages]) {
      devtools::install_github("MikkoVihtakari/ggOceanMaps")
  } else {
    install.packages(packages[!installed_packages])
  }
}
sapply(packages, require, character.only = TRUE)

