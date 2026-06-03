# owners

Who owns the repositories behind 5,874 critical open-source packages, and how the ownership pattern changes when the repository has gone quiet. Repository owner means the GitHub user or organisation account that holds the canonical repo for the package, not the registry publisher (which can differ).

Of 3,125 distinct (host, owner) pairs across the dataset, 2,918 have a known owner type from repos.ecosyste.ms: 1,427 organisations and 1,491 individual users. The remaining 207 are mostly Bitbucket, GitLab self-hosted, SourceForge and other hosts the indexer hasn't reached.

## individual-owned repos go non-active more often

Across the whole set, repositories owned by an individual go non-active at 38% versus 30% for organisations. The dead share is similar (12% vs 10%); the gap is concentrated in the dormant and unknown buckets.

Counted by repo rather than by owner, bernies (dead + dormant) are split almost evenly: 49% sit under an organisation account and 48% under an individual. So while individual ownership is the higher-risk category proportionally, organisations contribute as many bernies in absolute terms because they own more critical repos to begin with.

| owner kind | repos | active | dormant | dead | unknown | non-active % |
|---|---:|---:|---:|---:|---:|---:|
| organisation | 3,133 | 1,918 | 609 | 323 | 283 | 29.7% |
| individual | 2,396 | 862 | 541 | 368 | 625 | 37.9% |
| unknown host | 345 | 84 | 34 | 22 | 205 | 16.2% |

The gap holds in every large ecosystem, but the size of it varies a lot. nuget and pub are dominated by single corporate stewards (dotnet, flutter) and look healthy on both sides. rubygems, cargo, pypi and npm all show roughly a 2x ratio between individual and organisation non-active rates. Haskell and Julia are the outliers where organisation-owned packages go non-active about as often as individual-owned ones.

| ecosystem | org repos | user repos | org non-active % | user non-active % |
|---|---:|---:|---:|---:|
| npm | 1,208 | 988 | 21.6 | 38.8 |
| rubygems | 657 | 249 | 19.3 | 39.8 |
| cargo | 451 | 339 | 14.0 | 30.7 |
| maven | 491 | 34 | 15.1 | 29.4 |
| pypi | 349 | 139 | 17.8 | 33.1 |
| go | 317 | 237 | 42.3 | 46.4 |
| packagist | 428 | 118 | 22.4 | 26.3 |
| hackage | 121 | 297 | 46.3 | 44.8 |
| nuget | 251 | 10 | 7.2 | 20.0 |
| swiftpm | 76 | 21 | 36.8 | 52.4 |
| conda | 231 | 55 | 16.5 | 38.2 |
| hex | 73 | 77 | 26.0 | 42.9 |
| julia | 125 | 42 | 43.2 | 38.1 |
| cocoapods | 53 | 14 | 28.3 | 28.6 |
| pub | 113 | 9 | 5.3 | 11.1 |

## the concentration picture

1,897 repos are bernies. Of those owned by an individual, the long tail dominates: 511 individuals own exactly one bernie each, and the ten most prolific individuals together hold 169 of them (8.9% of the whole). No single person carries a meaningful fraction of the total.

The org side is more top-heavy. Six organisations hold 14 or more bernies each:

| organisation | global repos | bernies in set | active in set |
|---|---:|---:|---:|
| inspect-js | 76 | 40 | 3 |
| google | 2,773 | 20 | 28 |
| haskell | 91 | 15 | 15 |
| jshttp | 29 | 14 | 8 |
| es-shims | 153 | 14 | 3 |
| hashicorp | 920 | 13 | 10 |

The active-in-set column is the read on how the organisation is currently treating its critical packages. google, haskell, jshttp and hashicorp keep a comparable number of critical packages active; inspect-js and es-shims hold many bernies against very few currently active critical packages. The dataset does not say whether these accounts have other activity outside the critical set.

## migrations rather than abandonment

Several apparent clusters of bernies are completed namespace migrations that left the old account behind for compatibility:

  * `javaee` (11 dead repos, 0 active) became `eclipse-ee4j` and the packages moved to the Jakarta EE namespace.
  * `zendframework` (6 dead, 0 active) became Laminas; the org still exists for historical artefacts only.
  * `sensiolabs` (4 dead, 0 active) was absorbed into Symfony.
  * `rust-num` (8 dormant, 0 active) holds the older Rust numerics crates whose successors live elsewhere.

A dependent looking at one of these repos should follow the redirect rather than worry about whether anyone is home; the migration is the answer.

## multi-ecosystem bernies are an org phenomenon

Owners with bernies in more than one ecosystem are almost all big-org accounts whose footprint spans languages: google holds bernies in seven ecosystems, googleapis in five, getsentry, azure, jmespath and microsoft in three each. Few individuals span more than one ecosystem with multiple bernies; the ones who do tend to be the polyglot library authors (jgm: hackage + pypi + conda; felixge: npm + go; alexmojaki: pypi + conda).

For contact triage this matters: a google or azure bernie has a known reporting path even if the specific repo is unattended, while a solo-author bernie that only exists in one ecosystem typically has no such fallback.

## funding links and inactivity

GitHub Sponsors, Open Collective, Tidelift and several smaller platforms publish funding configuration at the account level rather than the repo level. So an account with several bernies and a funding setup is, on the face of it, taking recurring sponsorship while the specific packages a sponsor might have funded see no maintenance. The data does not show what the sponsor money is funding (it could be the account's other active work, or a different project entirely), but the pattern is worth surfacing because the user-facing perception on the npm or rubygems page is "this package is sponsored."

Coverage across the dataset:

| scope | owner kind | owners | with funding | % |
|---|---|---:|---:|---:|
| all critical-package owners | organisation | 1,196 | 155 | 13.0 |
| all critical-package owners | individual | 1,313 | 315 | 24.0 |
| owners holding ≥1 bernie | organisation | 482 | 62 | 12.9 |
| owners holding ≥1 bernie | individual | 610 | 135 | 22.1 |

Bernie-holding owners are no more or less likely to publish funding links than the critical-package population as a whole. Individuals are roughly twice as likely as organisations to publish them on either side.

Per platform, with both scopes side by side:

| platform | all critical owners | bernie-holding owners | bernie share |
|---|---:|---:|---:|
| GitHub Sponsors | 448 | 190 | 42% |
| Open Collective | 50 | 26 | 52% |
| Tidelift | 22 | 11 | 50% |
| Patreon | 10 | 3 | 30% |
| Liberapay | 7 | 1 | 14% |
| Paypal | 6 | 3 | 50% |
| NumFOCUS | 5 | 3 | 60% |
| Buymeacoffee | 4 | 2 | 50% |
| Ko-fi | 4 | 1 | 25% |
| other / custom | 26 | 11 | 42% |

Tidelift, Open Collective, NumFOCUS, Paypal and Buymeacoffee all show a bernie share of 50% or higher: half or more of the accounts using those platforms hold at least one bernie. GitHub Sponsors dominates absolute numbers (448 of 470 funding-enabled accounts publish it), and 42% of those accounts also hold a bernie. The Tidelift line is the one to highlight given Tidelift's contract specifically promises maintenance and security response on the listed packages.

Per ecosystem, the rate at which bernie-holding owners publish funding links varies more than the overall coverage suggests:

| ecosystem | bernie owners | with funding | % |
|---|---:|---:|---:|
| npm | 273 | 72 | 26.4 |
| conda | 59 | 16 | 27.1 |
| swiftpm | 23 | 6 | 26.1 |
| packagist | 72 | 17 | 23.6 |
| pypi | 82 | 17 | 20.7 |
| cargo | 118 | 22 | 18.6 |
| rubygems | 157 | 27 | 17.2 |
| julia | 47 | 6 | 12.8 |
| maven | 49 | 5 | 10.2 |
| go | 153 | 15 | 9.8 |
| nuget | 11 | 1 | 9.1 |
| hex | 45 | 4 | 8.9 |
| hackage | 97 | 4 | 4.1 |

npm leads on funding coverage among bernie-holders. hackage trails the field; go and maven are also well below average. The ecosystems where funding-link culture is most established (npm, packagist, swiftpm) are also where the funded-but-quiet pattern is most likely to show up in any volume.

Of the 25 accounts holding 3 or more bernies and publishing funding links, several have no active repos at all in the critical set:

| owner | kind | bernies | active in set | funding platforms |
|---|---|---:|---:|---|
| jonschlinkert | individual | 18 | 0 | GitHub Sponsors |
| piotrmurach | individual | 6 | 0 | GitHub Sponsors |
| mysticatea | individual | 4 | 0 | GitHub Sponsors |
| inspect-js | organisation | 40 | 3 | GitHub Sponsors, Tidelift |
| es-shims | organisation | 14 | 3 | GitHub Sponsors, Tidelift |
| fog | organisation | 11 | 3 | GitHub Sponsors |
| webpack | organisation | 4 | 18 | Open Collective |

The Tidelift cases are the most direct. Tidelift sells enterprise subscribers paid maintenance and security response for specifically listed packages. Across inspect-js and es-shims, the listed packages show a consistent shape: time-since-last-release ranges from 400 to 900 days, and the merged-PR count for the past year is zero on every one of the non-active packages. Some of those repos do have recent commits on the default branch (deep-equal has six in the past year, last 44 days ago); those commits have not been cut into npm releases, so a subscriber installing the listed package gets the same version they got a year or two ago.

A separate and smaller pattern is the all-bernies-no-active individual with no funding setup at all: vincenthz (23 dead Haskell crypto packages), mitchellh (8 dead pre-HashiCorp Go libraries), dominictarr (6 dead npm packages including the famous event-stream handoff), kr, armon. The critical-set view is just that these accounts hold dead critical packages and don't take sponsorship; what these individuals are doing outside the critical set is not in this dataset.

## per-ecosystem writeups

  * [npm.md](npm.md)
  * [ruby.md](ruby.md) (rubygems)
  * [pypi.md](pypi.md)
  * [rust.md](rust.md) (cargo)
  * [php.md](php.md) (packagist)
  * [go.md](go.md)
  * [java.md](java.md) (maven)
  * [haskell.md](haskell.md) (hackage)

Smaller ecosystems (hex, swiftpm, conda, nuget, pub, julia, cocoapods) are folded into the summary table above; with under 200 packages each the per-owner picture is thin.
