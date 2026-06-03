# commit-email domain takeover risk

For each individual bernie-holder on GitHub, we pulled every email address they've committed under (via `commits.ecosyste.ms /committers/{login}`), grouped by registrable domain, and classified each domain through RDAP with a brew-whois fallback. The question being answered: if a maintainer's email-recovery domain has lapsed or is about to, a future attacker who registers it could request a GitHub password reset and take over the account, including its push rights to any repos that depend on the bernies they own.

## what the data shows

622 distinct custom domains turn up in bernie-holders' commit history (excluding free webmail like gmail/outlook/icloud and GitHub's `@users.noreply.github.com`):

| classification | n |
|---|---:|
| active (registered, future expiry) | 564 |
| non-registrable (subdomains, machine hostnames, `.edu`, UUIDs) | 26 |
| unknown (TLD without RDAP coverage, whois inconclusive) | 30 |
| private (whois data redacted under privacy law) | 1 |
| **expired (in renewal grace period)** | **1** |

The expired one is `lddubeau.com` (Louis-Dominique Dubeau). Registry expiry date is today (2026-06-03), which puts the domain in the registrar's 30-day grace period. If it lapses without renewal, the domain enters redemption (a further 30 days) and then drops into the registry's pending-delete queue, opening for general registration about 70 days from today.

The stakes here are unusually high for what looks like a one-person account:

| package | dependent_repos | dependent_packages | downloads | bucket |
|---|---:|---:|---:|---|
| `saxes` | 1,780,495 | 540 | 240,147,032 | dead (archived) |
| `xmlchars` | 1,779,785 | 452 | 215,082,279 | dead (archived) |

`saxes` is the streaming XML/HTML parser sitting underneath jsdom, the DOM implementation used by Jest, Vitest, jest-environment-jsdom and most JS test runners that simulate a browser. `xmlchars` is its lower-level character-classification dependency. Together their footprint is comparable to express or lodash.

Both GitHub repos are archived, but archived isn't a hard barrier here. An attacker who acquires the GitHub account can unarchive at will, push new commits, cut new tags. The larger exposure is on npm: npm publishing rights are tied to the npm account's recovery email, not the GitHub one. If lddubeau's npm account uses the same `lddubeau.com` recovery, an attacker registering the domain after grace gets npm publish rights to both packages and can ship a malicious version directly to dependents on next `npm install`.

This is the only currently at-risk domain in the bernie data, and it happens to land under the largest npm-reach individual in the dataset.

## upcoming renewal calendar

Domains that are currently registered but expire in the next six months, where lapsed renewal would create the same risk as `lddubeau.com`. Most of these will be renewed as a matter of routine. The list is a watchlist, not a threat assessment.

| domain | expires | committer | notes |
|---|---|---|---|
| mysticatea.dev | 2026-06-26 | mysticatea | npm bernie-holder, 4 bernies, takes GitHub Sponsors |
| bholloway.com | 2026-07-01 | bholloway | one npm bernie |
| invenialabs.co.uk | 2026-07-02 | oxinabox | Julia community |
| jarvis.to | 2026-07-08 | leejarvis | one rubygems bernie |
| airnity.com | 2026-07-09 | ahamez | one hex bernie |
| danburkert.com | 2026-07-11 | danburkert | one cargo bernie |
| ferrous-systems.com | 2026-07-17 | japaric | Rust embedded community |
| djm.org.uk | 2026-07-17 | djm | one rubygems bernie |
| defuse.ca | 2026-07-18 | defuse | one packagist bernie |
| oxinabox.net | 2026-07-19 | oxinabox | Julia community |
| descolada.com | 2026-07-19 | samuel | socketry maintainer |
| xtuc.fr | 2026-07-15 | xtuc | npm bernie-holder, 16 bernies, 0 active |
| typeful.net | 2026-07-14 | sol | hspec maintainer |

Routine corporate or community renewals (datadoghq.com, ferrous-systems.com, lightspeedhq.com) appear in this window too but carry no realistic takeover risk; the renewal is somebody's job and stays on calendar.

## the methodology matters

An earlier pass through this data produced a false-positive list of 17 "available" domains, including some prominent maintainers (`webtun.org` for julienschmidt, author of go's httprouter; `dan.kubb.ca`; `apex.sh`). Every one of those was actually registered with a multi-year future expiry. Three things were going wrong:

1. **macOS system `whois` stops at the IANA referral** rather than chasing to the actual registry server, so most responses were the `.com` TLD record rather than the queried domain's record. The parser then misclassified the absence of registrar fields.
2. **`whois` output sometimes ends with `ERROR: domain not found:`** from a fallback referral chain even when the actual registry data was returned correctly above. A regex looking for "domain not found" anywhere in the response would mistake that trailing error for a real availability signal.
3. **Subdomains and machine hostnames in commit configs** (`alum.mit.edu`, `*.desk.hq.powerset.com`, `*.local`, UUIDs like `b2dd03c8-39d4-...`) are not registrable as standalone domains. Treating their unresolvable `whois` responses as "available" inflated the list.

Fixed by: switching to homebrew's rfc1036 whois (chases referrals properly), using RDAP for the structured-JSON path where TLDs support it, filtering out non-registrable patterns before any lookup, and ordering the parser to check expiry date before any "not found" text.

The corrected pipeline reduced the candidate count from 17 to 1. The naive answer was an order of magnitude too large.

## what we still can't see

The 30 unknown domains are all on ccTLDs where the rdap.org bootstrap returned 404 and the brew whois output didn't contain enough structured fields to classify:

  * European: `.li`, `.it`, `.nl`, `.uk`, `.ch`, `.es`, `.fi`
  * Asia-Pacific: `.jp`, `.co.jp`, `.pe`, `.mx`
  * Some second-level academic / hierarchical: `.ac.uk`, `.ucl.ac.uk`

These could be registered or available; the underlying registries either don't operate RDAP or restrict access. Closing this gap would mean wiring per-TLD whois server lookups (`whois -h whois.nic.uk` etc.) or fetching the per-TLD RDAP base from IANA's bootstrap file. Not done yet.

## what the SKILL flow should include

The bernie-check skill ([`../SKILL.md`](../SKILL.md)) currently assesses one repo at a time and produces a per-package remediation. It does not check the owner's commit-email domain status. Adding this would be a single endpoint per maintainer per repo, returning either "owner's recovery email domain is current," "expiring within N days," or "expired / available". The third state is the only one that changes a dependent's calculus, because it converts a sleeping-maintainer risk into an active-account-hijack risk.

For the docs taxonomy in [`../findings/README.md`](../findings/README.md), this slots in as an aggravating factor on otherwise-mild remediations: a package with a maintainer whose email domain has lapsed becomes a stronger candidate for **vendor** (remove the supply chain dependency entirely) or **switch** to a fork under a maintained account, regardless of the package's other shape signals.

## how to reproduce

  * `ruby emails.rb` pulls commit-email data per bernie-holding individual and classifies each domain via whois.
  * `ruby refetch_domain_status.rb` reclassifies the long tail via RDAP first, brew whois fallback, with non-registrable filtering.

Both cache responses under `cache/emails/`; re-runs are local-only. Schema in `commit_emails` (one row per `(login, email)`) and `email_domains` (one row per domain, with `whois_status`, `whois_expires_at`, `whois_registrar`, `status_source`).
