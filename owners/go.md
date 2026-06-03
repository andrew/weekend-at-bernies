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

| organisation | bernies | active | hist maint | active maint | reading |
|---|---:|---:|---:|---:|---|
| hashicorp | 13 | 10 | 463 | 171 (humans) | active distributed; modular-magician bot tops raw activity |
| azure | 13 | 1 | 4 | 1 | single-person org by the maintainer index (top 97% share), but Microsoft's larger azure-sdk-* orgs handle current SDK work |
| gobuffalo | 9 | 0 | 11 | 1 | active small team, but only one currently active maintainer (markbates) |
| google | 8 | 4 | 1,580 | 487 (humans) | active distributed; renovate-bot tops raw activity |
| golang | 5 | 1 | 92 | 30 | active distributed: the official x/* subrepos |
| gorilla | 4 | 0 | 10 | 0 | wound down: the gorilla/* web toolkit, archived in 2022; a community org revived it elsewhere |
| jmespath | 4 | 0 | 4 | 0 | wound down |
| opentracing | 3 | 0 | 18 | 0 | wound down: succeeded by opentelemetry |

The org activity data does cleanly separate the corporate-cleanup cases from the wound-down ones. hashicorp, google and golang have hundreds of active human maintainers between them; the bernies they own are just sub-projects within otherwise alive organisations. gorilla, jmespath and opentracing have zero active maintainers each, consistent with their published successors.

## the individual side

| individual | bernies | active in set | activity status | reading |
|---|---:|---:|---|---|
| mitchellh | 8 | 0 | engaged (3 active_maint, 3 push 30d, last push 2026-05-30) | pre-HashiCorp Go libraries (mapstructure, copystructure, multierror); the same person is currently maintaining ghostty-org/ghostty and mitchellh/libxev |
| jackc | 7 | 1 | engaged (2 active_maint, 3 push 30d) | pgx and surrounding libraries; the author is actively maintaining elsewhere on github |
| jinzhu | 2 | 0 in set | engaged (gorm itself is on the go-gorm org account) | personal account holds older versions; the funded sponsorship routes to live work |
| felixge | 2 | 0 in set | engaged (6 active_maint, 3 push 30d) | pprof-related; this is the personal-account footprint, not what the same person ships at their employer |
| armon | 3 | 0 | quiet (last push 2024-07-06) | pre-HashiCorp libraries; no recent activity recorded |
| kr | 3 | 0 | quiet (last push 2024-07-26) | similar profile to armon |

The mitchellh row is the highest-stakes one in the table because mapstructure sits underneath a large fraction of Go applications via Viper, Cobra and HashiCorp tools. The 8 pre-HashiCorp libraries on the personal account are non-active, but the person himself is very much engaged on github (ghostty-org/ghostty has 258 issues and 432 PRs of his activity recorded; libxev has 39 maintenance interactions). The packages are non-active because his attention moved, not because he left. armon and kr (former HashiCorp engineers whose pre-HashiCorp libraries are similarly dormant) are quieter on the activity check: last recorded push around a year ago.

Across go's 82 bernie-holding individuals: 46 engaged, 17 trickling, 17 quiet, 2 gone. The quiet bucket is unusually large for go (versus npm's 10 or rubygems' 7) and reflects the common pattern of go libraries being written, finished, and the author moving on to other work without the kind of ongoing churn that keeps a personal account active.

## funding in go is uncommon

Two individuals among the top go bernie-holders publish funding links: mattn (active in the critical set) and jinzhu (2 bernies on the personal account; gorm itself is on a separate org account and the Patreon and Open Collective links route there).

## what this means for outreach

A meaningful share of go's bernie set is structural: archived corporate projects, namespace migrations, libraries superseded by a successor inside the same org. For dependents the action is usually to vendor the file, switch to the version inside the new monorepo, or accept the pin. The personal-account cases (mitchellh, jackc, jinzhu) are reachable in principle since the people are still active on github, but contacting the author of a 5-year-old utility library to ask them to come back to it is a different ask from contacting them about something they're currently working on. The 2 individuals classified as gone here both hold a single bernie each, so they're unlikely to be the highest-impact targets either way.
