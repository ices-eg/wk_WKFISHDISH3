#' Set working directory to tor_b/theme_5/pcod_sdmTMB_example
# setwd("path/to/this/script/folder")
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
#' Automatic if running from local project root (not wk_WKFISHDISH3 root)

#' Indicate location of the src folder containing quarto templates
#' and helper functions
src_folder_location <- "src/"

source(paste0(src_folder_location, "0_shrimp_setup.R"))
source(paste0(src_folder_location, "Variogram_function.R"))
source(paste0(src_folder_location, "1_survey_SDMfit_functions.R"))
source(paste0(src_folder_location, "additional_quarto_funcs.R"))

# Create data and reports folders to keep things tidy

dir.create("_data")
dir.create("_saved_models")
dir.create("_saved_preds")
dir.create("_saved_cvs")
dir.create("Reports")

# Access and save pcod ####
pcod <- pcod %>%
  mutate(
    fYear = factor(year),
    startyear = year, # Matching pcod column names with their expected column names in quarto templates
    WeightNM = density,
    latitudestart = lat,
    longitudestart = lon,
    serialnumber = row_number(),
    xkm = X,
    ykm = Y
  )

save(pcod, file = "_data/pcod_model_input.rda")

# Load Data pcod ####
data_input_file <- "_data/pcod_model_input.rda"
from_wd_to_reports <- "Reports"
from_wd_to_qmd_reports_templates <- paste0(
  src_folder_location,
  "qmd_reports_templates/"
)
data_name <- "pcod" # Data tag that will be carried over report names and titles

dir.create(file.path(from_wd_to_reports, data_name))

# Create folders to keep Reports organized

dir.create(file.path(from_wd_to_reports, data_name, "Models"))
dir.create(file.path(from_wd_to_reports, data_name, "Preds"))
dir.create(file.path(from_wd_to_reports, data_name, "Compare"))

load(data_input_file)
df_surv <- pcod # The generic name for the input (survey) data is df_surv
model_covariates <- list("fYear", "depth", "depth_scaled", "depth_scaled2")


# Moving on to the spatial approach calculations ####

# First let me calculate the mean distance between adjacent stations to inform mesh cutoff properly

library(RANN)

years <- unique(df_surv$startyear)

mean_nn2_dists <- data.frame(startyear = years, mu_nn2 = 0, sd_nn2 = 0)

for (i in seq(years)) {
  yr <- years[i]
  df <- subset(df_surv, startyear == yr)
  coords <- as.matrix(df[, c("xkm", "ykm")])
  nn <- nn2(coords, k = 2)
  nearest_distances <- nn$nn.dists[, 2]
  mean_nn2_dists[i, "mu_nn2"] <- mean(nearest_distances)
  mean_nn2_dists[i, "sd_nn2"] <- sd(nearest_distances)
}

View(mean_nn2_dists)

# Lets go for 10 km (Above mu + 1 sd in every year, and in line with sdmtmb vignette)

#' We also need a prediction grid, in this case its provided also in the package,
#' so no need to build it ourselves

zone <- floor((mean(df_surv$longitudestart) + 180) / 6) + 1
utmCRS <- paste("+proj=utm +zone=", zone, " ellps=WGS84 +units=km", sep = '')

grid_dist <- 2

base_grid <- qcs_grid %>%
  rename(
    xkm = X,
    ykm = Y
  ) %>%
  st_as_sf(
    coords = c("xkm", "ykm"), # columns with coordinates
    crs = utmCRS,
    remove = FALSE # keep original columns
  ) %>%
  st_transform(crs = 4326)

coords_4326 <- as.data.frame(st_coordinates(base_grid))

base_grid <- base_grid %>%
  mutate(
    lon = coords_4326$X,
    lat = coords_4326$Y
  )

base_grid_name <- "pcod_base_grid_"
saveRDS(
  base_grid,
  file = paste0("_data/", base_grid_name, grid_dist, "_km.rds")
)

#' Lets fit a model with tweedie family and depth as a polynomial,
#' but without spatial structure

# 003 tweedie with poly depth (intro vignette) ####

model_name <- "003_mod_tw_polydepth"

grid_dist <- 2
base_grid <- readRDS(paste0("_data/", base_grid_name, grid_dist, "_km.rds"))

# Prepare predgrid
predgrid <- replicate_df(base_grid, "startyear", unique(df_surv$startyear)) %>%
  mutate(fYear = as.factor(startyear)) %>%
  st_drop_geometry()

#' Wrapper function to fit sdmtmb, predict and obtain index

sdm_fit(
  id = model_name,
  df = df_surv,
  meshcutoff = 10,
  formula = density ~ poly(log(depth), 2),
  offset_col_name = NULL,
  fam = tweedie(link = "log"),
  srf = "off",
  sp = "off",
  grid = predgrid,
  gridcell_dist = grid_dist
)

# Save and assign model
saveRDS(
  get(model_name),
  file = paste0("_saved_models/", data_name, "_", model_name, ".rds")
)
assign(
  paste0(data_name, "_", model_name),
  readRDS(paste0("_saved_models/", data_name, "_", model_name, ".rds"))
)

# Model Report and Diagnostics
model_full_name <- paste0(data_name, "_", model_name)
current_wd <- getwd()
out_dir_report <- file.path(
  current_wd,
  from_wd_to_reports,
  data_name,
  "/Models/",
  model_full_name
)

quarto_render(
  input = paste0(from_wd_to_qmd_reports_templates, "DHARMa_report.qmd"),
  execute_dir = current_wd,
  execute_params = list(
    model_name = model_full_name,
    m_file = paste0("_saved_models/", model_full_name, ".rds"),
    m_description = "sdmTMB but no sp no srf tweedie density as a function of poly depth",
    m_input_data_file = data_input_file,
    m_pos_covariates = model_covariates,
    save_dharma_residuals = F,
    run_gam_chunk = F
  ),
  metadata = list(
    title = model_full_name
  ),
  output_file = paste0(
    model_full_name,
    ".html"
  ),
  quarto_args = c("--output-dir", out_dir_report)
)


# Quarto render predictions report
model_full_name <- paste0(data_name, "_", model_name)
current_wd <- getwd()
out_dir_report <- file.path(
  current_wd,
  from_wd_to_reports,
  data_name,
  "/Preds/",
  model_full_name
)

grid_dist <- 2

quarto_render(
  input = paste0(
    from_wd_to_qmd_reports_templates,
    "Predictions_sdmTMB_report.qmd"
  ),
  execute_dir = current_wd,
  execute_params = list(
    model_name = model_full_name,
    m_file = paste0("_saved_models/", model_full_name, ".rds"),
    m_input_data_file = data_input_file,
    predgrid_file = paste0("_data/", base_grid_name, grid_dist, "_km.rds"),
    gridcell_dist = grid_dist,
    factor_covariates = NULL,
    numeric_covariates = list("depth" = mean(df_surv$depth))
  ),
  metadata = list(
    title = model_full_name
  ),
  output_file = paste0(
    model_full_name,
    ".html"
  ),
  quarto_args = c("--output-dir", out_dir_report)
)

#' Now we add a spatial effect (same across years)

# 004 tweedie with poly depth and sp ####

model_name <- "004_fit_sp_tw_polydepth"

grid_dist <- 2
base_grid <- readRDS(paste0("_data/", base_grid_name, grid_dist, "_km.rds"))

# Prepare predgrid
predgrid <- replicate_df(base_grid, "startyear", unique(df_surv$startyear)) %>%
  mutate(fYear = as.factor(startyear)) %>%
  st_drop_geometry()

sdm_fit(
  id = model_name,
  df = df_surv,
  meshcutoff = 10,
  formula = density ~ poly(log(depth), 2),
  offset_col_name = NULL,
  fam = tweedie(link = "log"),
  srf = "off",
  sp = "on",
  grid = predgrid,
  gridcell_dist = grid_dist
)

# Save and assign model
saveRDS(
  get(model_name),
  file = paste0("_saved_models/", data_name, "_", model_name, ".rds")
)
assign(
  paste0(data_name, "_", model_name),
  readRDS(paste0("_saved_models/", data_name, "_", model_name, ".rds"))
)

# Model Report and Diagnostics
model_full_name <- paste0(data_name, "_", model_name)
current_wd <- getwd()
out_dir_report <- file.path(
  current_wd,
  from_wd_to_reports,
  data_name,
  "/Models/",
  model_full_name
)

quarto_render(
  input = paste0(from_wd_to_qmd_reports_templates, "DHARMa_report.qmd"),
  execute_dir = current_wd,
  execute_params = list(
    model_name = model_full_name,
    m_file = paste0("_saved_models/", model_full_name, ".rds"),
    m_description = "sdmTMB with sp no srf tweedie density as a function of poly depth",
    m_input_data_file = data_input_file,
    m_pos_covariates = model_covariates,
    save_dharma_residuals = F,
    run_gam_chunk = F,
    run_sdmtmb_selftest_chunk = T,
    selftest_nsims = 10,
    meshcutoff = 10
  ),
  metadata = list(
    title = model_full_name
  ),
  output_file = paste0(
    model_full_name,
    ".html"
  ),
  quarto_args = c("--output-dir", out_dir_report)
)

# Quarto render predictions report
model_full_name <- paste0(data_name, "_", model_name)
current_wd <- getwd()
out_dir_report <- file.path(
  current_wd,
  from_wd_to_reports,
  data_name,
  "/Preds/",
  model_full_name
)

grid_dist <- 2

quarto_render(
  input = paste0(
    from_wd_to_qmd_reports_templates,
    "Predictions_sdmTMB_report.qmd"
  ),
  execute_dir = current_wd,
  execute_params = list(
    model_name = model_full_name,
    m_file = paste0("_saved_models/", model_full_name, ".rds"),
    m_input_data_file = data_input_file,
    predgrid_file = paste0("_data/", base_grid_name, grid_dist, "_km.rds"),
    gridcell_dist = grid_dist,
    factor_covariates = NULL,
    numeric_covariates = list("depth" = mean(df_surv$depth))
  ),
  metadata = list(
    title = model_full_name
  ),
  output_file = paste0(
    model_full_name,
    ".html"
  ),
  quarto_args = c("--output-dir", out_dir_report)
)

#' Now lets also add spatiotemporal effects on top of the spatial

# 005 tweedie with poly depth and sp and srf iid (sdmtmb intro vignette second part) ####

model_name <- "005_fit_sp_srf_iid_tw_polydepth"

grid_dist <- 2
base_grid <- readRDS(paste0("_data/", base_grid_name, grid_dist, "_km.rds"))

# Prepare predgrid
predgrid <- replicate_df(base_grid, "startyear", unique(df_surv$startyear)) %>%
  mutate(fYear = as.factor(startyear)) %>%
  st_drop_geometry()

sdm_fit(
  id = model_name,
  df = df_surv,
  meshcutoff = 10,
  formula = density ~ poly(log(depth), 2),
  offset_col_name = NULL,
  fam = tweedie(link = "log"),
  srf = "iid",
  sp = "on",
  grid = predgrid,
  gridcell_dist = grid_dist
)

# Save and assign model
saveRDS(
  get(model_name),
  file = paste0("_saved_models/", data_name, "_", model_name, ".rds")
)
assign(
  paste0(data_name, "_", model_name),
  readRDS(paste0("_saved_models/", data_name, "_", model_name, ".rds"))
)

# Model Report and Diagnostics
model_full_name <- paste0(data_name, "_", model_name)
current_wd <- getwd()
out_dir_report <- file.path(
  current_wd,
  from_wd_to_reports,
  data_name,
  "/Models/",
  model_full_name
)

quarto_render(
  input = paste0(from_wd_to_qmd_reports_templates, "DHARMa_report.qmd"),
  execute_dir = current_wd,
  execute_params = list(
    model_name = model_full_name,
    m_file = paste0("_saved_models/", model_full_name, ".rds"),
    m_description = "sdmTMB with sp srf iid tweedie density as a function of poly depth",
    m_input_data_file = data_input_file,
    m_pos_covariates = model_covariates,
    save_dharma_residuals = F,
    run_gam_chunk = F
  ),
  metadata = list(
    title = model_full_name
  ),
  output_file = paste0(
    model_full_name,
    ".html"
  ),
  quarto_args = c("--output-dir", out_dir_report)
)

# Quarto render predictions report
model_full_name <- paste0(data_name, "_", model_name)
current_wd <- getwd()
out_dir_report <- file.path(
  current_wd,
  from_wd_to_reports,
  data_name,
  "/Preds/",
  model_full_name
)

grid_dist <- 2

quarto_render(
  input = paste0(
    from_wd_to_qmd_reports_templates,
    "Predictions_sdmTMB_report.qmd"
  ),
  execute_dir = current_wd,
  execute_params = list(
    model_name = model_full_name,
    m_file = paste0("_saved_models/", model_full_name, ".rds"),
    m_input_data_file = data_input_file,
    predgrid_file = paste0("_data/", base_grid_name, grid_dist, "_km.rds"),
    gridcell_dist = grid_dist,
    factor_covariates = NULL,
    numeric_covariates = list("depth" = mean(df_surv$depth))
  ),
  metadata = list(
    title = model_full_name
  ),
  output_file = paste0(
    model_full_name,
    ".html"
  ),
  quarto_args = c("--output-dir", out_dir_report)
)

# sdmTMB models comparison AIC and CV ####

# Random clustering ####

clust <- sample(1:10, size = nrow(df_surv), replace = TRUE)

model_paths <- list.files(
  path = "_saved_models",
  pattern = "^pcod_(003|004|005)",
  full.names = TRUE
)
model_paths

model_names <- c("tw_0_3", "tw_sp_4", "tw_iid_5")

cv_objs_path <- "_saved_cvs/cv_objs_rand_345.rds"

cross_validate_sdmTMB(
  model_files = model_paths,
  model_names = model_names,
  df = df_surv,
  offset_cn = NULL,
  meshcutoff = 10,
  clust = clust,
  cv_results_loc = cv_objs_path
)

current_wd <- getwd()
comp_report_name <- "CV_rand_3_4_5"
comp_report_description <- "CV results pcod models 3, 4, 5."
out_dir_report <- file.path(
  current_wd,
  from_wd_to_reports,
  data_name,
  "Compare",
  comp_report_name
)
dir.create(out_dir_report)

quarto_render(
  input = paste0(
    from_wd_to_qmd_reports_templates,
    "Comp_sdmTMB_models_report.qmd"
  ),
  execute_dir = current_wd,
  execute_params = list(
    description = comp_report_description,
    model_files = model_paths,
    cv_objs_file = cv_objs_path,
    m_input_data_file = data_input_file,
    response_variable = "density",
    cluster_vector = clust,
    save_location = "_data/cv_df_cv_rand_345.rds"
  ),
  metadata = list(
    title = comp_report_name
  ),
  output_file = paste0(
    comp_report_name,
    ".html"
  ),
  quarto_args = c("--output-dir", out_dir_report)
)

# Spatial blocking ####
library(blockCV)

zone <- floor((mean(df_surv$longitudestart) + 180) / 6) + 1
utmCRSm <- paste("+proj=utm +zone=", zone, " ellps=WGS84 +units=m", sep = '')

sf_surv_m <- st_as_sf(
  df_surv,
  coords = c("longitudestart", "latitudestart"),
  crs = 4326
) %>%
  st_transform(utmCRSm)

# Lets use matern range iid model 5 estimate of 20 km as block square length

spatial_folds <- cv_spatial(
  x = sf_surv_m, # numeric column in sf_data to assess autocorrelation
  size = 20000, # clustering distance in map units (e.g. meters if UTM)
  k = 10, # number of folds
  hexagon = FALSE, # TRUE if you want hexagonal tiling
  seed = 123,
  progress = TRUE,
  plot = TRUE # to visualize clusters
)

clust_sp <- spatial_folds$folds_ids

cv_objs_path <- "_saved_cvs/cv_objs_sp_345.rds"

cross_validate_sdmTMB(
  model_files = model_paths,
  model_names = model_names,
  df = df_surv,
  offset_cn = NULL,
  meshcutoff = 10,
  clust = clust_sp,
  cv_results_loc = cv_objs_path
)

current_wd <- getwd()
comp_report_name <- "SP_CV_3_4_5"
comp_report_description <- "Spatial CV 20km results pcod models 3, 4, 5."
out_dir_report <- file.path(
  current_wd,
  from_wd_to_reports,
  data_name,
  "Compare",
  comp_report_name
)
dir.create(out_dir_report)

quarto_render(
  input = paste0(
    from_wd_to_qmd_reports_templates,
    "Comp_sdmTMB_models_report.qmd"
  ),
  execute_dir = current_wd,
  execute_params = list(
    description = comp_report_description,
    model_files = model_paths,
    cv_objs_file = cv_objs_path,
    m_input_data_file = data_input_file,
    response_variable = "density",
    cluster_vector = clust_sp,
    save_location = "_data/cv_df_cv_sp_345.rds"
  ),
  metadata = list(
    title = comp_report_name
  ),
  output_file = paste0(
    comp_report_name,
    ".html"
  ),
  quarto_args = c("--output-dir", out_dir_report)
)

# Spatiotemporal CV ####

# Building from cv_spatial:

sf_surv_m2 <- st_join(sf_surv_m, spatial_folds$blocks)

table(sf_surv_m2$block_id, useNA = "ifany")


df_clusters <- sf_surv_m2 %>%
  dplyr::distinct(startyear, block_id) %>%
  dplyr::group_by(startyear) %>%
  dplyr::mutate(
    fold_st = sample(rep(1:10, length.out = n()))
  ) %>%
  dplyr::ungroup()

sf_surv_m3 <- sf_surv_m2 %>%
  dplyr::left_join(df_clusters, by = c("startyear", "block_id"))

# Optional: check balance
print(table(sf_surv_m3$startyear, sf_surv_m3$fold_st))
sf_surv_m3 %>% group_by(fold_st) %>% summarise(n = n()) %>% st_drop_geometry()

clust_st <- sf_surv_m3$fold_st

cv_objs_path <- "_saved_cvs/cv_objs_st_345.rds"

cross_validate_sdmTMB(
  model_files = model_paths,
  model_names = model_names,
  df = df_surv,
  offset_cn = NULL,
  meshcutoff = 10,
  clust = clust_st,
  cv_results_loc = cv_objs_path
)

current_wd <- getwd()
comp_report_name <- "ST_CV_3_4_5"
comp_report_description <- "Spatiotemporal CV 20km results pcod models 3, 4, 5."
out_dir_report <- file.path(
  current_wd,
  from_wd_to_reports,
  data_name,
  "Compare",
  comp_report_name
)
dir.create(out_dir_report)

quarto_render(
  input = paste0(
    from_wd_to_qmd_reports_templates,
    "Comp_sdmTMB_models_report.qmd"
  ),
  execute_dir = current_wd,
  execute_params = list(
    description = comp_report_description,
    model_files = model_paths,
    cv_objs_file = cv_objs_path,
    m_input_data_file = data_input_file,
    response_variable = "density",
    cluster_vector = clust_st,
    save_location = "_data/cv_df_cv_st_345.rds"
  ),
  metadata = list(
    title = comp_report_name
  ),
  output_file = paste0(
    comp_report_name,
    ".html"
  ),
  quarto_args = c("--output-dir", out_dir_report)
)
