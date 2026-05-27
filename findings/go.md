# non-active go modules: shape and remediation (May 2026)

360 critical Go modules whose repos are not actively maintained, across 342 repos. Go has the highest dead share of any large registry in the dataset (20.2% of repos vs 10.8% for rubygems and 11.3% for npm). Data collection in progress; this doc fills in as it lands.

| bucket | n | meaning |
|---|---:|---|
| dormant | 124 | no maintainer activity in a year, but no evidence they've left |
| dead | 122 | archived, or people have knocked and nobody answered |
| unknown | 114 | too quiet to tell; nobody has filed anything to test responsiveness |

Go differs from rubygems in ways that affect every section below. There are no download counts, so concentration and the direct/transitive split use `dependent_repos` instead (validated against rubygems at ~75% band agreement). Vendoring is a first-class workflow (`go mod vendor`, `replace` directives) so the mechanical cost of the `vendor` remediation is lower, though the maintenance burden is the same. Module paths are repo URLs, so a package going dead often means the import path itself is at risk if the repo is deleted, which has no rubygems equivalent.

## summary

(pending classification run)

## size and shape

(pending size.rb)

## usage concentration

(pending dependents.rb; using dependent_repos in place of downloads)

## what dependents should do

(pending llm.rb)

## direct vs transitive

(pending dependents.rb)

## open questions

Whether Go's higher dead share reflects something about the module ecosystem (low barrier to publishing, import-path coupling to repos that vanish) or about how `classify.rb` reads Go repos (fewer issues filed, so more land in `dead` on the no-response criterion). Worth comparing `signals` across ecosystems.
