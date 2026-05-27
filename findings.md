# non-active rubygems: shape and remediation (May 2026)

343 critical rubygems packages whose repos are not actively maintained: 164 dormant (no maintainer activity in a year, but no evidence they've left), 74 dead (archived, or people have knocked and nobody answered), 105 unknown (too quiet to tell). For each: how big is it, who actually depends on it, has the maintainer pointed at a successor, and what should a dependent do. About a quarter classified so far, working from the most-depended-on down.

## most of them are tiny

Of 329 repos measured, 134 (41%) have under 300 lines in the source directory and 35 (11%) have over 3,000. Mean is 1,784 but the middle is sparse; the set is mostly small utilities plus a tail of large frameworks. 28 repos (9%) carry native code, several with under 50 lines of Ruby wrapping a C extension (`unf_ext`, `fast_blank`, `debug_inspector`), which look trivially small until you open `ext/`.

So for roughly four in ten of these, copying the code into your tree is a real option before you consider anything more involved.

## usage is concentrated, not broad

For 340 packages we have the top dependent packages by downloads. 96 of them (28%) have a single dependent accounting for at least 90% of downstream usage; 182 (53%) have one above 50%. Some are entirely captive:

  * `sass-listen` → sass (100%)
  * `websocket-extensions` → websocket-driver (100%)
  * `bindex` → web-console (100%)
  * `ruby_dep` → listen (99.7%)
  * `jmespath` → aws-sdk-core (99%)
  * `docile` → simplecov (98%)

Each of those is effectively a private dependency that happens to be published. The fix for `docile` going unmaintained is a conversation with simplecov, not with docile's 71 listed dependents. Only 64 packages (19%) have usage spread thinly enough that no single consumer could plausibly take it on.

This means a per-package recommendation is usually wrong for someone. The right answer for jmespath is "aws-sdk-core should adopt it"; the right answer for everyone else is "wait for aws-sdk-core to adopt it".

## explicit end-of-life

55 packages (16%) are explicitly retired: the repo is archived or the README says so. A further 22 (6%) have at least one direct runtime dependency that is itself dead or archived (the worst has four), so even adopting them means inheriting someone else's corpse.

## what dependents should do (highest-impact ~76, preliminary)

Of the most-depended-on quarter classified so far: 43 accept (pin and carry the risk), 18 switch, 13 vendor, 1 adopt, 1 piecemeal replacement. Accept dominates at the top because these are foundational packages where one consumer can't move alone; vendor and switch should grow further down the list.

The accept cases are mostly "done, not dead": `tzinfo`, `rack-test`, `builder`, `arel` are stable, narrow, and have nowhere left to go. Dormancy there reflects completion, not abandonment. The risk is that nobody is watching for the security report, not that the code is rotting.

17 packages have a clear named successor:

  * `mimemagic` → marcel
  * `libv8`, `therubyracer` → mini_racer
  * `webpacker` → jsbundling-rails
  * `turbolinks` → turbo-rails
  * `factory_girl_rails` → factory_bot_rails
  * `thread_safe` → concurrent-ruby
  * `webdrivers` → selenium-webdriver
  * `sass` → sassc → sassc-embedded
  * `rest-client` → faraday
  * `bootstrap-sass` → bootstrap
  * `database_cleaner` → database_cleaner-active_record
  * `rails-deprecated_sanitizer` → rails-html-sanitizer
  * `redcarpet` → kramdown
  * `kaminari` → pagy

The first dozen are uncontroversial. The last two are arguable: redcarpet and kaminari are dormant rather than dead, and their suggested replacements are alternatives rather than successors. Those need a human call.

## open questions

How many of the 43 "accept" cases also have an unpatched advisory, which turns "pin and carry the risk" into "pin and carry a known vulnerability". And whether the concentration pattern (53% with one dominant consumer) holds across other ecosystems or is a rubygems quirk; npm's micro-package culture suggests it'll be even more pronounced there.
