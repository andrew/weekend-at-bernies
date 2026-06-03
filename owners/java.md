# maven owners

525 critical maven packages from 49 distinct owners.

| | organisation | individual | unknown |
|---|---:|---:|---:|
| owners | 34 | 9 | 6 |
| packages | 491 | 34 | 127 |
| non-active packages | 74 | 10 | 6 |
| non-active % | 15.1 | 29.4 | 4.7 |

Maven is the most org-shaped ecosystem in the dataset: only 9 individuals own critical packages here, and the org accounts that dominate are mostly well-known and historically migration-heavy.

## the bernies are namespace migrations and a few foundation projects

| organisation | bernies | active | reading |
|---|---:|---:|---|
| javaee | 15 | 0 | the old Java EE umbrella; everything moved to eclipse-ee4j / jakarta |
| qos-ch | 8 | 3 | logback / slf4j; sloppy public release cadence, real maintenance happens privately |
| springfox | 4 | 0 | OpenAPI for Spring, superseded by springdoc |
| hamcrest | 4 | 0 | the matcher library, finished work |
| powermock | 3 | 0 | superseded by Mockito's inline mock-maker |
| google | 3 | 5 | a few archived Google Java tools |
| spring-cloud | 2 | 18 | live; the bernies are end-of-life sub-projects |

`javaee` alone holds 15 of the ecosystem's 84 non-active packages. None of these are abandoned in the sense of nobody being home; they're all redirected. Anyone hitting one of these coordinates in 2026 should expect to migrate to the jakarta.* namespace.

## qos-ch is split inside the org

qos-ch (Quality Open Software, Ceki Gulcu's company) owns logback, slf4j and their immediate satellites. The classification splits the account neatly:

| half of org | packages | days since release | days since commit | bucket |
|---|---:|---:|---:|---|
| logback (3 packages) | 3 | 71 | 1 (logback-core) | active |
| slf4j (8 packages) | 8 | 427 | 155 | dormant |

Both halves are foundational to Java logging. The slf4j freeze is the more interesting half of the row even though the org overall looks alive.

## the individual side is small but interesting

9 individuals hold maven packages in the critical set, with most owning a single non-active package. There is no large-account-with-many-bernies pattern here at all. The maven ecosystem's culture of putting libraries under org-scoped groupIds appears to do real work in preventing individual-author abandonment risk.

## funding observations

| | value |
|---|---:|
| maven bernie-holding owners | 49 |
| with funding link | 5 |
| % | 10.2 |

The funded owners are qos-ch (GitHub Sponsors), hibernate (Commonhaus), jhipster (Open Collective) and two smaller cases. No maven account fits the npm pattern of many bernies, zero active critical packages, and a published sponsorship setup.

## what this means for outreach

Most of the maven bernie set is namespace-migration debris (javaee, zendframework's java equivalents, springfox) where the action a dependent should take is move to the named successor. Build tools don't surface that automatically; the developer learns about it when something stops compiling against a newer JDK. qos-ch is the exception worth flagging: the slf4j half of the org has been quiet for over a year while the logback half is currently shipping releases, and any outreach there should distinguish between the two.
