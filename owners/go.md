# go owners

571 critical go packages from 153 distinct owners.

| | organisation | individual | unknown |
|---|---:|---:|---:|
| owners | 69 | 82 | 2 |
| packages | 317 | 237 | 17 |
| non-active packages | 134 | 110 | 2 |
| non-active % | 42.3 | 46.4 | 11.8 |

Go is the only major ecosystem where org and individual non-active rates are within touching distance of each other. Two structural events plausibly contribute: the 2018 GOPATH-to-modules transition and the subsequent move to semantic-import versioning, plus a recurring pattern of corporate-authored libraries getting archived when the owning team reorganises. Both produce repos that look abandoned by the dataset's criteria but were superseded or rolled into a vendor product.

## the org bernies are mostly corporate cleanup

| organisation | bernies | active | reading |
|---|---:|---:|---|
| hashicorp | 13 | 10 | pre-acquisition libraries (consul/api, vault helpers) that IBM-era HashiCorp left in place |
| azure | 13 | 1 | older azure-sdk-for-go branches superseded by track2 generator |
| gobuffalo | 9 | 0 | the Buffalo web framework, effectively done |
| google | 8 | 4 | scattered project-specific Go tools and samples |
| golang | 5 | 1 | the official x/* subrepos, mostly experimental or paused |
| gorilla | 4 | 0 | the gorilla/* web toolkit, archived in 2022 and revived by a new community org |

Most of these are not contactability problems. HashiCorp, Microsoft (azure) and Google all have functional issue trackers and known maintainer routing for security work; the libraries are non-active because the work has moved to a successor product, even though somebody at the org would still answer.

## the individual side

| individual | bernies | active | reading |
|---|---:|---:|---|
| mitchellh | 8 | 0 | pre-HashiCorp Go libraries (mapstructure, copystructure, multierror); none currently active in the critical set |
| jackc | 7 | 1 | pgx and surrounding libraries; one sub-package active, others non-active |
| jinzhu | 2 | 0 in set | gorm author; gorm itself is on the go-gorm org account, the personal account holds older versions |
| felixge | 2 | 0 in set | pprof-related; this is the personal-account footprint, not what the same person ships at their employer |

The mitchellh row is the highest-stakes one in the table because mapstructure sits underneath a large fraction of Go applications via Viper, Cobra and HashiCorp tools. Eight of the personal-account libraries here are non-active and none are currently active in the critical set. The account does not publish a funding link. The dataset does not show whether the same person is committing in other repos or accounts.

## funding in go is uncommon

Two individuals among the top go bernie-holders publish funding links: mattn (active in the critical set) and jinzhu (2 bernies on the personal account; gorm itself is on a separate org account and the Patreon and Open Collective links route there).

## what this means for outreach

A meaningful share of go's bernie set is structural: archived corporate projects, namespace migrations, libraries superseded by a successor inside the same org. For dependents the action is usually to vendor the file, switch to the version inside the new monorepo, or accept the pin. The personal-account cases (mitchellh, jackc, jinzhu) need maintainer-side data the critical-package slice does not provide before any outreach recommendation makes sense.
