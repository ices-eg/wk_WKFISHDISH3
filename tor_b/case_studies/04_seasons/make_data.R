#####################
## Case study 04: Seasonal migrations
#####################

## Tobias Mildenberger <tobm@dtu.dk> and Casper Berg <cabe@dtu.dk>
## June 2026


## remotes::install_github("tokami/DATRASextra@dev")
require(DATRASextra) ## v0.2.0


## specify data path
data_dir <- "~/Documents/data/makeData/DATRAS"
fig_dir <- "figs"
dir.create(fig_dir)


## years
years <- 2022:2025


## surveys with beam trawl gears
surveys <- c("NS-IBTS")


## GOV
gears <- c("GOV")


##
quarters <- c(1, 3)


## download / read-in data
## dat0 <- download_datras(surveys = surveys,
##                         years = years,
##                         path = data_dir)

dat0 <- read_datras(path = data_dir,
                    surveys = surveys,
                    years = years)


## keep only relevant info
table(dat0$Gear, dat0$Quarter)
dat <- subset(dat0, Gear %in% gears &
                      Quarter %in% quarters)


## select horse mackerel
dat <- subset(dat, Valid_Aphia == "126822") ## Trachurus trachurus

## prune
dat <- prune_datras(dat)


## clean up data (impute missing depth later for speed-up)
dat <- clean_datras(dat, impute_missing_depth = FALSE)

## calculate swept area
dat <- add_swept_area(dat)

## add numbers at length
dat <- add_numbers_at_length(dat)


png(file.path(fig_dir, "fig01.png"),
    width = 900, height = 800, res = 120, bg = "white")
plot_length_distribution(dat)
dev.off()

## add weight at length (use ca and lookup a,b as backup)
dat <- add_weight_at_length(dat, lookup_as_backup = TRUE)

length_cuts <- c(0, 22.9, Inf)

## add total numbers and weight by haul
dat <- add_total_numbers_by_haul(dat, length_cuts = length_cuts)
dat <- add_total_weight_by_haul(dat, length_cuts = length_cuts)

png(file.path(fig_dir, "fig02.png"),
    width = 1200, height = 1000, res = 120, bg = "white")
plot_datras_overview(dat,
                     metric = "mean",
                     value_var = "HaulN",
                     transform = "sqrt",
                     fixed_scale = FALSE,
                     positive_only = TRUE,
                     by_quarter = TRUE,
                     multi_panels = TRUE)
dev.off()


## calculate cog by length group and quarter
indicators <- calc_spatial_indicators(dat, by = "Quarter")


png(file.path(fig_dir, "fig03.png"),
    width = 800, height = 1000, res = 120, bg = "white")
plot_spatial_indicators(indicators)
dev.off()


## save data set
hh <- as_table(dat)

char_cols <- sapply(hh, is.character)
hh[char_cols] <- lapply(hh[char_cols], factor)

hh$lat <- round(hh$lat, 3)
hh$lon <- round(hh$lon, 3)

utils::object.size(hh) / 1e3

saveRDS(hh, file = "04_seasons.rds", compress = "xz")



## for readme

dat

vars <- colnames(hh)
for(i in seq_along(vars)){
  if (i == 1) {
    cat("| Variable | Unit | Description |\n")
    cat("|----------|------|-------------|\n")
  }
  cat("|", vars[i], "| | |\n")
}

head(hh, 10)
