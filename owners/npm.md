# npm owners

2,275 critical npm packages from 273 distinct owners.

| | organisation | individual | unknown |
|---|---:|---:|---:|
| owners | 98 | 168 | 7 |
| packages | 1,208 | 988 | 79 |
| non-active packages | 261 | 383 | 11 |
| non-active % | 21.6 | 38.8 | 13.9 |

The individual/organisation gap on non-active rates is the largest of any ecosystem with more than a thousand packages. npm dominates the bernie set in absolute terms partly through that gap and partly through the high share of individual ownership.

## a handful of accounts dominate the npm bernies

The top six bernie-holders own 158 of npm's 644 non-active packages between them, more concentration than any other ecosystem in this dataset shows. Almost every name has an outsize footprint elsewhere on the registry too.

| owner | kind | bernies | active in set | total in set |
|---|---|---:|---:|---:|
| sindresorhus | individual | 45 | 84 | 181 |
| inspect-js | organisation | 40 | 3 | 48 |
| ljharb | individual | 25 | 6 | 36 |
| micromark | organisation | 21 | 0 | 21 |
| jonschlinkert | individual | 18 | 0 | 59 |
| xtuc | individual | 16 | 0 | 17 |
| blakeembrey | individual | 16 | 0 | 18 |
| jshttp | organisation | 14 | 8 | 22 |
| es-shims | organisation | 14 | 3 | 27 |

Three of these accounts (inspect-js, es-shims, ljharb) publish under Jordan Harband's name:

| | bernies | active | total | funding |
|---|---:|---:|---:|---|
| inspect-js | 40 | 3 | 48 | GitHub Sponsors, Tidelift |
| es-shims | 14 | 3 | 27 | GitHub Sponsors, Tidelift |
| ljharb | 25 | 6 | 36 | GitHub Sponsors, Ko-fi |
| combined | 79 | 12 | 111 | |

sindresorhus is the largest single account in any ecosystem here:

| | count |
|---|---:|
| critical packages owned | 181 |
| active | 84 |
| non-active (dormant + dead) | 45 |
| non-active share | 25% (vs 39% npm average for individuals) |

Several other large individual accounts hold many non-active critical packages and zero active ones in the critical set:

| owner | bernies | active in set | activity status | funding |
|---|---:|---:|---|---|
| jonschlinkert | 18 | 0 | engaged (3 pushes in last 30d) | GitHub Sponsors |
| xtuc | 16 | 0 | quiet | none |
| blakeembrey | 16 | 0 | engaged (recent pushes) | GitHub Sponsors |
| gregberge | 14 | 0 | engaged | GitHub Sponsors |
| isaacs | 13 | 15 | engaged (7 active_maint, 16 push 30d) | GitHub Sponsors |
| dominictarr | 6 | 0 | gone (no recorded push) | none |
| indutny | 6 | 0 | engaged | none |
| mafintosh | 5 | 5 | engaged | GitHub Sponsors |

The activity status comes from a separate check against ecosyste.ms's commit and issues data: it asks whether the person has any recent maintenance activity anywhere on github, not just on their critical packages. Of the npm bernie-holding individuals (168 total) the split runs 110 engaged, 39 trickling, 10 quiet, 9 gone. So the dominant pattern under npm's largest individual accounts is the person has moved their attention to other repos, not that the person has stopped maintaining open source.

## micromark and the unifiedjs orbit

micromark holds 21 non-active critical packages and 0 active in the set. The funding configuration on the org points at unifiedjs (the parent account for remark, rehype and related markdown tooling), so a sponsor of the funded entity is supporting an account distinct from the micromark org whose packages they may be installing.

## tidelift and the listed-package pattern

Tidelift's funding links name specific packages. Two appear under non-active owners in our set:

  * `inspect-js/deep-equal`: listed for Tidelift funding, in the dormant bucket.
  * `es-shims/es5-shim`: listed for Tidelift funding, dormant.

The dormant classification on these packages has a specific shape. deep-equal sits like this:

| | value |
|---|---:|
| days since last npm release | 901 |
| commits on default branch in past year | 6 |
| days since last commit | 44 |
| merged PRs in past year | 0 |

Across all of inspect-js and es-shims, every non-active package has zero merged PRs in the past year and a time-since-release between 400 and 900 days. A subscriber installing the Tidelift-listed version of deep-equal today gets the same artefact they would have got two and a half years ago.

## the org category here is mostly small developer collectives

98 organisations own npm packages in the critical set, with the median org owning 2. The 22% non-active rate for orgs is dragged up by a small number of large account-holders that read more like single-author umbrella accounts than corporate stewards. The org maintainer-and-push data refines the picture:

| org account | bernies | hist maint | active maint | top maintainer | reading |
|---|---:|---:|---:|---|---|
| inspect-js | 40 | 4 | 0 | ljharb (86%) | committing quietly: pushes ongoing, no community engagement |
| micromark | 21 | 8 | 0 | ChristianMurphy | wound down: no current maintainers |
| jshttp | 14 | 14 | 7 | blakeembrey | active small team, distributed |
| es-shims | 14 | 6 | 0 | ljharb (88%) | committing quietly: same shape as inspect-js |

jshttp is the healthy case in this set: 14 historical maintainers, 7 currently active, and the top one accounts for less than half the total. inspect-js and es-shims are the ones that look most like umbrella accounts for a single individual; ljharb is responsible for 86 and 88% of all historical maintainer activity respectively, and no maintainer is currently registered as active. micromark is in the wound-down bucket: nobody is engaged, and recent pushes are minimal.

The actual large-corporate accounts (npm, microsoft, facebook, google) are present in the data but each holds only a handful of critical packages.

## what this means for outreach

For outreach, the npm bernie set is concentrated enough to be addressable: the top six bernie-holding accounts together hold roughly a quarter of the registry's non-active critical packages, and most of the relevant individuals are reachable (engaged or trickling on github). The gone-bucket cohort is small: 9 of 168 npm bernie-holding individuals, with dominictarr the only one holding more than a single bernie.

For the remediation taxonomy in [`../findings/README.md`](../findings/README.md), the npm owner picture argues for a vendor-heavy approach overall: the registry's high non-active rate on individual-owned packages combined with 200 bernies under accounts that have no other active critical package mean a per-package outreach effort would scale poorly. The 73 bernie-owners who also currently maintain an active critical npm package are the subset where outreach about archiving, handoff or release cadence is most likely to land, because they're already curating something the dataset cares about. For the inspect-js / es-shims / micromark single-person umbrellas the adopt action is unusually feasible (one person can transfer everything in one negotiation), at the cost of inheriting the same supply-chain concentration on whoever adopts.

For most of the rest the question for outreach is not "is anyone home" but "do you still consider this package worth releasing." The event-stream incident, where dominictarr handed maintenance to an anonymous contributor who then shipped malware, remains the standing reason maintainer handoff on npm carries more weight than the action sounds.
