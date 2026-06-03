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

| individual | bernies | active | reading |
|---|---:|---:|---|
| vincenthz | 27 | 0 | Vincent Hanquez, historical author of the Haskell cryptography stack (cryptonite, x509, tls); no active critical packages on this account |
| ekmett | 16 | 20 | 20 currently active critical packages alongside the 16 bernies |
| snoyberg | 10 | 12 | 12 currently active critical packages; bernies are smaller satellites |
| ndmitchell | 5 | 3 | 3 active critical packages, 5 non-active |
| uweschmidt | 4 | 0 | older XML/JSON libraries (hxt era); no active critical packages on this account |

The vincenthz row is the highest-stakes one in the table because the Haskell cryptography stack sits underneath almost all Haskell TLS, x509 and hash work. 27 critical packages are non-active and none are active in the critical set. The Haskell Cryptography Group exists as a successor effort and has been forking the relevant repos; the migration is not complete and many downstream packages still resolve to the original.

## the org side is mostly community accounts

| organisation | bernies | active |
|---|---:|---:|
| haskell | 17 | 15 |
| fpco | 5 | 2 |
| hspec | 4 | 0 |

There is no equivalent in hackage to npm's big-company-with-many-active-repos pattern (no haskell-google, haskell-microsoft, etc); the org accounts here are community-shaped.

## funding is almost absent

Only one hackage bernie-holder publishes funding links: jgm (John MacFarlane, pandoc author), with 2 non-active hackage sub-packages and 1 active. There is no equivalent here to the npm pattern of high-bernie-count accounts drawing sponsorship.

## what this means for outreach

The Haskell community has a coordinated effort (the Haskell Cryptography Group, the Haskell Foundation's stewardship work) aimed at the vincenthz set specifically. For the rest of the non-active hackage packages, deciding whether outreach is worth the effort needs maintainer-side data the critical-package slice does not provide.
