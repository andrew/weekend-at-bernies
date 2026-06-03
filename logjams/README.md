# logjams: bernies blocking updates from propagating

A logjam is an unmaintained package sitting between an actively-maintained dependency and the consumers above it. The dependency below ships new releases; the consumers above would pick them up; the dead package in the middle has a version requirement that nobody is around to bump. Updates pool behind it.

This matters most when the blocked update is a security fix. The fix exists, the maintainer who shipped it did their job, and it still can't reach most of the install base because the path runs through a package nobody can publish.

## identifying one

A package is a logjam if all of:

  * its repository is dead, dormant, or too quiet to tell
  * it declares one or more runtime dependencies
  * at least one of those declares a *bounded* version requirement (an upper limit: `^1.0`, `~> 1.0`, `< 2`, an exact pin) rather than an open one (`>= 1.0`, `*`)
  * the dependency's current latest major exceeds that bound
  * other packages depend on it (otherwise nothing is blocked)

The bounded-requirement check matters: `>= 1.0` is technically "behind" when the dep is at 5.0 but the resolver will still pick 5.0, so nothing is jammed. Only a requirement that excludes the newer version actually blocks it.

A stricter form adds: the blocked dependency is itself actively maintained, confirming updates are being produced below the jam rather than the whole chain being dead.

## what the data shows

Of 3,259 unmaintained critical packages with dependency data:

| | n | % |
|---|---:|---:|
| have any runtime dependencies | 1,516 | 47% |
| have at least one *bounded* runtime requirement | 1,310 | 40% |
| ...where the dep's latest major exceeds the bound | 471 | 14.5% |
| ...and have dependents above them (**blocking logjam**) | 458 | 14.1% |
| ...where the blocked dep is itself active | 352 | 10.8% |

About two-thirds of declared runtime requirements are bounded (`^`, `~`, `~>`, `<`, exact). The other third are open (`>=`, `*`), mostly in rubygems, conda, and pypi where open lower bounds are conventional. Filtering to bounded requirements drops the headline from a naive 18.7% to 14.1%.

By registry:

| | with runtime deps | blocking logjams | naive (any dep behind) |
|---|---:|---:|---:|
| npm | 491 | 171 | 171 |
| julia | 138 | 60 | 61 |
| hackage | 145 | 57 | 77 |
| packagist | 97 | 51 | 52 |
| rubygems | 188 | 43 | 121 |
| maven | 94 | 23 | 23 |
| go | 148 | 17 | 17 |
| hex | 32 | 14 | 15 |
| conda | 101 | 13 | 39 |
| swiftpm | 11 | 5 | 6 |
| pypi | 38 | 2 | 17 |

npm is unchanged because its default `^` is bounded. rubygems drops to a third of the naive count because so many gems declare `>= 0`. pypi nearly vanishes for the same reason. hackage holds up because Haskell's PVP convention encourages upper bounds. go's 17 are exact `v0.0.0-hash` pseudo-version pins, but go's minimum-version-selection resolver means a newer version elsewhere in the graph still wins, so a go "logjam" is softer than the same shape in npm or rubygems.

cargo and cocoapods are absent: their dependency data wasn't collected, so no claim either way.

## what this measurement misses

The bounded/open split above is a string-pattern heuristic. It treats any `^`, `~`, `~>`, `<`, or bare version as bounded and any `>=` or `*` as open, which is right most of the time but misses nuance: rubygems `~> 1.0` allows 1.x but `~> 1.0.0` only allows 1.0.x; cargo's bare `1.0` means `^1.0` not `=1.0`; python `!=` exclusions are open with holes. A proper answer would evaluate each requirement against the dep's latest version using that ecosystem's resolver rules. The inputs are recorded; the evaluation isn't.

A blocked major could also be a security fix, a breaking API change, or a version-number bump with no functional difference. We have advisory data per package, so "logjam where the blocked dep has a published advisory in a version the requirement excludes" is computable and would be the high-priority subset. Not yet computed.

A logjam only matters if consumers above it would otherwise get the update. If every consumer also pins the same old major for its own reasons, the bernie isn't the bottleneck. We have the top dependents for each bernie; checking whether *they* declare a compatible range on the same dep would show whether the bernie is the actual constraint.

## the useful subset

The 458 blocking logjams (bounded requirement excluding the dep's current major, consumers above) are the actionable list; the 352 where the blocked dep is itself active are the priority subset. For each, the remediation is the same as any other bernie (vendor, switch, adopt) but carries added urgency, because every release the blocked dependency ships widens the gap. The narrowest priority within the priority subset is the cases where the blocked dep has shipped a security fix since the bernie's last release.
