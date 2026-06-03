# Weekend at Bernie's

Data collection for [Weekend at Bernie's](https://nesbitt.io/2026/05/08/weekend-at-bernies.html), a blog post and talk on widely used open source packages that are effectively dead but still propped up in production everywhere. Pulls the `critical=true` package set from [packages.ecosyste.ms](https://packages.ecosyste.ms), enriches each backing repo with commit, issue, advisory and dependency data from the other ecosyste.ms services, then buckets repos into active / dormant / dead / unknown.

The failure mode we care about: a security report or a breaking dependency update lands and there is nobody left with commit or publish rights to respond. That used to be a slow-moving risk because nobody was auditing 200-line utilities from 2017. AI-assisted vulnerability discovery changes the rate at which those reports arrive without changing the number of people able to act on them.

## Setup

    bundle install

## Pipeline

    ruby fetch.rb            # critical packages -> bernies.db (packages + repos tables)
    ruby repos.rb            # refresh pushed_at/archived from repos.ecosyste.ms
    ruby commits.rb          # past-year commit/committer counts, bot split, dds
    ruby issues.rb           # past-year issue/PR activity, active_maintainers
    ruby advisories.rb       # per-package advisories, patched/unpatched
    ruby classify.rb         # bucket repos using whatever signals are present
    ruby clone.rb            # shallow-clone non-active repos for true last_commit_at
    ruby deps.rb             # dependency drift (majors behind) for non-active packages
    ruby classify.rb         # re-bucket
    ruby report.rb           # stats + out/*.csv

`fetch.rb` defaults to all sixteen upstream registries; pass names to limit (`ruby fetch.rb rubygems.org hex.pm`). Every HTTP response is cached under `cache/<step>/` keyed by URL so re-runs are local-only and the db can be rebuilt after schema changes. Each enrichment script skips rows it has already touched, takes an optional row limit, and is safe to re-run; delete the matching cache dir to force a refetch.

The signals stack as proofs of life. A recent release, a recent default-branch commit, an active issue maintainer, a merged PR — any one of those is enough to mark a repo alive and skip the expensive checks. Run `classify.rb` between steps; `clone.rb` and `deps.rb` skip repos already bucketed `active` (pass `--all` to override). `clone.rb` does a `--depth 1 --bare --filter=blob:none` clone per repo to read the real default-branch HEAD date, since `pushed_at` from the API covers any branch and lags. `deps.rb` measures drift: for each package's latest release it fetches the declared direct dependencies, looks up each dep's current latest, and records `majors_behind`.

Some repos won't be indexed by the issues or commits services yet. The lookup triggers a background sync, so a re-run a day or two later (after `rm cache/issues cache/commits`) will fill more in. Until then those repos sit in `unknown`.

## Buckets

  * **active** — regular human commits in the past year, or a release in the last year
  * **dormant** — little or no development but someone with write access is still around: closing issues, merging PRs, committing occasionally. A fix could plausibly land.
  * **dead** — archived, or someone filed an issue/PR in the past year and nobody with write access responded, merged, closed, committed or released anything
  * **unknown** — nobody filed anything and nothing happened; responsiveness is untested. Also covers repos the issues service hasn't indexed.

`dead` is deliberately a hard claim: it requires evidence that someone knocked and nobody answered. Zero commits is never sufficient on its own; a finished package with no commits in five years whose author would still merge a security fix is dormant, not dead. Thresholds live at the top of `classify.rb` and the `signals` column on each repo records the raw inputs so cutoffs can be argued over with `SELECT` rather than re-collection.

## Remediation

Bucketing tells you whether anyone is home. The remediation layer asks what a dependent should do about it: what shape the package is (small enough to vendor? one big consumer who should adopt? maintained successor exists?) and what the recommended action is. See `remediation.md` for the full taxonomy.

    ruby dependents.rb --ecosystem rubygems   # top-N dependent packages, top1/top5 concentration, transit_ratio
    ruby size.rb       --ecosystem rubygems   # shallow clone, brief + scc, README deprecation grep
    ruby situate.rb                           # heuristic situation pre-fill from the above
    ruby llm.rb        --ecosystem rubygems   # claude -p with json-schema fills situation/remediation
    ruby tag.rb        --ecosystem rubygems   # export out/tag.csv for human review
    ruby tag.rb --import out/tag.csv          # write reviewed rows back
    ruby report.rb                            # adds out/remediation.{csv,json}

These follow the same pattern as the bucket pipeline: each script is idempotent, caches under `cache/<step>/`, takes an optional row limit, and skips `bucket='active'` by default. `--ecosystem NAME` restricts to one ecosystem; `--bucket NAME` targets a specific bucket (useful for spot-checking active repos for misclassification). `size.rb` needs `brief` and `scc` on PATH. `llm.rb` shells out to `claude -p` with a JSON schema, model overridable via `BERNIES_MODEL`. `dependents.rb` computes `transit_ratio` (sum of top-N dependents' downloads ÷ this package's downloads) as a direct-vs-transitive proxy, falling back to `dependent_repos_count` on registries without download data (go, maven, swiftpm).

Each row carries `remediation_source` (heuristic / llm / human) so downstream consumers can weight it. `situate.rb` won't overwrite llm or human rows; `llm.rb` won't overwrite human rows. The intended output is developer-facing guidance, so high-blast-radius packages should pass through `tag.rb` review before being published.

    ruby export_ecosystem.rb cargo            # per-ecosystem dead+dormant -> out/cargo-bernies.csv

## Database

Everything lands in `bernies.db` (sqlite, WAL mode):

  * `packages` — one row per critical package (purl). Registry, dependent counts, downloads, latest release, registry maintainers, dep-drift rollups, `top1_share`/`top5_share`/`transit_ratio`, `situation`/`remediation`/`alternative_purl`/`remediation_source`.
  * `repos` — one row per repository_url. Repo metadata, commit/issue stats, clone result, advisory rollups, bucket, signals, `code_loc`/`complexity`/`entry_points`/`has_native` from `size.rb`.
  * `advisories` — one row per (purl, advisory). Severity, CVSS, vulnerable range, first_patched_version, patched flag.
  * `dependencies` — one row per (purl, dep). Requirement, dep's current latest, majors_behind, runtime/dev kind.
  * `dependents` — one row per (purl, rank). Top-N dependent packages by downloads, with description.

Some queries:

    sqlite3 bernies.db "SELECT bucket, COUNT(*) FROM repos GROUP BY bucket"

    sqlite3 bernies.db "SELECT p.name, p.dependent_repos, r.days_since_release, r.active_maintainers_count
                        FROM packages p JOIN repos r USING (repository_url)
                        WHERE p.ecosystem='npm' AND r.bucket='dead'
                        ORDER BY p.dependent_repos DESC LIMIT 20"

    sqlite3 bernies.db "SELECT r.bucket, COUNT(*) FROM repos r
                        WHERE r.past_year_bot_prs > 0 AND r.past_year_prs_merged = 0
                        GROUP BY r.bucket"

## Output

  * `out/bernies.csv` — every dead or dormant repo ranked by `dependent_repos`, with all activity signals and advisory counts. An existing advisory means that one has already been hit; the rest are exposed to the same outcome the next time someone goes looking.
  * `out/dead.csv`, `out/dormant.csv` — per-bucket subsets with the same columns.
  * `out/unpatched.csv` — advisories with no `first_patched_version`, across all buckets.
  * `out/buckets-by-ecosystem.csv` — active/dormant/dead/unknown counts and dead% per ecosystem.
  * `out/remediation.csv`, `out/remediation.json` — every non-active package with `situation`, `remediation`, `alternative_purl`, `remediation_source`, `llm_confidence`, top dependent, code size and complexity.
  * `findings/<lang>.csv` — same columns as `remediation.csv`, one file per ecosystem alongside the writeup (e.g. `findings/ruby.csv` for rubygems).
  * `out/tag.csv` — review sheet from `tag.rb`; edit and reimport.
  * `out/<ecosystem>-bernies.csv` — per-ecosystem dead+dormant export from `export_ecosystem.rb`.

## First full run (Apr 2026)

8606 critical packages across 16 registries, 5874 distinct repos.

| bucket  | repos | share |
|---------|------:|------:|
| active  | 2864  | 48.8% |
| dormant | 1184  | 20.2% |
| dead    |  713  | 12.1% |
| unknown | 1113  | 18.9% |

117 advisories have no fixed release. The `unknown` 18.9% are repos so quiet that nobody has filed an issue or PR in a year, so the question hasn't been asked.

| ecosystem | repos | active | dormant | dead | unknown | dead % |
|-----------|------:|-------:|--------:|-----:|--------:|-------:|
| npm       | 1599  | 578    | 385     | 181  | 455     | 11.3   |
| rubygems  |  683  | 347    | 158     |  74  | 104     | 10.8   |
| cargo     |  580  | 365    |  95     |  69  |  51     | 11.9   |
| packagist |  547  | 380    |  62     |  66  |  39     | 12.1   |
| go        |  530  | 188    | 122     | 107  | 113     | 20.2   |
| pypi      |  458  | 335    |  73     |  37  |  13     |  8.1   |
| hackage   |  396  | 100    | 105     |  69  | 122     | 17.4   |
| maven     |  370  | 234    |  36     |  27  |  73     |  7.3   |
| conda     |  302  | 202    |  53     |  12  |  35     |  4.0   |
| julia     |  173  |  34    |  34     |  37  |  68     | 21.4   |
| hex       |  153  |  73    |  35     |  17  |  28     | 11.1   |
| swiftpm   |   97  |  57    |  31     |   8  |   1     |  8.2   |
| nuget     |   74  |  58    |   6     |   8  |   2     | 10.8   |
| cocoapods |   51  |  23    |  12     |   6  |  10     | 11.8   |
| pub       |   36  |  30    |   3     |   2  |   1     |  5.6   |
| cpan      |   10  |   5    |   2     |   3  |   0     | 30.0   |

Repos appear under every ecosystem they publish to, so the column totals exceed 5874.

See `notes.md` for caveats and signal definitions, `remediation.md` for the situation/remediation taxonomy, [`findings/`](findings/) for per-ecosystem remediation writeups (rubygems is `findings/ruby.md`), [`owners/`](owners/) for the maintainer-and-organisation analysis (who owns the bernies, are they still around, what the funding picture looks like), and `todo.md` for what's next.

## Data sources

  * packages.ecosyste.ms — critical packages, dependent counts, downloads, latest release, registry maintainers
  * repos.ecosyste.ms — fresh pushed_at / archived / status
  * commits.ecosyste.ms — total and past-year commit/committer counts, bot split, dds
  * issues.ecosyste.ms — issue/PR counts, time-to-close, past-year closed/merged, `active_maintainers`
  * advisories.ecosyste.ms — per-package advisories with `first_patched_version`
  * git — shallow clone for the default-branch HEAD commit date and for `brief`/`scc` codebase metrics
  * `claude -p` — situation/remediation classification with structured output
