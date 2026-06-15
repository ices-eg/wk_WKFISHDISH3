#####################
## Case study 03: Modelling rare but widespread species
#####################

## Tobias Mildenberger <tobm@dtu.dk> and Casper Berg <cabe@dtu.dk>
## June 2026


## remotes::install_github("tokami/DATRASextra@dev")
require(DATRASextra)  ## v0.2.0


## specify data path
data_dir <- "~/Documents/data/makeData/DATRAS"
fig_dir <- "figs"
dir.create(fig_dir)


## years
years <- 2015:2024


## surveys with beam trawl gears
surveys <- c("NS-IBTS")


## beam trawls
gears <- c("GOV")


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


## select john dory
dat <- subset(dat, Valid_Aphia == "127427") ## Zeus faber


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


## add total numbers and weight by haul
dat <- add_total_numbers_by_haul(dat)
dat <- add_total_weight_by_haul(dat)

png(file.path(fig_dir, "fig01.png"),
    width = 1200, height = 1000, res = 120, bg = "white")
par(mfrow = c(1,2))
plot_datras_overview(dat, add = TRUE)
plot_datras_overview(dat, positive_only = TRUE,
                     col = 4, add = TRUE)
dev.off()

tmp <- unique(dat$HH[c("haul.id", "Year", "HaulN")])
agg <- aggregate(HaulN > 0 ~ Year,
          data = tmp,
          FUN = function(x) round(100 * mean(x),1))

png(file.path(fig_dir, "fig02.png"),
    width = 1400, height = 1500, res = 120, bg = "white")
plot(as.numeric(agg[,1]), agg[,2],
     ty = "b",
     xlab = "Year",
     ylab = "Hauls with positive observations (%)")
dev.off()

png(file.path(fig_dir, "fig03.png"),
    width = 1400, height = 1500, res = 120, bg = "white")
plot_datras_overview(dat,
                     by_year = TRUE,
                     positive_only = TRUE,
                     multi_panels = TRUE)
dev.off()

## save data set
hh <- as_table(dat)

char_cols <- sapply(hh, is.character)
hh[char_cols] <- lapply(hh[char_cols], factor)

hh$lat <- round(hh$lat, 3)
hh$lon <- round(hh$lon, 3)

utils::object.size(hh) / 1e3

saveRDS(hh, file = "03_rare.rds", compress = "xz")



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
