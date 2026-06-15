# ToR b case studies

This directory contains a collection of example datasets developed for ToR b of
WKFISHDISH3. Each dataset is designed to highlight one (or more) specific
methodological challenge(s) commonly encountered when developing, fitting,
evaluating, and interpreting SDMs for marine species.

The datasets are not intended to represent complete ecological studies. Instead,
they provide simplified examples that allow participants to explore alternative
modelling approaches and evaluate their strengths and limitations under
controlled conditions.


## Available case studies

| Folder       | Title                                                              | Main methodological challenge                   |
|--------------|--------------------------------------------------------------------|-------------------------------------------------|
| `01_tvl_tvs` | Gear efficiency: TVL vs. TVS for plaice in the Baltic              | Estimating relative gear efficiency             |
| `02_zeros`   | Unnecessary zeros: Can we remove zeros without losing information? | Identifying structural versus informative zeros |
| `03_rare`    | Rare but widespread: Modelling species with few observations       | Handling sparse data for rare species           |
| `04_seasons` | Can one model fit all seasons?                                     | Modelling seasonal heterogeneity                |
| `...`        | Additional case studies                                            | To be added                                     |


## General workflow

Each case study contains:

* a dataset (`.rds`),
* a README file describing the challenge, variables, and assumptions,
* a script to re-create the (processed) case study (if possible).

Participants may use any modelling framework of their choice, including
generalised additive models (GAMs), spatiotemporal models, machine-learning
approaches, or other SDM methods.


## Data sources

So far, the datasets are primarily derived from fishery-independent surveys
available through the ICES Database of Trawl Surveys (DATRAS), with additional
processing and aggregation performed for workshop purposes. Original data
ownership and usage restrictions remain with the respective data providers. (Add
more information here with more case studies)


## Citation

If these datasets are used outside the workshop, please cite the original survey
data sources, acknowledge the workshop dataset compilation and consider
contacting the case study creator(s).


## Contact

Alan Baudron [<alan.baudron@gov.scot>](mailto:Alan.Baudron@gov.scot)

Manuel Hidalgo [<jm.hidalgo@ieo.csic.es>](mailto:jm.hidalgo@ieo.csic.es)

Tobias Mildenberger [<tobm@dtu.dk>](mailto:tobm@dtu.dk)
