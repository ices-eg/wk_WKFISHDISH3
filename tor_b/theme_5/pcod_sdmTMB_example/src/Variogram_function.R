# Morans I to check for spatial autocorrelation in residuals
# First check that there are no duplicate locations within
# each year

check_res_spat_autocor <- function(sf_data, res_col = "dres", year_col = "startyear", 
                                   x_col = "xkm", y_col = "ykm", only_df = TRUE){
  
  spat_res_autocor_df <- data.frame(startyear = 0,
                                    obs_MorI = 0,
                                    exp_MorI = 0,
                                    exp_sd = 0,
                                    p_val = 0)
  
  yrs <- sort(unique(sf_data[[year_col]]))
  
  if (only_df){
    for (i in seq_len(length(yrs))){
      yr <- yrs[i]
      sf_data.yr <- sf_data %>% filter(.data[[year_col]] == yr)
      res <- testSpatialAutocorrelation(sf_data.yr[[res_col]], 
                                        x = sf_data.yr[[x_col]], 
                                        y = sf_data.yr[[y_col]],
                                        plot = F)
      print(paste0(yr))
      print(res)
      vec_yr <- c(yr, round(res$statistic[1], 3), round(res$statistic[2], 3), 
                  round(res$statistic[3], 3), round(res$p.value, 3))
      spat_res_autocor_df[i,] <- vec_yr
      
    }
  } else {
    for (i in seq_len(length(yrs))){
      yr <- yrs[i]
      sf_data.yr <- sf_data %>% filter(.data[[year_col]] == yr)
      res <- testSpatialAutocorrelation(sf_data.yr[[res_col]], 
                                        x = sf_data.yr[[x_col]], 
                                        y = sf_data.yr[[y_col]],
                                        plot = T)
      print(paste0(yr))
      print(res)
      vec_yr <- c(yr, round(res$statistic[1], 3), round(res$statistic[2], 3), 
                  round(res$statistic[3], 3), round(res$p.value, 3))
      spat_res_autocor_df[i,] <- vec_yr
      
    }
  }
  
  return(spat_res_autocor_df)
}



# Exp and autofit variogram to check for spatial correlation
library(dplyr)
library(automap)
library(ggplot2)
library(gstat)
library(sp)

fit_autovars <- function(sf_data, response_column){
  
  stopifnot("startyear" %in% names(sf_data))
  yrs <- sort(unique(sf_data$startyear))
  plots <- vector("list", length(yrs))
  names(plots) <- as.character(yrs)
  
  exp_vars_df <- data.frame(dist = numeric(),
                            gamma = numeric(),
                            startyear = numeric())
  
  fit_vars_df <- data.frame(dist = numeric(),
                            gamma = numeric(),
                            startyear = numeric())
  
  ranges_vars_df <- data.frame(model = character(),
                               psill = numeric(),
                               range = numeric(),
                               startyear = numeric())
  
  for (yr in yrs){
    df <- dplyr::filter(sf_data, startyear == yr)
    
    formula_avg <- as.formula(paste(response_column, "~1"))
    auto_vgm <- autofitVariogram(formula_avg, df)
    
    vgm_exp   <- auto_vgm$exp_var %>% select(dist, gamma) %>% # experimental variogram (data.frame)
      mutate(startyear = yr)
    
    exp_vars_df <- bind_rows(exp_vars_df, vgm_exp)
    
    vgm_model <- auto_vgm$var_model 
    
    # Create a distance grid over the range of the experimental variogram
    dseq <- seq(
      from = min(vgm_exp$dist, na.rm = TRUE),
      to   = max(vgm_exp$dist, na.rm = TRUE),
      length.out = 200
    )
    
    # Generate the fitted model line as a data.frame with columns 'dist' and 'gamma'
    vgm_line <- gstat::variogramLine(vgm_model, dist_vector = dseq) %>%
      mutate(startyear = yr)
    
    fit_vars_df <- bind_rows(fit_vars_df, vgm_line)
    
    var_model_df <- vgm_model %>% select(model, psill, range) %>% # experimental variogram (data.frame)
      mutate(startyear = yr)
    
    ranges_vars_df <- bind_rows(ranges_vars_df, var_model_df)
    
    p <- (plot(auto_vgm))
    plots[[as.character(yr)]] <- p
  }
  return(list(plots, exp_vars_df, fit_vars_df, ranges_vars_df))
}

plot_autovars <- function(fit_autovars_output_list){
  for (p in fit_autovars_output_list){
    yr <- names(fit_autovars_output_list)[sapply(fit_autovars_output_list, identical, p)]
    p_up <- update(p, main = paste0(yr, " experimental and fitted variograms"))
    plot(p_up)
  }
}


# Function to determine extent of spatial correlation, used to find
# block distances for spatial cv. Use only once we strongly
# suspect of spatial correlation (it breaks if the variogram doesnt fit)
library(dplyr)
library(ggplot2)
library(blockCV)

fit_var_cv <- function(sf_data_m, response_column, plot = FALSE){
  
  df <- sf_data_m
  year <- unique(df$startyear)
  
  sacm <- cv_spatial_autocor(x = df,
                             column = response_column,
                             plot = plot)
  
  exp_var <- sacm[["variograms"]][[1]][["exp_var"]]
  var_model <- sacm[["variograms"]][[1]][["var_model"]]
  
  # Extract relevant values
  nug <- var_model$psill[var_model$model == "Nug"]
  psill <- var_model$psill[var_model$model == "Ste"]
  range <- var_model$range[var_model$model == "Ste"]
  
  # Only build ggplot if requested
  if(plot) {
    
    # If Ste component is missing, set psill and range to 0/NA
    if(length(psill) == 0) psill <- 0
    if(length(range) == 0) range <- NA
    
    # Matern function is complicated; for visualization, we can approximate
    # here with an exponential variogram model (common and similar):
    
    dist_seq <- exp_var$dist
    if (!is.na(range)) {
      fitted_gamma <- nug + psill * (1 - exp(-dist_seq / range))
    } else {
      fitted_gamma <- rep(NA_real_, length(dist_seq))
    }
    
    # Compute fitted gamma safely
    if(length(fitted_gamma) != length(dist_seq) || all(is.na(fitted_gamma))) {
      fitted_df <- data.frame(dist = dist_seq, gamma = NA_real_)
    } else {
      fitted_df <- data.frame(dist = dist_seq, gamma = fitted_gamma)
    }
    
    # Plot
    sv_plot <- ggplot() +
      geom_point(data = exp_var, aes(x = dist, y = gamma), color = "blue") +
      geom_line(data = fitted_df %>% filter(!is.na(gamma)), 
                aes(x = dist, y = gamma), color = "red", linewidth = 1) +
      labs(x = "Distance (m)", y = "Semi-variance",
           title = paste0("Experimental (blue) and Fitted (red) Variogram ", year)) +
      theme_minimal()
    
    output <- list(year = year,
                   n_points = nrow(df),
                   exp_var = exp_var, 
                   var_model = var_model, 
                   nug = nug, 
                   psill = psill, 
                   range = range, 
                   fitted_df = fitted_df, 
                   sv_plot = sv_plot)
  }
  else{
    output <- list(year = year,
                   n_points = nrow(df),
                   exp_var = exp_var, 
                   var_model = var_model, 
                   nug = nug, 
                   psill = psill, 
                   range = range)
  }
  
  return(output)
}


