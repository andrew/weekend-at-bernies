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

| organisation | bernies | active | hist maint | active maint | reading |
|---|---:|---:|---:|---:|---|
| javaee | 15 | 0 | 33 | 0 | wound down: fully migrated to eclipse-ee4j / jakarta |
| qos-ch | 8 | 3 | 8 | 0 | see split below |
| springfox | 4 | 0 | 1 | 0 | wound down: superseded by springdoc |
| hamcrest | 4 | 0 | 8 | 1 | single-person org around offbyone; finished work |
| powermock | 3 | 0 | 2 | 0 | wound down: superseded by Mockito's inline mock-maker |
| google | 3 | 5 | many | many | active distributed |
| spring-cloud | 2 | 18 | active | active | active distributed; bernies are end-of-life sub-projects |

`javaee` alone holds 15 of the ecosystem's 84 non-active packages. The org activity check confirms: 33 historical maintainers and zero active, which matches the public story of the namespace migration to jakarta. Anyone hitting one of these coordinates in 2026 should expect to follow the migration.

## qos-ch is split inside the org

qos-ch (Quality Open Software, Ceki Gulcu's company) owns logback, slf4j and their immediate satellites. The classification splits the account neatly:

| half of org | packages | days since release | days since commit | bucket |
|---|---:|---:|---:|---|
| logback (3 packages) | 3 | 71 | 1 (logback-core) | active |
| slf4j (8 packages) | 8 | 427 | 155 | dormant |

The org-level activity data adds context: 8 historical maintainers but 0 currently active by the maintainer engagement check, with all 8 historical interactions attributed to ceki himself. So qos-ch reads as a single-person org where the one person continues to push to logback but slf4j has fallen behind. Both halves are foundational to Java logging.

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
