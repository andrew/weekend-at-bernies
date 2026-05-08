# notes

## framing

The risk is the *potential*, not the CVE count. A dead package with a million dependents and zero advisories is in the same position as one with three open CVEs; it just hasn't been looked at yet. AI-assisted vuln discovery is getting good enough that "nobody has bothered to audit this 200-line utility from 2017" stops being a defence. So `bernies.csv` is the full dead+dormant set ranked by blast radius, and the advisory columns are evidence of what's already gone wrong, not a filter on what matters.

Useful angles for the talk: the dead percentage per ecosystem (does the pattern hold everywhere?), total dependent_repos sitting behind dead packages, how many have exactly one registry maintainer, and how many already have an advisory vs how many are just waiting.

First full run (Apr 2026, 8606 critical packages, 5874 repos): 48.8% active, 20.2% dormant, 12.1% dead, 18.9% unknown. The `unknown` bucket is itself a finding: nearly a fifth of critical packages are so quiet that nobody has filed an issue or PR in a year, so responsiveness has simply never been tested. The first security report against any of those is the test.

## "someone home" signals

Three independent views of whether a maintainer exists, each with a different blind spot:

  * **registry maintainers** (`packages.registry_maintainers_count`) — who can publish a release. This is the chokepoint for shipping a security fix. npm/pypi/rubygems expose this; maven/go largely don't. A count of 1 here is a bus-factor red flag even on an active repo.
  * **past-year committers** (`repos.past_year_committers` minus bots) — who is writing code. Bots inflate this badly (dependabot, renovate, github-actions) so the bot split matters.
  * **active issue maintainers** (`repos.active_maintainers_count`) — who with member/owner/collaborator association has touched an issue or PR in the past year. This catches the "I don't commit any more but I still triage" maintainer that the commit count misses.

A repo can be alive on GitHub and dead on the registry (fork-and-publish situations, or the one person with the npm token has vanished). Worth a separate cut: `bucket='active' AND registry_maintainers_count<=1`.

## dormant vs dead

The line is maintainer presence, not activity. Zero commits in three years can just mean the package is finished; it says nothing about whether the author would respond to a security report. So commit age is never sufficient for `dead` on its own. `dead` requires either `archived` or issues data showing zero maintainer response in the past year (no active_maintainers, nothing closed, nothing merged, no release, no commit). A quiet repo with no issues data is `unknown`, not dead.

This makes `dead` a smaller, harder claim and pushes the burden onto the issues data quality. The close/merge counts include bot-driven closes (stale-bot etc.) which will mislabel some dead repos as dormant; that errs in the safer direction.

## things to look at once the db is full

  * dead repos with open dependabot/renovate PRs (`past_year_prs > 0 AND past_year_prs_merged = 0`) — the PR is sitting there and nobody can press merge
  * dead repos with `past_year_issues > 0` — people are still filing bugs into the void
  * dormant repos with exactly one active maintainer — one bad week from dead
  * `days_since_release` distribution per ecosystem — some ecosystems (go, maven) release rarely by culture, so a 2-year gap means less there than on npm
  * sum of `dependent_repos` behind dead packages per ecosystem — "N million repos transitively depend on something nobody maintains"
  * dead packages that *do* have past-year advisories with a patch: who fixed it? forks, foundation takeovers, drive-by maintainers? that's the counter-story

## dependency drift

`deps.rb` compares each package's declared direct-dep major to that dep's current latest major. The ≥1-major-behind cutoff is reliable; the magnitude isn't. Outliers come from squatter versions (`coffeescript@99.999.99999` on npm), calver (`2025.1.1`), release-train names (`Hoxton.SR4`), and snapshot tags. Filter `majors_behind <= 20` or so for anything quantitative.

A third of non-active packages have zero runtime deps and can't drift. Those tend to be the npm micro-utilities at the top of `bernies.csv`, which is its own point: the most depended-on dead packages are often the ones with the least to maintain.

## advisories

`advisories.rb` queries by `(ecosystem, package_name)` and records one row per advisory per package. `patched=0` means every `vulnerable_version_range` for that package has a null `first_patched_version`. That is the strict "no fixed release exists" case. There is a softer case worth a second query: `patched=1` but `first_patched_version > latest_release` on the registry, i.e. the fix is tagged in git but never published. Haven't seen that yet but worth checking once npm/pypi are loaded.

## known gaps

  * `pushed_at` is last push to any branch, not default. A repo can look alive because someone pushed to a fork branch. `clone.rb` fixes this with a real default-branch HEAD date; commits.ecosyste.ms `past_year_commits` is also default-branch only.
  * `clone.rb` can't clone monorepo subpath URLs (`github.com/foo/bar/tree/master/clients/x`) and records null. Those repos still get classified via the API data on the parent repo if another package points at it.
  * monorepos: many packages -> one repo. The repo can be very active while one package inside it is abandoned. `latest_release_at` is per-package so the join helps, but bucket is per-repo.
  * non-github hosts have patchier issues/commits coverage and will skew toward `unknown`.
  * commits api `last_synced_at` can lag; `past_year_*` is a year back from that sync, not from today.
