# Rare but widespread: Modelling species with few observations


| Field        | Value                               |
|--------------|-------------------------------------|
| Author       | Tobias Mildenberger and Casper Berg |
| Email        | tobm@dtu.dk and cabe@dtu.dk         |
| Version      | 2.0                                 |
| Last updated | 2026-06-14                          |



## Methodological challenge

In contrast to species associated with specific habitats, rare species may
exhibit many zero observations simply because abundance is low, even within
otherwise suitable habitat. In such cases, zeros contain important information
about occupancy, detectability, and abundance, and removing them may bias
habitat relationships and spatial predictions.

This dataset contains observations of John Dory (*Zeus faber*) from the North
Sea International Bottom Trawl Survey (NS-IBTS) between 2015 and 2024. John Dory
is distributed across much of the North Sea but is encountered only rarely in
survey catches. As a result, the dataset contains a large proportion of
zero observations despite the species occurring over a broad geographic range (Fig. 1).

![Figure 1. All NS-IBTS haul locations (left panel) and locations with positive
observations (right panel).](figs/fig01.png)

The number of hauls with positive observations of John Dory range between 1.8
and 5.1% (Figure 2).

![Figure 2. Ratio of number of hauls with positive John Dory observations and
total number of hauls between 2015-2024.](figs/fig02.png)

Positive observations occur throughout much of the survey area, but are sparse
and highly variable among years (Fig. 3).

![Figure 3. Spatial distribution of hauls with positive observations by
year.](figs/fig03.png)

### Questions to explore

* Can habitat preferences be estimated reliably with few positive observations?
* How many observations are needed before model predictions become stable?
* Are observed absences likely to represent true absences?
* Do zero-inflated or hurdle models improve predictive performance?
* What information is lost if zero observations are removed?
* How sensitive are predictions to individual observations or years?
* Can broad-scale habitat preferences be distinguished from sampling variability?
* Does spatial smoothing help recover meaningful distribution patterns from
  sparse observations?


## Data sources

* **Source:** ICES DATRAS
* **Survey:** North Sea International Bottom Trawl Survey (NS-IBTS)
* **Years:** 2015–2024
* **Species:** John Dory (*Zeus faber*)
* **Response variables:**

  * Number of fish per haul
  * Total weight per haul


## Key variables

| Variable     | Unit             | Description                                                          |
| ------------ | ---------------- | -------------------------------------------------------------------- |
| haul.id      | —                | Unique identifier for each survey haul.                              |
| Survey       | —                | DATRAS survey programme identifier.                                  |
| Gear         | —                | Survey gear identifier.                                              |
| Country      | —                | Country code of the survey institute or vessel.                      |
| Ship         | —                | Survey vessel code.                                                  |
| Year         | year             | Year in which the haul was conducted.                                |
| Quarter      | quarter          | Calendar quarter of the survey (1–4).                                |
| Month        | month            | Calendar month of the haul (1–12).                                   |
| Day          | day              | Day of month on which the haul was conducted.                        |
| lon          | decimal degrees  | Haul longitude (WGS84).                                              |
| lat          | decimal degrees  | Haul latitude (WGS84).                                               |
| timeOfYear   | fraction of year | Timing of the haul within the year.                                  |
| abstime      | year             | Continuous decimal-year variable, approximately `Year + timeOfYear`. |
| DayNight     | —                | Day/night category of the haul (`D` = day, `N` = night).             |
| TimeShotHour | hour of day      | Haul start time as decimal hour.                                     |
| HaulDur      | minutes          | Duration of the haul.                                                |
| SweptArea    | m²               | Estimated swept area of the haul.                                    |
| HaulN | number | Number of John Dory caught in the haul. |
| HaulWgt | g | Total weight of John Dory caught in the haul. |

Detailed information about many of these columns can also be downloaded as an
excel table from the [ICES
webpage](https://www.ices.dk/data/Documents/DATRAS/DATRAS_Field_descriptions_and_example_file_December2025.xlsx).


## Assumptions

1. Species identifications are correct and consistent throughout the time
   series.
2. Haul positions and associated sampling metadata are accurate.
3. Survey catchability is sufficiently constant through time for distributional
   patterns to be interpreted biologically.
4. Many observed absences reflect non-detection or low abundance rather than
   unsuitable habitat.
5. The observed spatial distribution is representative of the species'
   underlying distribution during the study period.
