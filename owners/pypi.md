# pypi owners

500 critical pypi packages from 81 distinct owners.

| | organisation | individual | unknown |
|---|---:|---:|---:|
| owners | 38 | 41 | 2 |
| packages | 349 | 139 | 12 |
| non-active packages | 62 | 46 | 2 |
| non-active % | 17.8 | 33.1 | 16.7 |

Both rates are below the dataset average and the absolute count of bernies is small relative to npm's 644 and rubygems' 226. A higher share of packages here live under recognisable foundations and working groups (pallets-eco, jupyter, sphinx-doc, python, pydata, scikit-*) than in either of those two ecosystems.

## sphinx-doc is the largest concentration

| organisation | bernies | active | hist maint | active maint | reading |
|---|---:|---:|---:|---:|---|
| sphinx-doc | 6 | 1 | 9 | 4 | active small team; top maintainer holds 57% of historical activity |
| googleapis | 6 | 17 | 236 | 76 | active distributed; the bernies are old client libs superseded by newer ones |
| pallets-eco | 5 | 3 | 15 | 3 | active small team; community-maintained Flask extensions |
| jupyter | 4 | 7 | 53 | 13 | active distributed; several legacy notebook subprojects coexist with live work |
| pexpect | 2 | 0 | 3 | 1 | single-person org (takluyver, 50% share) |
| requests | 2 | 0 | 9 | 0 | wound down: 9 historical maintainers, none currently active |
| python-hyper | 3 | 0 | 13 | 0 | wound down: HTTP/2 work effectively superseded |

The org activity data is gentler than the bernie classification suggests for most pypi orgs. googleapis, jupyter and pallets-eco are all clearly active organisations whose bernies are sub-projects that aged out alongside the org's main work. The two wound-down rows (requests, python-hyper) match their public stories: the requests-oauthlib half of the requests org has not seen new maintenance, and python-hyper's HTTP/2 work has been superseded.

## individuals here are mostly low-count

41 individuals own pypi bernies and only one (xolox) holds more than two. Many of pypi's most-installed historical packages (requests, flask, jinja, numpy) appear here under org accounts (psf, pallets-eco, pydata, scipy) rather than personal ones, which keeps individual-owner concentration low even where a single author originally wrote the code.

Activity check: of those 41 individuals, 26 are engaged, 6 trickling, 9 quiet, 0 in the gone bucket. pypi is the only major ecosystem in this dataset where every bernie-holding individual still has recorded activity on github.

## funding is less visible here

Only three pypi bernie-holders publish funding links of any kind: sphinx-doc, wolph, wbond. The funding-and-silence pattern that shows up on npm does not show up in the pypi data.

## what this means for outreach

The pypi bernie set is small enough to triage by hand. The org-owned cases each have a clear successor or stewardship path. The individual cases are mostly utility libraries with no obvious heir; the right move for a dependent is usually to vendor them or accept the pin. PSF or NumFOCUS adoption is theoretically available for packages large enough to matter, but the threshold is high.

For the remediation taxonomy in [`../findings/README.md`](../findings/README.md), the pypi owner picture supports the existing distribution well. switch and switch-piecemeal both involve naming a successor and contacting the current owner: a higher share of pypi bernie-owners are also active on pypi (29 of 82) than in most other ecosystems, so those conversations are more likely to land. accept dominates for the long tail of small utility libraries owned by individuals who aren't currently active on anything else; vendor is constrained because pypi packages are commonly larger than npm or rubygems equivalents. PSF or NumFOCUS adoption is theoretically available but only justifies the overhead for packages large enough to warrant it.
