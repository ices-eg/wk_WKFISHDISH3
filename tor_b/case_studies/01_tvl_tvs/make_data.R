#####################
## Case study 01: What is the relationship between TVL and TVS gears?
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
years <- 1999:2024


## surveys with beam trawl gears
surveys <- c("BITS")


## beam trawls
gears <- c("TVS", "TVL")


## download / read-in data
## dat0 <- download_datras(surveys = surveys,
##                         years = years,
##                         path = data_dir)

dat0 <- read_datras(path = data_dir,
                    surveys = surveys,
                    years = years)


## keep only the two gears
table(dat0$Gear, dat0$Year)
dat <- subset(dat0, Gear %in% gears)


## some plots
png(file.path(fig_dir, "fig01.png"),
    width = 1100, height = 900, res = 120, bg = "white")
plot_datras_overview(dat,
                     by_gear = TRUE,
                     multi_panels = TRUE)
dev.off()

png(file.path(fig_dir, "fig02.png"),
    width = 1100, height = 900, res = 120, bg = "white")
plot_datras_overview(dat,
                     metric = "count_hauls",
                     mode = "grid",
                     by_gear = TRUE,
                     multi_panels = TRUE)
dev.off()


## select plaice
dat <- subset(dat, Valid_Aphia == "127143") ## Pleuronectes platessa


## prune
dat <- prune_datras(dat)


## clean up data (impute missing depth later for speed-up)
dat <- clean_datras(dat, impute_missing_depth = FALSE)


## calculate swept area
dat <- add_swept_area(dat)


## add numbers at length
dat <- add_numbers_at_length(dat)


plot_length_distribution(dat)


## add weight at length (use ca and lookup a,b as backup)
dat <- add_weight_at_length(dat, lookup_as_backup = TRUE)


## define custom length cuts
length_cuts <- c(0,10,15,20,25,35,Inf)


## add total numbers and weight by haul for custom length cuts
dat <- add_total_numbers_by_haul(dat, length_cuts = length_cuts)
dat <- add_total_weight_by_haul(dat, length_cuts = length_cuts)

png(file.path(fig_dir, "fig03.png"),
    width = 1000, height = 1300, res = 120, bg = "white")
plot_datras_overview(dat,
                     metric = "mean",
                     value_var = "HaulN",
                     by_gear = TRUE,
                     panel_layout = "horizontal",
                     fixed_scale = TRUE,
                     positive_only = TRUE)
dev.off()


## save data set
hh <- as_table(dat)

char_cols <- sapply(hh, is.character)
hh[char_cols] <- lapply(hh[char_cols], factor)

hh$lat <- round(hh$lat, 3)
hh$lon <- round(hh$lon, 3)

utils::object.size(hh) / 1e3

saveRDS(hh, file = "01_tvl_tvs.rds", compress = "xz")

## qs::qsave(hh, "01_tvl_tvs.qs")
## hh <- qs::qread("01_tvl_tvs.qs")


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
