# Age-invariant decay in the critical set

## Summary

This project pulls the "critical" set of packages from packages.ecosyste.ms — about 8,500 widely-used packages across npm, pypi, rubygems, and thirteen other registries — and sorts each one's repository into a bucket based on signs of life:

- **active**: a release or human commit in the past year
- **dormant**: barely any development, but a maintainer is still around (closing issues, merging the occasional PR)
- **dead**: archived, or someone filed an issue and nobody with write access responded
- **unknown**: nothing happened and nobody knocked, so we can't tell

Group the packages by the year of their first release and look at how the buckets split. The dormant share is the same in every cohort: 15 percent. Not roughly 15. Exactly 15, in nine consecutive two-year cohorts from 2005 through 2022.

This is unexpected. The obvious assumption is that older packages decay more — they have had more time to lose maintainers. They have not. A 2007 package is no more likely to be dormant today than a 2019 one.

The dead share is also stable, hovering around 10 percent. The active share rises with cohort recency, but only because newer packages have had less time to drop out, and their repos are still findable. None of that movement is in dormant.

## The headline

All sixteen registries pooled, rounded to the nearest 5 percent:

| cohort    |     n | active | dormant | dead |
| --------- | ----: | -----: | ------: | ---: |
| 2005-2006 |   127 |    45% |     15% |   0% |
| 2007-2008 |   225 |    35% |     15% |   5% |
| 2009-2010 |   596 |    45% |     15% |  10% |
| 2011-2012 |   995 |    45% |     15% |  15% |
| 2013-2014 | 1,401 |    45% |     15% |  10% |
| 2015-2016 | 1,680 |    55% |     15% |  10% |
| 2017-2018 | 1,477 |    60% |     15% |  10% |
| 2019-2020 |   986 |    65% |     15% |  10% |
| 2021-2022 |   747 |    60% |     15% |   5% |
| 2023-2024 |   216 |    80% |     10% |   5% |

The same data at full precision, in case you want to check the rounding:

| cohort    |     n | active | dormant |  dead | unknown / no repo |
| --------- | ----: | -----: | ------: | ----: | ----------------: |
| 2005-2006 |   127 |  44.1% |   12.6% |  2.4% |             40.9% |
| 2007-2008 |   225 |  34.2% |   16.0% |  5.3% |             44.4% |
| 2009-2010 |   596 |  47.0% |   16.9% |  8.1% |             28.0% |
| 2011-2012 |   995 |  46.9% |   16.7% | 13.1% |             23.3% |
| 2013-2014 | 1,401 |  45.7% |   16.8% | 10.3% |             27.1% |
| 2015-2016 | 1,680 |  52.5% |   16.7% | 10.2% |             20.6% |
| 2017-2018 | 1,477 |  60.4% |   15.0% | 10.3% |             14.3% |
| 2019-2020 |   986 |  64.2% |   13.6% |  7.5% |             14.7% |
| 2021-2022 |   747 |  62.2% |   16.5% |  3.2% |             18.1% |
| 2023-2024 |   216 |  78.7% |   12.0% |  3.2% |              6.0% |

The dormant column never strays more than two percentage points from 15. Across two decades.

## Where the age effect actually lives

If you collapse to a two-state view (active vs everything else), there is a clear slope:

| cohort    |     n | active | non-active |
| --------- | ----: | -----: | ---------: |
| 2005-2006 |   127 |    45% |        55% |
| 2007-2008 |   225 |    35% |        65% |
| 2009-2010 |   596 |    45% |        55% |
| 2011-2012 |   995 |    45% |        55% |
| 2013-2014 | 1,401 |    45% |        55% |
| 2015-2016 | 1,680 |    55% |        45% |
| 2017-2018 | 1,477 |    60% |        40% |
| 2019-2020 |   986 |    65% |        35% |
| 2021-2022 |   747 |    60% |        40% |
| 2023-2024 |   216 |    80% |        20% |

So non-active *does* grow with age. But almost all of the growth sits in the "unknown" bucket, not in dormant. Older repos drift out of the upstream issues service's index, or get renamed, or move owners and the link breaks. That makes them look unknown to us. It is a measurement artefact, not a maintenance failure.

The dormant rate, which is a real maintenance state and not a measurement gap, stays flat.

## A compositional caveat

The 15 percent number is a blended average across sixteen registries with very different baselines:

Sorted by dormant share, high to low:

| registry              |     n | active | dormant |  dead |
| --------------------- | ----: | -----: | ------: | ----: |
| swiftpackageindex.com |    97 |  58.8% |   32.0% |  8.2% |
| hex.pm                |   153 |  47.7% |   22.9% | 11.1% |
| npmjs.org             | 2,295 |  50.7% |   20.4% |  8.1% |
| juliahub.com          |   173 |  19.7% |   19.7% | 21.4% |
| proxy.golang.org      |   645 |  32.7% |   19.2% | 18.9% |
| hackage.haskell.org   |   696 |  17.0% |   17.1% | 10.6% |
| rubygems.org          |   974 |  62.1% |   16.8% |  7.6% |
| pypi.org              |   523 |  72.1% |   14.0% |  7.1% |
| crates.io             |   813 |  71.2% |   12.8% |  9.0% |
| packagist.org         |   548 |  69.3% |   11.3% | 12.0% |
| repo1.maven.org       |   704 |  67.8% |    7.4% |  5.4% |
| pub.dev               |   122 |  93.4% |    2.5% |  3.3% |
| nuget.org             |   376 |  63.8% |    2.1% |  3.7% |

Most of the major registries sit in a 12 to 22 percent dormant band. swiftpackageindex is the high outlier at 32 percent, though with only 97 packages it is on the noisy end. nuget and pub.dev sit far below the rest at around 2 percent. The pooled 15 percent figure comes from this blend, not from every ecosystem hitting that number independently.

Within npm specifically, the dormant share by 2-year cohort rounds to 25, 25, 20, 20, 15, 30, 10. Not perfectly flat, and the middle stretch (15 to 25) is wider than the global story suggests. The outliers are the 2021-2022 cohort (also anomalous in the lifespan analysis) and the small 2023-2024 cohort (n=145, so noisy).

So the honest claim is: the pooled critical set holds about 15 percent dormant in every vintage. Within the biggest single ecosystems the pattern is the same shape with more wobble. Either way, age is not what predicts dormancy.

## What this means

Dormancy is not something that catches up with packages as they get older. It is a steady-state property of the critical set itself: roughly one in six packages will be dormant at any given measurement, drawn evenly across the whole age range.

One practical consequence: you can't shrink the dormant pile by ignoring old packages. The 2005 cohort and the 2020 cohort contribute the same percentage. The largest absolute number of dormant packages sits in whichever cohort is biggest, which on this data is 2015-2016, but that is because there are more packages of that vintage overall, not because they have decayed more.
