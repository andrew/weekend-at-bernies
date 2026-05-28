# non-active rubygems: shape and remediation (May 2026)

343 critical rubygems packages whose repos are not actively maintained. For each: how big is it, who actually depends on it, has the maintainer pointed at a successor, and what should a dependent do.

| bucket | n | meaning |
|---|---:|---|
| dormant | 164 | no maintainer activity in a year, but no evidence they've left |
| unknown | 105 | too quiet to tell; nobody has filed anything to test responsiveness |
| dead | 74 | archived, or people have knocked and nobody answered |

## summary

Half of these packages (173) have no realistic exit for a typical dependent: the recommendation is to pin the version and accept that nobody is watching for the next security report. None of them has a *published* unpatched advisory today, but that reflects how little auditing dormant code gets, not how safe it is. A quarter (92) are small enough to copy into your own tree, which trades a supply-chain edge for owning the code and its bugs outright. 66 have a maintained successor to switch to, and for about a third of those the migration could be driven by convincing a handful of intermediary packages rather than thousands of end users.

Usage is far more concentrated than the dependent counts suggest. 53% of these packages have a single consumer accounting for over half of all downstream installs; 28% have one above 90%. In 50 of those cases the dominant consumer is a different organisation from the package's owner, which makes that consumer the de-facto maintainer whether or not they have accepted the role. fastlane, cocoapods and rails each hold several such captives.

| remediation | n | % | meaning |
|---|---:|---:|---|
| accept | 173 | 50% | keep it, pin the version, carry the risk; no good exit exists |
| vendor | 92 | 27% | copy the source into your tree and drop the dependency; you now own it |
| switch | 66 | 19% | move to a named, maintained successor |
| adopt | 7 | 2% | take over maintenance (you are, or should be, the primary consumer) |
| switch-piecemeal | 5 | 1% | replace the slice you use with two or three smaller packages |

| situation | n | % | meaning |
|---|---:|---:|---|
| few-large | 207 | 60% | a handful of large dependents account for most usage |
| broad | 66 | 19% | many small dependents, no obvious steward |
| inlineable | 48 | 14% | small enough that copying the code in is mechanically easy |
| alternative | 15 | 4% | a maintained drop-in replacement exists |
| no-alternative | 6 | 2% | fills a niche nothing else covers, often native or protocol code |
| kitchen-sink | 1 | <1% | large surface, dependents use a slice, several replacements needed |

## most of them are tiny

Of 329 repos measured, 134 (41%) have under 300 lines in the source directory and 35 (11%) have over 3,000. Mean is 1,784 but the middle is sparse; the set is mostly small utilities plus a tail of large frameworks. 28 repos (9%) carry native code, several with under 50 lines of Ruby wrapping a C extension (`unf_ext`, `fast_blank`, `debug_inspector`), which look trivially small until you open `ext/`. Small size makes vendoring mechanically easy but doesn't make it safe; whatever bugs are in those 300 lines come with them.

## usage is concentrated

For 340 packages we have the top dependent packages by downloads. 96 of them (28%) have a single dependent accounting for at least 90% of downstream usage; 182 (53%) have one above 50%. Some are entirely captive:

  * `sass-listen` → sass (100%)
  * `websocket-extensions` → websocket-driver (100%)
  * `bindex` → web-console (100%)
  * `ruby_dep` → listen (99.7%)
  * `jmespath` → aws-sdk-core (99%)
  * `docile` → simplecov (98%)

Each of those is effectively a private dependency that happens to be published. The fix for `docile` going unmaintained is a conversation with simplecov; docile's other 70 listed dependents are along for the ride. Only 64 packages (19%) have usage spread thinly enough that no single consumer could plausibly take it on. So a per-package recommendation is usually wrong for someone: jmespath's recommendation is really "aws-sdk-core should adopt it", and for everyone else it's "wait for them to".

Of the 96 packages where one dependent accounts for ≥90% of usage, 41 share a repo owner with that dependent (packaging splits like `kaminari-core`→kaminari, the seven `cocoapods-*` plugins, the thirteen `fog-*` providers; the parent project already owns them in every sense that matters). The other 50 are cross-org: an individual's repo that a large project now depends on entirely. Those 50 are the cases where the dominant consumer is the de-facto maintainer whether they've acknowledged it or not.

| consumer | captives held | from |
|---|---:|---|
| fastlane | 6 | `emoji_regex`, `simctl`, `word_wrap`, `tty-spinner`, `xcpretty-travis-formatter`, `security` |
| cocoapods | 4 | `cocoapods-deintegrate`, `atomos`, `fourflusher`, `fuzzy_match` |
| rails | 4 | `bindex`, `hike`, `rack-ssl`, `babel-transpiler` |
| devise | 2 | `warden`, `orm_adapter` |
| danger | 2 | `claide-plugins`, `no_proxy_fix` |

## explicit end-of-life

55 packages (16%) are explicitly retired: the repo is archived or the README says so. A further 22 (6%) have at least one direct runtime dependency that is itself dead or archived (the worst has four), so even adopting them means inheriting someone else's corpse.

## what dependents should do

Accept is half the set and skews to the top of the list: foundational packages where one consumer can't move alone (`tzinfo`, `rack-test`, `builder`, `arel`). The code is stable and narrow and has nowhere left to go. None of the 173 currently has a published unpatched advisory, which mostly tells you how little auditing dormant code receives. The dead-maintainer problem is that the absence of a CVE means nobody has gone looking yet; when somebody does, there is no maintainer to ship the fix, and automated vulnerability discovery is closing the gap between "nobody has looked" and "somebody has found something" much faster than the maintainer population is growing.

Vendor is a quarter of the set and lines up with the size finding: 41% of repos under 300 lines, most with no runtime deps. Vendoring removes the supply-chain edge (no registry account to compromise, no surprise releases) but it absorbs the code's existing problems into your tree along with the responsibility for fixing them, which is the maintenance burden you were outsourcing in the first place. It makes most sense when you can read every line you're copying, the licence permits it, and you'd be comfortable defending that code in your own review. For anything with native code or non-trivial parsing it's closer to adoption than to a quick fix.

51 packages have a named successor. The ones where the original maintainer or community has pointed at a replacement are solid:

  * `mimemagic` → marcel
  * `libv8`, `therubyracer` → mini_racer
  * `webpacker` → jsbundling-rails
  * `turbolinks` → turbo-rails
  * `factory_girl_rails` → factory_bot_rails
  * `thread_safe` → concurrent-ruby
  * `webdrivers` → selenium-webdriver
  * `sass` → sassc → sassc-embedded
  * `bootstrap-sass` → bootstrap
  * `database_cleaner` → database_cleaner-active_record
  * `rails-deprecated_sanitizer` → rails-html-sanitizer
  * `cocaine` → terrapin
  * `paperclip` → activestorage
  * `nokogumbo` → nokogiri
  * `sentry-raven` → sentry-ruby
  * `faraday_middleware` → faraday
  * `dry-equalizer` → dry-core
  * `celluloid-io` → async

A second tier are reasonable but editorial; the targets are maintained alternatives in the same space rather than designated successors, so switching is a judgement call:

  * `rest-client`, `httpclient`, `httpi` → faraday
  * `commander`, `gli` → thor
  * `yajl-ruby` → oj
  * `redcarpet` → kramdown
  * `kaminari` → pagy
  * `carrierwave` → shrine
  * `attr_encrypted` → lockbox
  * `delayed_job_active_record` → good_job

A handful are wrong and need correcting before publishing:

  * `premailer-rails` → bootstrap-email (different purpose)
  * `airbrake` → sentry-ruby (a competitor)
  * `fast_blank` → activesupport (fast_blank exists to be faster than that)
  * `validate_url` → addressable (a parser, doesn't validate)
  * `citrus` → toml (parser generator vs one parser)
  * `sassc-rails` → sass-embedded-host-ruby (doesn't exist)

## direct vs transitive: which ones can actually be removed

Comparing each package's downloads to the combined downloads of the packages that depend on it gives a rough split between direct use (someone typed it into a Gemfile) and transitive use (it arrives via something else):

| usage | n | % | with a named successor |
|---|---:|---:|---:|
| mostly transitive | 114 | 34% | 18 |
| mixed | 180 | 53% | 13 |
| mostly direct | 46 | 14% | 10 |

For anything with a named successor that split tells you how tractable removal is. The 18 transitive-dominated ones (`mimemagic`, `sass`, `thread_safe`, `therubyracer`, `rest-client`, `yajl-ruby`, `webdrivers`, `database_cleaner`, `httpclient`, ...) can realistically be drained from dependency trees by getting a handful of intermediary packages to switch; mimemagic→marcel already played out this way after the 2021 licence incident, when activestorage moved and most of the install base went with it. The 10 direct-dominated ones (`turbolinks`, `carrierwave`, `bootstrap-sass`, `sentry-raven`, `font-awesome-rails`, ...) are spread across thousands of legacy Rails Gemfiles and won't move without each app being touched, which mostly won't happen. The transitive-heavy set with a clear successor, ordered by which intermediaries need convincing, is where effort actually reduces exposure.

## open questions

Whether the concentration pattern (53% with one dominant consumer) and the direct/transitive split hold across other ecosystems or are a rubygems quirk. npm's micro-package culture suggests both will be more pronounced there; go's preference for vendoring and maven's deep enterprise trees may look quite different.
