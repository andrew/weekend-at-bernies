# maintenance in the top science projects (July 2026)

This is a first pass over the top 2,000 projects in [science.ecosyste.ms](https://science.ecosyste.ms), using the same activity and maintainer checks as [Weekend at Bernie's](https://nesbitt.io/2026/05/08/weekend-at-bernies.html). The ranking came from the public science projects page on 30 July 2026. Of the selected projects, 1,899 are categorised as peer-reviewed scientific software.

For each repository the collection pulled repository metadata, a year of default-branch commit activity, a year of issue and pull request activity, package releases and registry maintainers, and published security advisories. It found 2,793 published packages belonging to 1,640 of the repositories.

| bucket | projects | share | meaning |
|---|---:|---:|---|
| active | 865 | 43.3% | regular human commits or a release in the past year |
| dormant | 587 | 29.4% | little development, but evidence that someone with write access is still around |
| dead | 173 | 8.7% | archived, or people filed issues or pull requests and nobody responded |
| unknown | 375 | 18.8% | no activity and nobody knocked, so responsiveness remains untested |

That puts 760 projects, 38.0% of the sample, in the dead or dormant buckets. Among the 1,899 peer-reviewed projects the share is slightly higher at 39.5%, or 751 projects.

## more dormant, fewer dead

| cohort | active | dormant | dead | unknown | dead or dormant |
|---|---:|---:|---:|---:|---:|
| 5,874 critical package repositories, April 2026 | 48.8% | 20.2% | 12.1% | 18.9% | 32.3% |
| 2,000 top science projects, July 2026 | 43.3% | 29.4% | 8.7% | 18.8% | 38.0% |

The dead share is 3.4 percentage points lower in the science sample, while the dormant share is 9.2 points higher. The combined share is therefore 5.7 points higher. Different selection methods prevent a broader claim about scientific software from this comparison. The critical-package set is ranked by package use across sixteen registries; the science set is ranked by the science score and general project score on science.ecosyste.ms.

Richard's handover question is concentrated in the 587 dormant projects. Many more projects have slowed down than have become demonstrably unresponsive, and the data still shows somebody able to commit, close an issue, merge a pull request, or publish a release. A transfer may remain possible before those projects move into the dead or unknown buckets.

The median active project had 58 commits in the past year and was pushed 29 days ago. For dormant projects those medians were two commits and 189 days. Dead projects had no commits and a median last push 773 days ago. Unknown projects also had no commits, with a median last push 1,077 days ago and no issue or pull request filed in the measured year.

Thirty of the 173 dead projects are archived; during the measured year, people filed issues or pull requests against 153 dead projects. Those incoming requests, followed by no maintainer commit, close, merge or release, are the evidence for the classification. The unknown bucket instead contains 375 quiet projects where nobody tested whether a maintainer would answer.

## personal ownership is associated with more bernies

science.ecosyste.ms records whether the repository owner is a GitHub user or organisation. Projects under personal accounts were more often dead or dormant:

| repository owner | projects | active | dormant | dead | unknown | dead or dormant |
|---|---:|---:|---:|---:|---:|---:|
| organisation | 1,035 | 538 | 276 | 75 | 146 | 33.9% |
| individual user | 913 | 311 | 301 | 92 | 209 | 43.0% |
| not recorded | 52 | 16 | 10 | 6 | 20 | 30.8% |

Organisation ownership is only a proxy: an institution may have no control over the project, and one person may hold all the access. The dead-or-dormant share is still 9.1 percentage points higher for personal accounts, while the dead share alone is 10.1% for individuals against 7.2% for organisations.

The data cannot give a clean count of "academic-owned" projects. The peer-reviewed label covers the software and says nothing about who controls its repository or release credentials. Only 550 owner profiles have a company or affiliation recorded. A rough text match for university, institute, laboratory, college, research or academy finds 294 projects; 112 of them are dead or dormant, or 38.1%. The unmatched projects are at 38.0%. The affiliation field is too incomplete and inconsistent to support a claim that institutional affiliation changes the result.

## release access is often concentrated

Of the 1,640 repositories with a published package, 1,146 have one recorded registry maintainer, 356 have two or more, and 138 have none recorded. Some registries expose this information better than others, so zero should be read as missing or zero rather than a confirmed absence of release access.

| recorded registry maintainers | projects | dead or dormant | share |
|---|---:|---:|---:|
| one | 1,146 | 461 | 40.2% |
| two or more | 356 | 108 | 30.3% |
| zero recorded | 138 | 45 | 32.6% |

Projects with one recorded publisher were 9.9 percentage points more likely to be dead or dormant than those with two or more. The counts show an association; a second publisher may simply be another sign of wider project health. The immediate access problem remains: a scientific package often has a single release chokepoint even when several people can contribute code. Several dead or dormant projects also have large user bases:

| science rank | project | bucket | dependent repositories | monthly downloads |
|---:|---|---|---:|---:|
| 6 | Python Sorted Containers | dead | 23,703 | 131,556,604 |
| 217 | Talisman | dormant | 20,812 | 70,476 |
| 1,552 | cytoscape-fcose | dead | 10,156 | 4,838,204 |
| 96 | resampy | dead | 3,118 | 1,470,571 |
| 43 | Yellowbrick | dead | 1,085 | 373,048 |
| 162 | Visions | dormant | 722 | 1,072,345 |
| 77 | emcee v3 | dormant | 538 | 148,138 |
| 62 | Surprise | dormant | 453 | 128,799 |

Dependent-repository counts measure edges in the dependency graph and cannot be added together to produce a deduplicated population of downstream repositories. They are useful for ordering projects by the number of dependency relationships exposed to a maintenance failure.

Python Sorted Containers shows how this screen should be read. It is classified dead because it had no human commits or maintainer response in the measured year despite two new issues, its last recorded release was 1,900 days ago, and the repository was last pushed 874 days ago. Those observations satisfy the screening rule but cannot establish whether the owner would respond to a private security report tomorrow. The classifications are a review queue, with final status requiring manual checks.

## published advisories and the next report

The 2,793 package records had 70 published advisory records. Five have no patched version recorded, spread across three projects: docling, qiskit and lazyllm-llamafactory. All three projects are currently active. None of the dead or dormant projects has an unpatched advisory in this dataset.

The 760 dead or dormant projects still face the same exposure. Advisory data records vulnerabilities that somebody has found, reported and published. The maintenance risk is whether a project can produce and release a fix when the next valid report arrives.

## what researchers can do before somebody leaves

The data supports a few practical handover checks for projects run by graduate students or postdocs:

* Put the repository under a durable organisation with at least two administrators. Moving it on the student's final day is too late if the account, email address or second-factor device has already changed.
* Give at least two current people publish rights for every package registry, then test that each can perform a release. Repository access and registry access are separate, and the latter is the point where a finished fix often gets stuck.
* Record the build, test and release steps in the repository. Include where credentials live, which branch and tag trigger a release, and who can rotate or recover each credential.
* Name the next maintainer before the current one leaves. A lab-owned GitHub organisation still fails as a handover when every review and release waits for one person.
* Review dormant projects while their remaining maintainer is still responding. Waiting for an unanswered security report turns an easy transfer into account recovery and registry policy work.
* Check issue response, release access and default-branch activity separately. A green contribution graph can come from bots or side branches, while the package itself has nobody able to review and publish a fix.

For institutions, a useful inventory would join staff or student departure dates to repository administration and package-publishing rights. ecosyste.ms can supply the public activity side of that audit, but it cannot see employment status, private security contacts, local credentials or whether a named publisher can still log in.

## limits

The sample covers the top 2,000 projects out of roughly 86,000 in science.ecosyste.ms and favours mature, visible projects. It should not be used to estimate an abandonment rate for all research software.

Because classification happens at repository level, an active monorepo can hide an abandoned package. The science run did not clone every default branch, so repository push dates can include side branches; the default-branch commit counts partly correct for that. Upstream sync times also vary: repository records ranged from October 2025 to July 2026, commit records from February to July 2026, and issue records from August 2025 to July 2026. Each "past year" window is relative to the upstream service's sync time.

Repository metadata was available from repos.ecosyste.ms for 1,952 projects. The other 48 retained the baseline metadata supplied by science.ecosyste.ms. Commit and issue records were available for all 2,000 projects.

The API returned zero citations for every selected project, so citations cannot be used in this report. Science scores came from the public ranking page because the API does not currently return them or sort by them. The full project export is in [`out/science-projects.csv`](out/science-projects.csv), the 760 dead or dormant projects are in [`out/science-bernies.csv`](out/science-bernies.csv), and bucket totals are in [`out/science-buckets.csv`](out/science-buckets.csv).
