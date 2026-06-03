# rubygems owners

948 critical rubygems packages from 157 distinct owners.

| | organisation | individual | unknown |
|---|---:|---:|---:|
| owners | 65 | 81 | 11 |
| packages | 657 | 249 | 42 |
| non-active packages | 127 | 99 | 12 |
| non-active % | 19.3 | 39.8 | 28.6 |

The individual-to-organisation ratio on non-active rates is the highest of any major ecosystem.

## the org side is dominated by a few healthy stewards

The five biggest org owners are `rails`, `ruby`, `dry-rb`, `thoughtbot`, `fog`. The first four hold many currently active critical packages alongside a handful of non-active sub-libraries (`rails/journey`, `thoughtbot/clearance` and the like) that have been superseded internally and left published for backward compatibility.

fog is the exception, and its presence near the top of the list reflects a slow-motion winding down of the fog/* multi-cloud abstraction. The fog umbrella holds 11 non-active and 3 active critical packages. The org activity check shows 36 historical maintainers but only 2 currently active, with the top historical maintainer (plribeiro3000, 114 interactions) no longer engaged; the org is somewhere between a small active team and a winding-down organisation. Its provider plugins (fog-aws, fog-google, fog-azure) were once the canonical way for Ruby applications to talk to public clouds; vendor SDKs largely displaced them. The owner account has a GitHub Sponsors link active.

| organisation | bernies | active | reading |
|---|---:|---:|---|
| fog | 11 | 3 | winding down; vendor SDKs took the work |
| cocoapods | 9 | 0 | the Ruby tooling around Cocoapods; Apple-centric and quiet |
| ruby | 7 | 23 | ruby-core repos, mostly healthy |
| rails | 7 | 25 | mostly healthy; non-actives are superseded sub-libraries |
| savonrb | 6 | 0 | SOAP libraries, naturally low-churn |
| dry-rb | 5 | 4 | the dry-rb stack is being collapsed into one repo |
| thoughtbot | 4 | 5 | a few quiet older gems alongside live ones |

## the individual side is the long tail

81 individuals hold rubygems bernies and most hold one or two; only piotrmurach (six non-active packages and a GitHub Sponsors link) crosses a meaningful threshold. The pattern is breadth: many one-person gems with no co-maintainer and no release in over a year.

Activity check against ecosyste.ms's commit and issue data: 55 of these 81 individuals are currently engaged elsewhere on github, 14 trickling, 7 quiet, 5 gone. The 5 actually-gone (sstephenson, kattrali, mojombo, joshbuddy, roidrage) each hold a single bernie. piotrmurach himself classifies as engaged (last push 2026-05-17), so the cluster of six bernies under that account is about attention, not departure.

Ruby's packaging grew during a period (2007 to 2015) when one author per gem was the norm and active retirement (archiving, naming a successor) was uncommon. Most of those authors are still active on github in some form; the gems themselves are the part that went quiet.

## funding in this ecosystem is rare

Only six rubygems bernie-holders have funding links published on their owner account, and most are accounts that also hold currently active critical packages (thoughtbot, socketry). The exceptions:

  * `fog`: GitHub Sponsors active; the maintained packages and the sponsorship target are no longer well-aligned.
  * `piotrmurach`: six non-active critical packages, zero active in the critical set, GitHub Sponsors active. The pastel/tty-* command-line tools were once widely used; most see no commits in years.

## what this means for outreach

The Ruby community has institutional handoff mechanisms (the rubygems team, the trusted-gems list) that npm lacks, so the friction is mostly social: someone has to do the asking. For the long tail of individual-owned gems, the right action is usually a polite "is anyone still here, and would you accept a co-maintainer?" The org-owned cases are easier; fog, cocoapods and dry-rb each have clear routing for that question.

For the remediation taxonomy in [`../findings/README.md`](../findings/README.md), the rubygems owner picture argues for accept and vendor dominating. The typical bernie-holder here owns the bernie and nothing else currently active in our set, so outreach about adopt or switch has little anchor; the rubygems writeup in `findings/` already shows accept at 50% of recommended actions, the highest of any ecosystem, and the owner data is consistent with that. The handful of orgs that are still active (rails, ruby, dry-rb, thoughtbot) are the cases where outreach about retiring or handing off a specific sub-library is most likely to land.
