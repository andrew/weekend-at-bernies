# non-active pypi packages: shape and remediation (May 2026)

123 critical PyPI packages whose repos are not actively maintained, across 123 repos. PyPI has the lowest non-active share of any large registry: 8.1% dead and 27% non-active overall, against 20.2% / 65% for Go and 10.8% / 49% for rubygems. All 123 classified; human review pending.

| bucket | n | meaning |
|---|---:|---|
| dormant | 73 | no maintainer activity in a year, but no evidence they've left |
| dead | 37 | archived, or people have knocked and nobody answered |
| unknown | 13 | too quiet to tell; nobody has filed anything to test responsiveness |

## summary

PyPI's small non-active set is itself the headline. The critical-package list for PyPI is 523, similar to cargo (813) and packagist (548), but only a quarter of those are non-active where rubygems sits at half and Go at two-thirds. Part of that is selection (PyPI's critical set skews toward large, institutionally-maintained projects: numpy, pandas, requests, the AWS and Google SDKs), and part is that Python's standard library absorbs the micro-utility layer that goes unmaintained in npm and rubygems.

| remediation | n | % | go % | rubygems % | meaning |
|---|---:|---:|---:|---:|---|
| accept | 48 | 39% | 41% | 50% | keep it, pin the version, carry the risk; no good exit exists |
| switch | 35 | 28% | 32% | 19% | move to a named, maintained successor |
| vendor | 25 | 20% | 21% | 27% | copy the source into your tree and drop the dependency; you now own it |
| switch-piecemeal | 10 | 8% | 4% | 1% | replace the slice you use with two or three smaller packages |
| adopt | 5 | 4% | 1% | 2% | take over maintenance |

| situation | n | % | go % | rubygems % | meaning |
|---|---:|---:|---:|---:|---|
| broad | 64 | 52% | 56% | 19% | many small dependents, no obvious steward |
| few-large | 29 | 24% | 20% | 60% | a handful of large dependents account for most usage |
| kitchen-sink | 12 | 10% | 9% | <1% | large surface, dependents use a slice, several replacements needed |
| inlineable | 8 | 7% | 7% | 14% | small enough that copying the code in is mechanically easy |
| alternative | 5 | 4% | 7% | 4% | a maintained drop-in replacement exists |
| no-alternative | 5 | 4% | 1% | 2% | fills a niche nothing else covers |

PyPI has the lowest accept share and the highest switch-piecemeal and adopt shares of the three. The accept gap vs rubygems (39% vs 50%) is mostly because more PyPI packages have a named exit; the piecemeal share reflects larger, multi-purpose libraries.

## almost nothing is tiny

Of 123 repos measured, only 5 (4%) are under 300 lines and 46 (37%) are over 3,000. Mean is 6,930 lines.

| size | pypi | go | rubygems |
|---|---:|---:|---:|
| under 300 lines | 5 (4%) | 33 (10%) | 134 (41%) |
| 300–3,000 | 72 (59%) | 185 (55%) | 160 (49%) |
| 3,000+ | 46 (37%) | 119 (35%) | 35 (11%) |

3 (2%) carry C extensions. The micro-package layer that makes up two-fifths of rubygems' non-active set barely exists here; Python's stdlib covers most of what those would do, and what does get packaged tends to be a real library. Vendoring is mechanically possible for almost none of these.

## usage concentration

Of 120 packages with concentration data, 23 (19%) have a single dependent at ≥90% of downstream downloads and 71 (59%) have one above 50%. That 59% is a touch higher than rubygems' 53%.

  * `text-unidecode` → python-slugify (100%)
  * `pure-eval` → stack-data (100%)
  * `pexpect` → jupyter-console (98%)
  * `mypy-extensions` → typing-inspect (95%)

A couple of the ≥90% rows look suspect (`defusedxml` and `sniffio` showing one obscure dependent at 97%+ when both have well-known major consumers), so the top-dependent data for PyPI needs spot-checking before leaning on it.

The direct-vs-transitive split is 115 direct / 7 mixed / 0 transitive, which is wildly different from rubygems and probably reflects how PyPI download counts are recorded rather than a real structural difference. Treat as unreliable until cross-checked.

## explicit end-of-life

17 repos (14%) are archived and 25 (20%) have a deprecation notice in the README or manifest, between rubygems (8% archived) and Go (18%).

## named successors

27 of 123 have a named successor. Official handoffs and absorbed-upstream cases:

  * `toml` → tomli (and `tomllib` in stdlib from 3.11)
  * `appdirs` → platformdirs
  * `entrypoints` → importlib.metadata
  * `oauth2client` → google-auth
  * `adal` → msal
  * `msrestazure` → azure-mgmt-core
  * `applicationinsights` → azure-monitor-opentelemetry
  * `asynctest` → pytest-asyncio
  * `commonmark` → markdown-it-py
  * `text-unidecode` → unidecode
  * `sqlalchemy-jsonfield` → sqlalchemy
  * `rsa`, `oscrypto` → cryptography

Editorial; maintained alternatives in the same space:

  * `backoff`, `retry` → tenacity
  * `requests-oauthlib`, `flask-jwt-extended` → authlib
  * `semver` → packaging
  * `dataclasses-json` → pydantic
  * `alabaster` → furo
  * `pandocfilters` → panflute

Wrong: `google-auth` → google-cloud-python (google-auth is actively maintained; the bucket assignment is likely the error), `h11` → httpcore (httpcore depends on h11), `pytest-runner` → tox (different purpose), `google-pasta` → libcst (different purpose), `msal-extensions` → keyring (different purpose).

## open questions

Why PyPI's non-active share is so much lower than the others: stdlib coverage absorbing the utility layer, the critical-set selection skewing toward funded projects, or genuinely better maintainer retention. And whether the direct/transitive numbers are an artefact of how PyPI reports downloads or a real difference in dependency-tree depth.
