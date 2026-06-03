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

| organisation | bernies | active | reading |
|---|---:|---:|---|
| sphinx-doc | 6 | 1 | the official Sphinx org; the bernies are old contrib extensions |
| googleapis | 6 | 17 | mostly old python client libs superseded by newer ones |
| pallets-eco | 5 | 3 | community-maintained Flask extensions, several handed-off |
| jupyter | 4 | 7 | several legacy notebook subprojects, the live work is elsewhere |
| pexpect | 2 | 0 | quiet but functional, low churn by design |
| requests | 2 | 0 | requests-oauthlib and friends, in stewardship mode |

The repeated pattern is a live parent org holding a few sub-projects that have aged out as the active codebase moved elsewhere: Sphinx's monorepo, googleapis' newer python-* clients, jupyter's split into jupyter-server and friends. None of them reads as abandonment in the way a quiet personal account does.

## individuals here are mostly low-count

41 individuals own pypi bernies and only one (xolox) holds more than two. Many of pypi's most-installed historical packages (requests, flask, jinja, numpy) appear here under org accounts (psf, pallets-eco, pydata, scipy) rather than personal ones, which keeps individual-owner concentration low even where a single author originally wrote the code.

## funding is less visible here

Only three pypi bernie-holders publish funding links of any kind: sphinx-doc, wolph, wbond. The funding-and-silence pattern that shows up on npm does not show up in the pypi data.

## what this means for outreach

The pypi bernie set is small enough to triage by hand. The org-owned cases each have a clear successor or stewardship path. The individual cases are mostly utility libraries with no obvious heir; the right move for a dependent is usually to vendor them or accept the pin. PSF or NumFOCUS adoption is theoretically available for packages large enough to matter, but the threshold is high.
