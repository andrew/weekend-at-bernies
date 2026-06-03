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

| owner | bernies | active in set | funding |
|---|---:|---:|---|
| jonschlinkert | 18 | 0 | GitHub Sponsors |
| xtuc | 16 | 0 | none |
| blakeembrey | 16 | 0 | GitHub Sponsors |
| gregberge | 14 | 0 | GitHub Sponsors |

Whether these accounts are active on non-critical repos is outside this dataset.

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

98 organisations own npm packages in the critical set, with the median org owning 2. The 22% non-active rate for orgs is dragged up by a small number of large account-holders that read more like single-author umbrella accounts than corporate stewards:

| org account | bernies | active |
|---|---:|---:|
| inspect-js | 40 | 3 |
| micromark | 21 | 0 |
| jshttp | 14 | 8 |
| es-shims | 14 | 3 |

The actual large-corporate accounts (npm, microsoft, facebook, google) are present in the data but each holds only a handful of critical packages.

## what this means for outreach

For outreach, the npm bernie set is concentrated enough to be addressable: the top six bernie-holding accounts together hold roughly a quarter of the registry's non-active critical packages. What an outreach effort can realistically ask of those owners (archive, hand off, cut a release, add a co-maintainer) needs more data than the critical-package slice provides; the event-stream incident, where dominictarr handed maintenance to an anonymous contributor who then shipped malware, is the standing reason maintainer handoff on npm carries more weight than the action sounds.
