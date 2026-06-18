load_object <- function(model_file) {
  ext <- tools::file_ext(model_file)
  
  if (ext == "rds") {
    # .rds returns the object directly
    return(readRDS(model_file))
  }
  
  if (ext == "rda" || ext == "RData") {
    # .rda loads an object into the environment and returns the name(s)
    obj_name <- load(model_file)        # returns character vector of object names
    if (length(obj_name) != 1) {
      stop(".rda file must contain exactly one object for this loader.")
    }
    return(get(obj_name))
  }
  
  stop("Unsupported file type: ", ext)
}

library(tweedie)


# FINAL correct wrapper for mgcViz Tweedie simulation
rTweedie <- function(mu, w, sig, p = NULL, ..., phi = NULL) {
  
  # mgcViz sends 'sig' as phi (dispersion)
  if (is.null(phi)) phi <- sig
  
  # mgcViz should pass 'p', but if not, try to retrieve it
  if (is.null(p)) {
    # Look for p in the parent frame (mgcViz family environment)
    if (exists("p", inherits = TRUE)) {
      p <- get("p", inherits = TRUE)
    } else {
      stop("Cannot find Tweedie p parameter")
    }
  }
  
  # Number of samples = length(mu)
  n <- length(mu)
  
  # generate values
  tweedie::rtweedie(
    n     = n,
    mu    = mu,
    phi   = phi,
    power = p
  )
}

sdm_plot_response_distribution <- function(resids,
                                           n_sample  = 5000,
                                           log_trans = TRUE,
                                           theme     = report_theme) {
  
  sims <- resids$simulatedResponse
  obs  <- resids$observedResponse
  
  if (is.null(dim(sims))) stop("simulatedResponse has no dimensions")
  if (nrow(sims) == length(obs)) sims_mat <- t(sims) else sims_mat <- sims
  
  # sample from simulated values to keep plotting lightweight
  total_sims <- length(sims_mat)
  n_sample   <- min(n_sample, total_sims)
  set.seed(2026)
  samp_idx <- sample.int(total_sims, n_sample)
  sim_vals <- as.numeric(sims_mat)[samp_idx]
  
  df_obs <- data.frame(value = obs,      type = "Observed")
  df_sim <- data.frame(value = sim_vals, type = "Simulated")
  df_all <- dplyr::bind_rows(df_obs, df_sim)
  
  # apply log1p so zeros are retained and the long tail is visible
  if (log_trans) {
    df_all  <- dplyr::mutate(df_all, value = log1p(value))
    # pretty breaks expressed on the original scale
    raw_breaks <- c(0, 1, 5, 10, 50, 100, 500, 1000, 5000)
    x_scale <- ggplot2::scale_x_continuous(
      name   = "Catch weight (original scale)",
      breaks = log1p(raw_breaks),
      labels = raw_breaks
    )
  } else {
    x_scale <- ggplot2::scale_x_continuous(name = "Response (catch weight)")
  }
  
  fill_vals <- c("Observed" = "grey40", "Simulated" = "steelblue")
  
  # density of positive values
  p_pos <- ggplot2::ggplot(
    dplyr::filter(df_all, value > 0),
    ggplot2::aes(x = value, fill = type)
  ) +
    ggplot2::geom_density(alpha = 0.4, adjust = 1, linewidth = 0.4) +
    x_scale +
    ggplot2::scale_y_continuous(name = "Density") +
    ggplot2::scale_fill_manual(values = fill_vals) +
    ggplot2::labs(
      title    = "Observed vs simulated: positive values",
      subtitle = if (log_trans) "spacing: log(1 + x), labels: original scale" else NULL,
      fill     = ""
    ) +
    theme
  
  p_pos
}


sdm_plot_ecdf_distribution <- function(resids,
                                       df = NULL,
                                       year_variable = NULL,
                                       by_year       = FALSE,
                                       n_sim_lines   = 250,
                                       show_sim_lines = TRUE,
                                       show_envelope  = F,
                                       log_trans     = TRUE,
                                       theme         = report_theme) {
  
  library(ggplot2)
  library(dplyr)
  library(rlang)
  
  sims <- resids$simulatedResponse
  obs  <- resids$observedResponse
  
  if (is.null(dim(sims))) stop("simulatedResponse has no dimensions")
  
  # Ensure sims are [n_sims x n_obs]
  if (nrow(sims) == length(obs)) sims_mat <- t(sims) else sims_mat <- sims
  
  n_sims <- nrow(sims_mat)
  n_obs  <- length(obs)
  
  # Observed dataframe
  df_obs <- data.frame(value = obs)
  
  if (by_year) {
    if (is.null(df) || is.null(year_variable)) {
      stop("Provide df and year_variable when by_year = TRUE")
    }
    df_obs[[year_variable]] <- df[[year_variable]]
    year_sym <- sym(year_variable)
  }
  
  # Define common x grid (critical for envelope)
  x_grid <- sort(unique(c(obs, as.numeric(sims_mat))))
  
  # Keep grid manageable
  if (length(x_grid) > 500) {
    x_grid <- quantile(x_grid, probs = seq(0, 1, length.out = 500))
  }
  
  # --- Compute ECDF for each simulation ---
  ecdf_mat <- sapply(seq_len(n_sims), function(i) {
    ecdf_fun <- ecdf(sims_mat[i, ])
    ecdf_fun(x_grid)
  })
  
  # --- Envelope ---
  if (show_envelope) {
    lower <- apply(ecdf_mat, 1, quantile, probs = 0.025, na.rm = TRUE)
    upper <- apply(ecdf_mat, 1, quantile, probs = 0.975, na.rm = TRUE)
    
    df_env <- data.frame(
      x = x_grid,
      lower = lower,
      upper = upper
    )
  }
  
  # --- Sample simulation lines ---
  if (show_sim_lines) {
    sim_idx <- sample(seq_len(n_sims), min(n_sim_lines, n_sims))
    
    df_sim_lines <- do.call(rbind, lapply(sim_idx, function(i) {
      data.frame(
        x = x_grid,
        ecdf = ecdf_mat[, i],
        sim_id = i
      )
    }))
  }
  
  # Axis scale
  if (log_trans) {
    raw_breaks <- c(0, 1, 5, 10, 50, 100, 500, 1000, 5000)
    x_scale <- scale_x_continuous(
      trans  = "log1p",
      breaks = raw_breaks,
      labels = raw_breaks,
      name   = "Response (log1p scale)"
    )
  } else {
    x_scale <- scale_x_continuous(name = "Response")
  }
  
  # --- Plot ---
  p <- ggplot()
  
  # Envelope ribbon
  if (show_envelope) {
    p <- p +
      geom_ribbon(
        data = df_env,
        aes(x = x, ymin = lower, ymax = upper),
        fill = "steelblue",
        alpha = 0.25
      )
  }
  
  # Simulation ECDF lines
  if (show_sim_lines) {
    p <- p +
      geom_line(
        data = df_sim_lines,
        aes(x = x, y = ecdf, group = sim_id),
        color = "steelblue",
        alpha = 0.2,
        linewidth = 0.6
      )
  }
  
  # Observed ECDF by year
  if (by_year) {
    p <- p +
      stat_ecdf(
        data = df_obs,
        aes(x = value, group = !!year_sym),
        color = "grey60",
        alpha = 0.5,
        size = 0.6
      )
  }
  
  # Overall observed ECDF
  p <- p +
    stat_ecdf(
      data = df_obs,
      aes(x = value),
      color = "black",
      size = 1.2
    )
  
  # Final styling
  p <- p +
    x_scale +
    labs(
      y     = "F(x)",
      title = "Posterior predictive ECDF check",
      subtitle = "Black = observed | Blue = DHARMa simulations"
    ) +
    theme
  
  return(p)
}


# Tweedie variance model comparison ####

tweedie_variance_comp <- function(model_names, model_files) {
  
  library(statmod)
  library(ggplot2)
  library(dplyr)
  library(purrr)
  
  # Load models
  ms <- setNames(
    lapply(model_files, function(m) {
      e <- new.env()
      nm <- load_object(m)
      nm
    }),
    model_names
  )
  
  # Means to evaluate
  means <- c(0.5, 20, 50, 100)
  
  # Extract parameters for subtitle
  param_df <- map_dfr(names(ms), function(model_name) {
    
    model <- ms[[model_name]]
    pars <- model$model$par
    
    phi <- exp(pars["ln_phi"])
    p   <- 1 + plogis(pars["thetaf"])
    
    data.frame(
      model = model_name,
      phi = phi,
      p = p
    )
  })
  
  # Build subtitle text
  subtitle_text <- param_df %>%
    mutate(txt = sprintf("%s: phi = %.2f, p = %.2f", model, phi, p)) %>%
    pull(txt) %>%
    paste(collapse = "  \n")
  
  # Build data
  plot_data <- map_dfr(names(ms), function(model_name) {
    
    model <- ms[[model_name]]
    pars <- model$model$par
    
    phi <- exp(pars["ln_phi"])
    p   <- 1 + plogis(pars["thetaf"])
    
    # log-spaced x grid
    x <- exp(seq(log(1e-4), log(max(means) * 3), length.out = 400))
    
    map_dfr(means, function(mu) {
      
      cdf <- ptweedie(x, mu = mu, phi = phi, power = p)
      
      data.frame(
        x = x,
        cdf = cdf,
        mean = factor(mu, levels = means),
        model = model_name
      )
    })
  })
  
  # Plot
  p_cdf <- ggplot(plot_data, aes(x = x, y = cdf, color = model)) +
    geom_line(size = 1) +
    facet_wrap(~ mean, scales = "free") +
    scale_x_continuous(trans = "log1p") +
    labs(
      x = "Response (log scale)",
      y = "CDF",
      color = "Model",
      title = "Tweedie cumulative distribution comparison",
      subtitle = subtitle_text
    ) +
    theme_minimal() +
    theme(legend.position = "top")
  
  return(p_cdf)
}

# Tweedie variance and ecdf comparison ####

tweedie_variance_ecdf_comp <- function(model_names, model_files,
                                  df, response_variable,
                                  year_variable = "startyear") {
  
  library(statmod)
  library(ggplot2)
  library(dplyr)
  library(purrr)
  library(rlang)
  
  # NSE helpers
  response_var <- sym(response_variable)
  year_var     <- sym(year_variable)
  
  # Load models
  ms <- setNames(
    lapply(model_files, function(m) {
      e <- new.env()
      nm <- load_object(m)
      nm
    }),
    model_names
  )
  
  # Compute overall mean
  mu <- mean(df[[response_variable]], na.rm = TRUE)
  
  # Extract model parameters
  param_df <- map_dfr(names(ms), function(model_name) {
    
    model <- ms[[model_name]]
    pars  <- model$model$par
    
    phi <- exp(pars["ln_phi"])
    p   <- 1 + plogis(pars["thetaf"])
    
    data.frame(
      model = model_name,
      phi = phi,
      p = p
    )
  })
  
  # Subtitle text
  subtitle_text <- param_df %>%
    mutate(txt = sprintf("%s: phi = %.2f, p = %.2f", model, phi, p)) %>%
    pull(txt) %>%
    paste(collapse = "  \n")
  
  # Build x grid
  x <- exp(seq(
    log(1e-4),
    log(max(df[[response_variable]], na.rm = TRUE) * 3),
    length.out = 400
  ))
  
  # Model CDF data
  plot_model <- map_dfr(names(ms), function(model_name) {
    
    model <- ms[[model_name]]
    pars  <- model$model$par
    
    phi <- exp(pars["ln_phi"])
    p   <- 1 + plogis(pars["thetaf"])
    
    cdf <- ptweedie(x, mu = mu, phi = phi, power = p)
    
    data.frame(
      x = x,
      cdf = cdf,
      model = model_name
    )
  })
  
  # Plot
  p <- ggplot() +
    
    # ECDF by year (grey)
    stat_ecdf(
      data = df,
      aes(x = !!response_var, group = !!year_var),
      color = "grey60",
      alpha = 0.5,
      size = 0.6
    ) +
    
    # Overall ECDF (black)
    stat_ecdf(
      data = df,
      aes(x = !!response_var),
      color = "black",
      size = 1
    ) +
    
    # Tweedie model CDFs
    geom_line(
      data = plot_model,
      aes(x = x, y = cdf, color = model),
      size = 1.1
    ) +
    
    scale_x_continuous(trans = "log1p") +
    
    coord_cartesian(
      xlim = c(0, max(df[[response_variable]], na.rm = TRUE))
    ) +
    
    labs(
      x = paste0(response_variable, " (log1p scale)"),
      y = "F(x)",
      color = "Model",
      title = "Empirical vs Tweedie CDF comparison",
      subtitle = paste0(
        "Mean used: ", round(mu, 2), "\n",
        subtitle_text
      )
    ) +
    
    theme_minimal() +
    theme(legend.position = "top")
  
  return(p)
}
