---
name: bernie-check
description: Assess whether a given repository is a "bernie", a package that is still depended on but no longer actively maintained, and produce a remediation recommendation covering maintainer state and security posture. Use when reviewing a dependency, auditing a project's risk, or evaluating an open-source library before adopting it.
---

# bernie-check

Tell whether a repository is a bernie (effectively unmaintained, still propped up in production) and what a dependent should do about it. Pulls fresh data from ecosyste.ms and the OSSF Scorecard API; does not depend on any local database.

A bernie classification by itself is not the answer. The remediation a dependent should take depends on who owns the package, whether that owner is still around, what the package's shape is, and what the project's published security posture looks like. This skill bundles all of those into one assessment.

## Inputs

Either a repository URL passed as argument, or auto-detect from the current git working directory's `origin` remote.

```bash
# Explicit
TARGET="https://github.com/foo/bar"

# Auto-detect (run from inside a git repo)
TARGET=$(git remote get-url origin 2>/dev/null | sed -E 's#^git@github.com:#https://github.com/#; s#\.git$##')
```

Bail out early if the URL can't be derived or isn't a recognised git host. ecosyste.ms covers github.com, gitlab.com, bitbucket.org, gitlab.gnome.org, codeberg.org and several smaller hosts; non-github hosts may have thinner data.

Extract `OWNER` and `REPO` for later GitHub-specific calls:

```bash
read -r HOST OWNER REPO <<<"$(echo "$TARGET" | sed -E 's#^https?://##' | awk -F'/' '{print $1, $2, $3}')"
```

## Step 1: Fetch core data

All ecosyste.ms endpoints return JSON. Use curl with `-L` (the `/lookup` endpoints return 302 redirects to the canonical resource path) and a User-Agent that includes a contact email (ecosyste.ms asks for this in their TOS).

```bash
UA='bernie-check (your-contact@example.com)'

# Repository metadata (status, archived, pushed_at, metadata.files map, scorecard, owner_url)
REPO_JSON=$(curl -sLH "User-Agent: $UA" \
  "https://repos.ecosyste.ms/api/v1/repositories/lookup?url=$TARGET")

# Commit stats (note the field name is past_year_total_commits, not past_year_commits)
COMMITS_JSON=$(curl -sLH "User-Agent: $UA" \
  "https://commits.ecosyste.ms/api/v1/repositories/lookup?url=$TARGET")

# Issue/PR stats (active_maintainers is an array; take .size for the count)
ISSUES_JSON=$(curl -sLH "User-Agent: $UA" \
  "https://issues.ecosyste.ms/api/v1/repositories/lookup?url=$TARGET")

# Packages published from this repo (returns an array, one row per registry+name)
PACKAGES_JSON=$(curl -sLH "User-Agent: $UA" \
  "https://packages.ecosyste.ms/api/v1/packages/lookup?repository_url=$TARGET")
```

A 404 or empty body on any of these means the service hasn't indexed this repo yet. Fall back to whatever signals you have; do not treat absence as evidence of inactivity. Trigger a re-sync by hitting the `/lookup` endpoint once, ecosyste.ms processes the queue asynchronously, so a re-run in a day or two may fill in the gap.

## Step 2: Classify the repo

Apply the same logic as the local classify.rb. Thresholds:

  * `ACTIVE_COMMITS_PER_YEAR = 12`: twelve human commits in the past year is the floor for "active"
  * `STALE_RELEASE_DAYS = 365`: a release within the last year keeps the repo "active" regardless of commit count

Compute these fields from the responses (exact field names):

  * `days_since_release`: from `MAX(packages[].latest_release_at)` in `PACKAGES_JSON`, or fall back to `repo.pushed_at`
  * `days_since_push`: from `repo.pushed_at`
  * `human_commits`: `commits.past_year_total_commits - commits.past_year_total_bot_commits`
  * `active_maint`: `issues.active_maintainers.size` (the field is an array, not a count)
  * `closed`: `issues.past_year_issues_closed_count + issues.past_year_pull_requests_closed_count`
  * `merged`: `issues.past_year_merged_pull_requests_count`
  * `asked`: true if `issues.past_year_issues_count + issues.past_year_pull_requests_count > 0`
  * `archived`: `repo.archived == true`

Decision:

```
if repo.archived:
  bucket = "dead"
elif asked and no signs of life (no commits, no closes, no merges, no recent release):
  bucket = "dead"          # someone knocked, nobody answered
elif any signs of life:
  if human_commits >= 12 OR recent release:
    bucket = "active"
  else:
    bucket = "dormant"
elif recent commit OR recent push:
  bucket = "active"
else:
  bucket = "unknown"       # nothing happened either way; quiet but untested
```

Record the signals that drove the decision so the call can be argued over: `archived`, `commit:Nd`, `release:Nd`, `commits:N`, `active_maint:N`, `closed:N`, `merged:N`. The classifier is permissive: zero commits alone is never sufficient to call something "dead". You need evidence that someone tried to engage and nobody responded.

A repo is a **bernie** if `bucket in ("dead", "dormant")`. If the bucket is `active` or `unknown`, stop here and report accordingly: active means no remediation needed; unknown means there's not enough data yet.

## Step 3: Owner state (only for bernies)

Pull the owner record and decide whether you're looking at an individual or an org. The action paths diverge.

```bash
OWNER_URL=$(echo "$REPO_JSON" | ruby -rjson -e 'puts JSON.parse(STDIN.read)["owner_url"]')
OWNER_JSON=$(curl -sLH "User-Agent: $UA" "$OWNER_URL")
KIND=$(echo "$OWNER_JSON" | ruby -rjson -e 'puts JSON.parse(STDIN.read)["kind"]')   # "user" or "organization"
```

Also note `funding_links` (array) from the owner record. A funding setup combined with a bernie sub-package is a meaningful pressure point: sponsors have a credible lever to ask for archiving, handoff, or a release cadence.

### Individual owner

```bash
# Currently engaged in maintenance anywhere?
AUTHOR=$(curl -sLH "User-Agent: $UA" \
  "https://issues.ecosyste.ms/api/v1/hosts/GitHub/authors/$OWNER")
ACTIVE_MAINT_COUNT=$(echo "$AUTHOR" | ruby -rjson -e 'puts JSON.parse(STDIN.read)["active_maintaining"].size')

# Recent push activity across all their repos
RECENT=$(curl -sLH "User-Agent: $UA" \
  "https://repos.ecosyste.ms/api/v1/hosts/GitHub/owners/$OWNER/repositories?sort=pushed_at&order=desc&per_page=30")
```

Classify into one of:

  * **engaged**: `active_maintaining.size > 0` OR any push in last 30 days
  * **trickling**: push in last year but no active maintaining
  * **quiet**: last push 1 to 3 years ago
  * **gone**: no push in 3+ years AND no active maintaining

Counts of repos pushed in the last 30 / 365 days from the `RECENT` array are useful supplementary signals.

### Organisation owner

```bash
# Bus factor and active maintainer count for the org
MAINT=$(curl -sLH "User-Agent: $UA" \
  "https://issues.ecosyste.ms/api/v1/hosts/GitHub/owners/$OWNER/maintainers")
# Same recent-push call as above
RECENT=$(curl -sLH "User-Agent: $UA" \
  "https://repos.ecosyste.ms/api/v1/hosts/GitHub/owners/$OWNER/repositories?sort=pushed_at&order=desc&per_page=30")
```

Exclude bots (`renovate-bot`, `dependabot[bot]`, `modular-magician`, anything matching `/\[bot\]$/` or `/-bot$/`) when judging "active maintainers." A corporate org whose top maintainer is renovate-bot looks healthier than it is.

Compute:

  * `hist_maint`: `maintainers.size`
  * `active_maint`: `active_maintainers.size`, then subtract bots
  * `top1_share`: `maintainers[0].count / sum(maintainers[].count)`
  * `top_maintainer`: `maintainers[0].maintainer`

Classify into one of:

  * **active distributed**: `active_maint >= 5`, top1_share < 0.6
  * **active small team**: `active_maint` 1 to 4, top1_share < 0.6
  * **single-person umbrella**: `active_maint >= 1` AND `top1_share >= 0.6`, OR (`active_maint = 0` AND top1_share high AND any recent push). The org name is a stand-in for one individual.
  * **push-only**: `active_maint = 0` AND recent push activity exists. Someone is pushing without merging community PRs or addressing issues.
  * **trickling / wound down**: `active_maint = 0`, no recent pushes. Likely abandoned or migrated.

For wound-down orgs, check if a successor account is named in the readme, description or pinned issue. Common patterns: `zendframework → laminas`, `javaee → eclipse-ee4j`, `sensiolabs → symfony`, `gorilla → gorilla/* under a new org`, `opentracing → opentelemetry`.

## Step 4: Security posture

Pull whatever is publicly verifiable. Items requiring admin/write access to the repo (private vulnerability reporting toggle, secret scanning, push protection) cannot be checked externally; flag them as "unknown without admin access" rather than guessing.

### OSSF Scorecard

Fetch directly from the OSSF API. repos.ecosyste.ms does carry a `scorecard` field but it can be months out of date; the OSSF API serves the latest scorecard run.

```bash
SCORECARD=$(curl -sL "https://api.securityscorecards.dev/projects/github.com/$OWNER/$REPO")
echo "$SCORECARD" | ruby -rjson -e '
  d = JSON.parse(STDIN.read)
  if d["score"]
    puts "score: #{d["score"]}  (run #{d["date"]})"
    (d["checks"] || []).each { |c| puts "  #{c["name"]}: #{c["score"]}" }
  else
    puts "no scorecard: #{d["message"] || "unscored"}"
  end
'
```

The per-check breakdown is more diagnostic than the aggregate. Pay particular attention to:

  * `Maintained`: Scorecard's own freshness check; corroborates the bernie classification
  * `Vulnerabilities`: open advisories with no patched release
  * `Branch-Protection`: whether main is protected against direct push
  * `Pinned-Dependencies`: whether the project's own deps are pinned
  * `Token-Permissions`: whether CI tokens have minimal scope
  * `Security-Policy`: presence of SECURITY.md or similar

Score of -1 on a check means "inconclusive" or "not applicable" rather than a failure. A 404 on the scorecard API means the project hasn't been scored; report as "no Scorecard available" rather than treating it as a bad signal.

### Published security files

The repos.ecosyste.ms response has a `metadata.files` map. Check:

  * `security`: points to `SECURITY.md` filename if present. A good `SECURITY.md` includes a reporting address or a link to GitHub's private security advisory flow.
  * `threat_model`: points to `THREAT_MODEL.md` or similar. Rare; absence is normal.
  * `codeowners`: `CODEOWNERS` file, which says who reviews what
  * `governance`: explicit governance doc, common in larger projects
  * `license`: should not be null

If `files.security` is null, double-check by fetching the raw file directly (ecosyste.ms's file detection isn't perfect):

```bash
curl -sI "https://raw.githubusercontent.com/$OWNER/$REPO/HEAD/SECURITY.md" \
  | head -1 | grep -q '200' && echo "SECURITY.md exists" || echo "no SECURITY.md"
```

### GitHub Private Vulnerability Reporting

GitHub publishes the PVR status on a dedicated public endpoint. Use `gh api`:

```bash
gh api "repos/$OWNER/$REPO/private-vulnerability-reporting" 2>/dev/null
# Possible responses:
#   {"enabled": true}   PVR accepts reports from outside the project
#   {"enabled": false}  PVR is off; report-by-issue or contact via SECURITY.md
#   HTTP 422            archived or private repo; PVR not applicable
```

PVR being off on a maintained project is itself a finding worth surfacing in the report: it forces vulnerability reporters into public issues or maintainer email, which is worse for both sides. PVR off on an archived repo is unremarkable.

If SECURITY.md exists, also note whether it describes a private reporting path (email, security@, hackerone), since that's the human-readable equivalent.

### Published advisories

The advisories.ecosyste.ms service has per-package advisory history. For each package backing this repo (from `PACKAGES_JSON`):

```bash
for PKG in $(echo "$PACKAGES_JSON" | ruby -rjson -e 'JSON.parse(STDIN.read).each { |p| puts "#{p["ecosystem"]}|#{p["name"]}" }'); do
  ECO=${PKG%|*}; NAME=${PKG#*|}
  curl -sLH "User-Agent: $UA" \
    "https://advisories.ecosyste.ms/api/v1/advisories?ecosystem=$ECO&package_name=$NAME&per_page=100"
done
```

For each advisory check `first_patched_version`. An advisory with no patched version is the worst case for a bernie: a known vulnerability with no fix and nobody to ship one. Zero published advisories does not mean the package is safe; it means nobody has looked.

## Step 5: Recommend a remediation

Map the package's shape and the owner's state to one of the actions from the bernies project's findings taxonomy:

  * **accept**: pin the version, carry the risk. No good exit exists. Defensible when the owner is an active distributed org (they can still ship a security fix), or when no maintained successor is available and the package is too large to vendor.
  * **vendor**: copy the source into your project, drop the dependency. Works best for small packages (`code_loc < 300`) and when the owner is gone or a single-person umbrella with no successor. Removes supply-chain exposure; you now own the code.
  * **switch**: move to a named maintained successor. Forced and unambiguous for migrated orgs (zendframework → laminas, etc). Also fits when an obvious replacement exists in the ecosystem.
  * **switch-piecemeal**: replace the slice you use with two or three smaller packages. Common for kitchen-sink libraries where most dependents use one corner.
  * **adopt**: take over maintenance. Realistic only when the dependent has the resources, or when a single-person umbrella owner is willing to transfer.

Decision sketch, given the data:

| owner / package state | likely action |
|---|---|
| migrated or wound-down org with named successor | switch |
| active distributed org with bernie sub-package | accept (org can still ship a fix); raise a security issue if there's an unpatched advisory |
| single-person umbrella, owner engaged, has funding link | accept-with-watch, or adopt if you're a major consumer; sponsor pressure is available |
| single-person umbrella, owner gone | vendor (if small) or community-fork-adopt; archive risk is high |
| gone individual, small package | vendor |
| gone individual, large package, no alternative | accept (pin); track for advisories |
| kitchen-sink with named replacements | switch-piecemeal |
| you are the dominant consumer (>50% of downloads) | adopt |

## Step 6: Produce the report

A concise human-readable summary, suitable for pasting into a security review or dependency audit. Suggested shape:

```
# Bernie assessment: <owner>/<repo>

Bucket: <active | dormant | dead | unknown>
  Signals: <archived | commit:Nd | release:Nd | commits:N | active_maint:N | closed:N | merged:N>

Owner: <login> (<user|organisation>)
  Activity: <engaged | trickling | quiet | gone | active distributed | single-person umbrella | wound down>
  Funding: <github-sponsors | tidelift | none>
  Bus factor (orgs only): <hist_maint> historical maintainers, <active_maint> active humans, top <top1_share>

Security posture:
  OSSF Scorecard: <N.N> / 10  (or "not scored")
    Maintained: <score>
    Vulnerabilities: <score>
    Branch-Protection: <score>
    Pinned-Dependencies: <score>
    Token-Permissions: <score>
  SECURITY.md: <yes / no>
  Threat model: <yes / no>
  Private vulnerability reporting: <enabled / disabled / inconclusive>
  Unpatched advisories: <N>

Recommended remediation: <accept | vendor | switch | switch-piecemeal | adopt>
  Reasoning: <one or two sentences tying the owner state, package shape and security posture to the action>
  Alternative successor (if any): <pkg>
  Contact path: <github issue | maintainer email | none>
```

Keep the report under one screen. The user is reviewing many dependencies; they need to scan, not read.

## What this skill does not do

  * **It does not score severity.** A bernie classification and a list of unpatched advisories is data, not a risk score. The user is in a better position to weight what matters for their use case.
  * **It does not propose a successor unless one is named in the data.** The findings/ writeups in the bernies project name successors for common cases; for everything else, vendor / accept / switch require the user to confirm what the right replacement is.
  * **It does not run against many repos at once.** This is a per-repo skill. For a dependency-tree-wide assessment, run it across each dependency and aggregate the results.
  * **It does not check signals that need admin access on the target repo** (secret scanning toggle, push protection, branch protection rules beyond what Scorecard infers, dependency review enforcement). These are not visible without write access; if they matter for your audit, ask the project owner.
