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

## are the individual owners still here?

For each of the 609 individual github.com owners holding at least one bernie, we asked ecosyste.ms two questions: are they currently maintaining anything (issues/PRs activity in the last few months) and have they pushed to any repo recently. Combining the two:

| class | n | % | meaning |
|---|---:|---:|---|
| engaged | 379 | 62.2 | currently maintaining at least one repo, or pushed to any repo in the last 30 days |
| trickling | 130 | 21.3 | pushed in the last year, but no current issue/PR engagement |
| quiet | 81 | 13.3 | last push 1 to 3 years ago |
| gone | 19 | 3.1 | no recorded push, and not currently maintaining anything |

The vast majority of "bernie owners" are still here. The reason the packages went non-active is mostly that the maintainer's attention moved elsewhere, not that the person left. Examples from the top of the list: mitchellh (8 bernies, currently active on the ghostty terminal emulator with 3 active_maintaining repos and 3 pushes in the last 30 days), vincenthz (23 hackage bernies, 10 pushes in the last year), sindresorhus (45 bernies, 26 pushes in the last 30 days). The headline "they've stopped" framing is wrong about all three.

The 19 actually-gone accounts are heavily concentrated in npm (9) and rubygems (5). The two with more than one bernie are dominictarr (6 npm bernies, no pushes recorded since indexing began) and the smaller hex/julia cases. Most names in the gone bucket hold a single bernie each.

## are the orgs still here?

For each of the 481 organisation accounts holding at least one bernie, we asked ecosyste.ms two questions: how many maintainers are currently engaged on the org's repos (excluding bots like renovate-bot, dependabot, modular-magician), and how recent the push activity is across all of the org's repos. The classes are not symmetric with the individual ones: an org with five active maintainers and an org dominated by one person who is also that org's sole committer are operationally different things even if both pass a "yes there is activity" check.

| class | orgs | bernies | criteria |
|---|---:|---:|---|
| active distributed | 97 | 269 | 5+ active human maintainers, no single dominator |
| active small team | 85 | 169 | 1 to 4 active human maintainers, no single dominator |
| single-person org | 58 | 103 | active maintenance exists but one person handles 60%+ of it |
| push-only | 43 | 116 | pushes in the last 30 days but no active maintainer engagement |
| trickling | 107 | 153 | pushed within the last year, not in the last 30 days, no active maintainers |
| wound down | 48 | 64 | historical maintainers exist but no active engagement and no recent pushes |
| unindexed but pushing | 20 | 33 | not in the maintainers index but pushing actively (typically large corporate orgs ecosyste.ms hasn't fully crawled) |
| no data | 23 | 23 | ecosyste.ms has neither maintainer record nor recent push activity |

About 42% of bernie-holding orgs (202 of 481) are in some form clearly alive (active distributed + small team + unindexed). They account for 47% of org-held bernies. Another 12% are single-person orgs where the org account is functionally an umbrella for one individual. Most of those names are recognisable: inspect-js and es-shims (Jordan Harband), savonrb, hspec, markdown-it (puzrin), composer (Seldaek), gorilla, fog (geemus, the single human active maintainer).

The interesting middle category is "push-only" (43 orgs, 116 bernies): orgs that are getting code pushed but no community engagement. inspect-js and es-shims are the largest of these, despite the active-maintainer count being zero: ljharb continues to push to those repos without merging external PRs or addressing issues. That's a different failure mode from a dormant org. There are commits on main, but no releases are cut, and external contributors can't get changes accepted.

The wound-down list overlaps almost exactly with the migration-cluster section below. javaee (11 bernies), zendframework (6), css-modules (4), gorilla (4), opentracing (3), turbolinks, visionmedia (tj's old org), celluloid are all here. For these the action a dependent should take is to follow the named successor rather than try to revive the original.

## what the owner data implies for remediation

The remediation taxonomy in [`../findings/README.md`](../findings/README.md) names five actions a dependent can take on a non-active package: accept, vendor, switch, switch-piecemeal, adopt. Which one fits depends partly on the package's shape (size, usage concentration, named successor) and partly on the owner's state. The owner side is what this analysis adds.

| owner state | what it implies for remediation |
|---|---|
| migrated or dead org with named successor (javaee, zendframework, sensiolabs, rust-num) | switch is forced and unambiguous; the successor is published. Outreach to the old org is unnecessary. |
| active distributed org with bernie sub-packages (google, hashicorp, googleapis, symfony, dotnet) | accept is defensible: the org can ship a security fix even if release cadence has slowed. Outreach has a known landing path. |
| single-person umbrella, owner currently engaged (inspect-js, es-shims, fog, sphinx-doc, hspec, jonschlinkert, sindresorhus, ljharb) | adopt is mechanically real because one person controls everything; the same fact concentrates supply-chain risk on that person. Sponsor-based pressure is available when a funding link exists. |
| wound-down org or gone individual with no named successor (dominictarr, sstephenson, opentracing-without-otel-named, gorilla pre-revival) | vendor for small packages, accept for larger ones; outreach is unlikely to land. |
| owner also operates an active critical package in the same ecosystem (104 orgs and 25 individuals here) | switch and adopt outreach has the highest chance of getting a reply: the person/org is already curating something other people depend on |
| funded owner with bernie set and zero active critical packages (jonschlinkert, piotrmurach, micromark, inspect-js/es-shims via Tidelift) | the sponsor relationship is itself a remediation lever: a sponsor can credibly ask for archiving, handoff, or a release cadence |

The supporting numbers behind those rows:

| | organisation | individual |
|---|---:|---:|
| bernie owners total | 482 | 610 |
| also own ≥1 active critical (highest-priority outreach) | 219 (45%) | 98 (16%) |
| bernies-only, no active critical (vendor/accept territory) | 263 | 512 |
| more active critical packages than bernies (sindresorhus / dtolnay shape) | 104 | 25 |
| in the gone bucket on the github activity check | n/a | 19 |
| classified single-person org or umbrella | 58 | n/a |
| classified wound-down or migrated org | 155 | n/a |

So out of 1,138 bernie-holding accounts in the dataset, somewhere around 317 are already operating something else live in the same registry (the highest-priority targets for switch / adopt outreach), 155 orgs are clearly migrated or wound down (switch to the named successor, no conversation needed), and the bulk of individual bernie-holders (512 of 610) own nothing else active in the critical set, putting most of those packages into vendor-or-accept territory by default.

The per-ecosystem differences mostly reflect ownership culture rather than ecosystem health: packagist and maven cluster bernies under live vendor orgs (so 45% and 33% of bernie-owners are also active there), while rubygems, hex and julia have lots of one-person-per-package ownership (so the typical bernie-owner has only the bernie). Same fact, different implication for what to do: the packagist owner is more likely to be reachable; the rubygems owner is more likely to need vendor or accept as the answer.

This is a stronger signal than the github-activity check earlier. An individual can be very active on github without being engaged with anything in the critical-package set, but a maintainer of a currently active critical package has skin in the same game the bernies are part of.

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

A separate and smaller pattern is the all-bernies-no-active individual with no funding setup at all: vincenthz (23 dead Haskell crypto packages), mitchellh (8 dead pre-HashiCorp Go libraries), dominictarr (6 dead npm packages including the famous event-stream handoff), kr, armon. The maintainer activity check above adds important nuance here: of those five, only dominictarr classifies as gone in the activity data. vincenthz is trickling (10 pushes in the last year), mitchellh is engaged (3 active_maintaining repos), kr and armon are quiet (last push roughly a year ago). The packages they own are non-active; most of the people who own them are not.

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

## other analyses

  * [domains.md](domains.md): commit-email domain takeover risk across bernie-holders. One at-risk domain found in the data (`lddubeau.com`, owns saxes and xmlchars on npm); the methodology lessons from getting to that answer are recorded too.
