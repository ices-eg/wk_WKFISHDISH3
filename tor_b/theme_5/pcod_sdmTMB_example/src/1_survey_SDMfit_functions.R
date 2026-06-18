
library(glue);library(sdmTMB);library(dplyr)
nm_conv <- 1/1852 # meters to nautical miles
nm2_conv <- 0.291553 # square km to nautical square miles conversion factor
trawl_width <- 11.7 # assumed trawl width for swept area

# Current year
current_year = as.integer(format(Sys.time(), '%Y'))

# This is a function to fit sdmTMB models. ####
# You can provide an id e.g. "bess","winter", to label the results.
# The second argument takes a dataframe, which needs to contain all the variables in the formula.
# The third argument takes a formula, used to fit the sdmTMB model.
# The fourth argument is for the prediction grid (see detailed instructions below function).
# The argument save to global can be set to TRUE in case you want a list with the output, but then you need to
# assign it, as in ' bess_model_output <- fit_sdm(...) '.

sdm_fit <- function(id = "fit1", df, first_year = 1900, last_year = 2100, meshcutoff = NA,
                    formula="", time_col_name = "startyear", offset_col_name = NULL, fam = tweedie(link="log"),  srf = "ar1", sp = "on",
                    time_varying = NULL, time_varying_type = "rw0", grid, gridcell_dist, save_to_global = TRUE,
                    out_index_only = FALSE, probObs = 1, fitted_model = NULL, calc_index = TRUE, 
                    se_fit_predict = FALSE, re_form_predict = NULL) {
  
  
  years <- first_year:last_year
  input <- df[df[[time_col_name]] %in% years, , drop = FALSE]
  
  if (probObs < 1) {
    input <- input %>% group_by(.data[[time_col_name]]) %>% slice_sample(prop = probObs) %>%
      ungroup() %>% droplevels()
  } 
  
  if (is.null(offset_col_name)){
    offset_var <- NULL
  } else {
    offset_var <- log(input[[offset_col_name]])
  }
  
  if (is.null(fitted_model)){
    # Create mesh
    mesh <- make_mesh(input, xy_cols = c("xkm", "ykm"), cutoff = meshcutoff)
    
    # Fit sdmTMB model
    fit <- sdmTMB(
      formula = formula,
      data = input,
      offset = offset_var,
      mesh = mesh,
      family= fam,
      spatial=sp,
      spatiotemporal=srf,
      time_varying = time_varying,
      time_varying_type = time_varying_type,
      time=time_col_name,
      control=sdmTMBcontrol(eval.max=5000,iter.max=4000,nlminb_loops = 3))
    
  } else {
    fit <- fitted_model
  }
  
  
  predgrid <- grid[grid[[time_col_name]] %in% years, , drop = FALSE]  %>%
    droplevels()
  
  if (is.null(offset_col_name)){
    offset_preds <- NULL
  } else{
    offset_preds <- rep(mean(offset_var), nrow(predgrid))
  }
  
  # Step 3: Predict on predgrid
  preds <- predict(fit, return_tmb_object = TRUE,
                   offset = offset_preds,
                   newdata = predgrid,
                   se_fit = se_fit_predict,
                   re_form = re_form_predict)
  
  area_size = gridcell_dist^2*nm2_conv
  # Step 4: Calculate index
  index <- list()
  if (calc_index){
    
    index <- get_index(preds, area = area_size, bias_correct = TRUE)
    
    index <- index %>% mutate(index=est/mean(est),
                              indexCIl=lwr/mean(est),
                              indexCIh=upr/mean(est),
                              index_type="tot_grid_biomass",
                              model_name=id,
                              log_lwr=log(lwr),
                              log_upr=log(upr),
                              biomass=est/(trawl_width*nm_conv),
                              biomassCIl=lwr/(trawl_width*nm_conv),
                              biomassCIh=upr/(trawl_width*nm_conv),
                              years=paste0(min(startyear),"-",max(startyear)),
                              max_year=max(startyear),
                              fmax_year=as.factor(max_year),
                              probObs=probObs,
                              formula=paste(deparse(fit$formula), collapse = ""),
                              registrations=nrow(input),
                              meshn=fit$spde$mesh$n,
                              meshcutoff=meshcutoff,
                              srf=paste(as.character(fit$spatiotemporal), collapse = ";"),
                              sp=paste(as.character(fit$spatial), collapse = ";"),
                              AIC=AIC(fit))
  }
  
  # Step 5: Collect results
  if(out_index_only==FALSE) {
    output <- list(input = input, model = fit, preds = preds, index = index)
  } else {
    output <- index
  }
  
  # Step 6: Name with ID suffix and assign it to global environment
  if(save_to_global==FALSE) {
    return(output)
  } else {
    assign(id, fit, envir = .GlobalEnv)
    assign(paste0("preds_",id), preds, envir = .GlobalEnv)
    assign(paste0("index_", id), index, envir = .GlobalEnv)
  }

}


# Combined survey function #####

# This function is basically the same as fit_sdm, but in the sdmTMB configuration it 
# includes a spatially varying effect for fSeries, so remember to add that to your data.
# fSeries will be a factor variable with SS/WS.
# This function will yield two sets of predictions and indices, one for Summer and one
# for winter.
sdm_fit_comb <- function(id = "fit1", df, first_year = 1900, last_year = 2100, meshcutoff = 60,
                    formula, offset_col_name = "", fam = tweedie(link="log"),  srf = "ar1", sp = "on",
                    time_varying = NULL, time_varying_type = "rw0", grid, gridcell_dist, save_to_global = TRUE,
                    out_index_only = FALSE, probObs = 1) {
  
  years <- first_year:last_year
  input <- df %>% filter(startyear %in% years)
  
  if (probObs < 1) {
    input <- input %>% group_by(fYear, fSeries) %>% slice_sample(prop = probObs) %>%
      ungroup() %>% droplevels()
  } 
  # Create mesh
  mesh <- make_mesh(input, xy_cols = c("xkm", "ykm"), cutoff = meshcutoff)
  
  offset_var <- log(input[[offset_col_name]])
  
  
  # Fit sdmTMB model
  fit <- sdmTMB(
    formula = formula,
    data = input,
    offset = offset_var,
    mesh = mesh,
    family= fam,
    spatial=sp,
    spatiotemporal=srf,
    time="startyear",
    time_varying = time_varying,
    time_varying_type = time_varying_type,
    spatial_varying = ~fSeries,
    control=sdmTMBcontrol(eval.max=5000,iter.max=4000,nlminb_loops = 3))
  
  # offset calc
  offset_preds <- mean(offset_var)
  
  # Create predgrids for summer and winter
  predgrid_ss <- grid %>%
    mutate(Series = "SS",
           fSeries = as.factor(Series)) %>% filter(
             startyear %in% years) %>%
    droplevels()
  
  predgrid_ws <- grid %>%
    mutate(Series = "WS",
           fSeries = as.factor(Series))%>% filter(
             startyear %in% years) %>%
    droplevels()
  
  # Predict
  preds_ss <- predict(fit, return_tmb_object = TRUE,
                      offset = rep(offset_preds, nrow(predgrid_ss)),
                      newdata = predgrid_ss 
                      )
  preds_ws <- predict(fit, return_tmb_object = TRUE,
                      offset = rep(offset_preds, nrow(predgrid_ws)),
                      newdata = predgrid_ws 
                      )
  
  # Calculate indices
  area_size = gridcell_dist^2*nm2_conv
  index_ss <- get_index(preds_ss, area = area_size, bias_correct = TRUE)
  index_ss <- index_ss %>% mutate(index=est/mean(est),
                                  indexCIl=lwr/mean(est),
                                  indexCIh=upr/mean(est),
                                  index_type="tot_grid_biomass",
                                  model_name=id,
                                  log_lwr=log(lwr),
                                  log_upr=log(upr),
                                  biomass=est/(trawl_width*nm_conv),
                                  biomassCIl=lwr/(trawl_width*nm_conv),biomassCIh=upr/(trawl_width*nm_conv),
                                  Series = "Summer",
                                  years=paste0(min(startyear),"-",max(startyear)),
                                  max_year=max(startyear),
                                  fmax_year=as.factor(max_year),
                                  probObs=probObs,
                                  formula=as.character(formula)[3],
                                  registrations=nrow(input),
                                  meshn=mesh$mesh$n,
                                  meshcutoff=meshcutoff,
                                  srf=srf,
                                  sp=sp,
                                  AIC=AIC(fit))
  
  index_ws <- get_index(preds_ws, area = area_size, bias_correct = TRUE)
  index_ws <- index_ws %>% mutate(index=est/mean(est),
                                  indexCIl=lwr/mean(est),
                                  indexCIh=upr/mean(est),
                                  index_type="tot_grid_biomass",
                                  model_name=id,
                                  log_lwr=log(lwr),
                                  log_upr=log(upr),
                                  biomass=est/(trawl_width*nm_conv),
                                  biomassCIl=lwr/(trawl_width*nm_conv),biomassCIh=upr/(trawl_width*nm_conv),
                                  Series = "Winter",
                                  years=paste0(min(startyear),"-",max(startyear)),
                                  max_year=max(startyear),
                                  fmax_year=as.factor(max_year),
                                  probObs=probObs,
                                  formula=as.character(formula)[3],
                                  registrations=nrow(input),
                                  meshn=mesh$mesh$n,
                                  meshcutoff=meshcutoff,
                                  srf=srf,
                                  sp=sp,
                                  AIC=AIC(fit))
  
  index <- bind_rows(index_ss, index_ws) %>% 
    mutate(indexComb=est/mean(est),
           indexCombCIl=lwr/mean(est),
           indexCombCIh=upr/mean(est),)
  
  # Step 5: Collect results
  if(out_index_only==FALSE) {
    output <- list(input = df, mesh = mesh, model = fit, preds_ss = preds_ss, 
                   preds_ws = preds_ws, index = index)
  } else {
    output <- index
  }
  
  # Step 6: Name with ID suffix and assign it to global environment
  if(save_to_global==FALSE) {
    return(output)
  } else {
    assign(id, fit, envir = .GlobalEnv)
    assign(paste0("preds_ss_", id), preds_ss, envir = .GlobalEnv)
    assign(paste0("preds_ws_", id), preds_ws, envir = .GlobalEnv)
    assign(paste0("index_", id), index, envir = .GlobalEnv)
    assign(paste0("mesh_", id), mesh, envir = .GlobalEnv)
  }
  
}

# Cross validation function ####

cross_validate_sdmTMB <- function(model_files, model_names, df,
                                  offset_cn = NULL, meshcutoff,
                                  clust, cv_results_loc) {
  
  ms_n <- model_names
  
  ms <- setNames(
    lapply(model_files, function(m) {
      e <- new.env()
      nm <- load_object(m)
      nm
    }),
    ms_n
  )
  
  if (!is.null(offset_cn)){
    df$offset <- log(df[[offset_cn]])
  } else {
    df$offset <- NULL
  }
  
  mesh_cv <- make_mesh(df, xy_cols = c("xkm", "ykm"), cutoff = meshcutoff)
  
  results <- lapply(seq_along(ms), function(i) {
    m <- ms[[i]]
    name <- ms_n[[i]]
    
    out <- tryCatch({
      cv_m <- sdmTMB_cv(
        formula = m$formula[[1]],
        data = df,
        mesh = mesh_cv,
        offset = "offset",
        fold_ids = clust,
        k_folds = length(unique(clust)),
        spatiotemporal = as.list(m$spatiotemporal),
        family = m$family,
        spatial = as.list(m$spatial),
        time = m$time,
        time_varying = m$time_varying,
        spatial_varying = m$spatial_varying,
        parallel = FALSE,
        control = sdmTMBcontrol(eval.max = 5000, iter.max = 4000, nlminb_loops = 3)
      )
      
      cv_m$models <- lapply(cv_m$models, AIC)
      
      list(success = TRUE, result = cv_m, name = name)
      
    }, error = function(e) {
      message(sprintf("Model '%s' FAILED: %s", name, e$message))
      list(success = FALSE, result = NULL, name = name)
    })
    
    if (out$success) {
      message(sprintf("Model '%s' ran successfully.", name))
    }
    
    out
  })
  
  # Identify successful models
  success_idx <- which(vapply(results, function(x) x$success, logical(1)))
  
  # Trim objects
  ms <- ms[success_idx]
  ms_n <- ms_n[success_idx]
  
  # Extract cv objects and name them
  cv_objs <- setNames(
    lapply(results[success_idx], function(x) x$result),
    ms_n
  )
  
  if (!is.null(cv_results_loc)){
    saveRDS(cv_objs, file = cv_results_loc)
  }
  
  cat("Successful models:\n")
  print(ms_n)
  
  failed_names <- vapply(results[!vapply(results, `[[`, logical(1), "success")], `[[`, character(1), "name")
  cat("Failed models:\n")
  print(failed_names)
  
}


