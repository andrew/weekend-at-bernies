# hackage owners

422 critical hackage packages from 97 distinct owners.

| | organisation | individual | unknown |
|---|---:|---:|---:|
| owners | 27 | 66 | 4 |
| packages | 121 | 297 | 22 |
| non-active packages | 56 | 133 | 4 |
| non-active % | 46.3 | 44.8 | 18.2 |

Hackage is the only ecosystem where the org-vs-individual rates invert: organisation-owned packages are slightly more likely to be non-active than individual-owned ones. Both rates are also unusually high. Half of every Haskell critical package's repos look quiet, regardless of who owns them. Several structural events in the same period (the Stack/Cabal split, the `text`-into-base migration, the general shift of working Haskell into private company codebases) match the pattern in the data, but the dataset itself only carries the per-repo signals.

## the individual side

| individual | bernies | active in set | activity status | reading |
|---|---:|---:|---|---|
| vincenthz | 27 | 0 | trickling (10 pushes in last year, last push 2026-04-26) | historical author of the Haskell cryptography stack (cryptonite, x509, tls); still pushing to something, just not actively maintaining the critical packages |
| ekmett | 16 | 20 | engaged (3 push 30d, 34 push 365d) | 20 currently active critical packages alongside the 16 bernies |
| snoyberg | 10 | 12 | engaged (5 active_maint, 2 push 30d) | 12 currently active critical packages; bernies are smaller satellites |
| ndmitchell | 5 | 3 | engaged (1 push 30d, 9 push 365d) | 3 active critical packages, 5 non-active |
| uweschmidt | 4 | 0 | quiet | older XML/JSON libraries (hxt era); no recent activity recorded |

The vincenthz row is the highest-stakes one in the table because the Haskell cryptography stack sits underneath almost all Haskell TLS, x509 and hash work. The activity check refines the picture: ecosyste.ms records 10 pushes from him in the last year and his most recent push is just over a month ago, so the person is still on github even though none of the 27 critical haskell packages on the account have seen a release. The Haskell Cryptography Group exists as a successor effort and has been forking the relevant repos; the migration is not complete and many downstream packages still resolve to the original.

Across hackage's 66 bernie-holding individuals: 38 engaged, 21 trickling, 6 quiet, 1 gone. The trickling share (32%) is the highest of any major ecosystem here, which matches the broader pattern of Haskell maintainers continuing to commit but at a slower cadence than other ecosystems treat as active.

## the org side is mostly community accounts

| organisation | bernies | active in set | hist maint | active maint | reading |
|---|---:|---:|---:|---:|---|
| haskell | 17 | 15 | 275 | 76 | active distributed: 76 currently active human maintainers across the org |
| fpco | 5 | 2 | active | active | small team |
| hspec | 4 | 0 | 6 | 1 | single-person org dominated by sol (96% of historical activity) |

There is no equivalent in hackage to npm's big-company-with-many-active-repos pattern (no haskell-google, haskell-microsoft, etc). The community org accounts here have more distributed maintenance than the npm equivalents: the `haskell` org alone has 76 currently active human maintainers, which is on par with mid-sized corporate orgs in this dataset.

## funding is almost absent

Only one hackage bernie-holder publishes funding links: jgm (John MacFarlane, pandoc author), with 2 non-active hackage sub-packages and 1 active. There is no equivalent here to the npm pattern of high-bernie-count accounts drawing sponsorship.

## what this means for outreach

The Haskell community has a coordinated effort (the Haskell Cryptography Group, the Haskell Foundation's stewardship work) aimed at the vincenthz set specifically. The activity data shows vincenthz himself is still on github (trickling rather than gone), so contact is in principle possible even if his attention is elsewhere. For the rest of the non-active hackage packages most owners are similarly still around in some form: 38 of 66 are currently engaged on something, only 1 falls into the gone bucket on the activity check.

For the remediation taxonomy in [`../findings/README.md`](../findings/README.md), the hackage owner picture suggests accept and adopt dominate. Most hackage bernie-owners are not currently maintaining any other critical hackage package (75 of 97), so per-package switch outreach has limited reach; for the cryptography stack specifically the Haskell Cryptography Group is already coordinating the adopt-by-community route. Vendor is structurally awkward in Haskell because the language's library boundaries are deep in the type system and copy-paste rarely works; that pushes the recommendation back toward accept-and-pin for most packages without an organisational successor.
