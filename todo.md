# todo

Operational companion to findings.md. That doc is for sharing; this one is for picking up where we left off.

## current rubygems run

  * `llm.rb --ecosystem rubygems` running in background (~76/343 at last check). When it finishes: `ruby situate.rb` (now guarded against overwriting llm/human rows), `ruby tag.rb --ecosystem rubygems`, then refresh the numbers in findings.md.
  * Verify the 17 `alternative_purl` values. `pkg:gem/sass-embedded-host-ruby` doesn't exist (real package is `sass-embedded`); `kaminari → pagy` and `redcarpet → kramdown` are alternatives not successors and probably should be `accept` with the alternative in notes. Quick check: `SELECT alternative_purl FROM packages WHERE alternative_purl IS NOT NULL` then look each up against `packages` or hit rubygems.org.
  * Active control sample: `ruby size.rb --ecosystem rubygems --bucket active 30 && ruby llm.rb --ecosystem rubygems --bucket active 30`. Any row with `eol_direct=1` or `remediation='switch'` is a `classify.rb` miss to feed back.

## pipeline

  * `dependents.rb` is slow at the head: ~2 min/call for packages with millions of dependents because `/dependent_packages?sort=downloads` sorts server-side. Took ~1h for 369 rubygems; full ~3.9k run will be a day. Either accept that (it's cached) or see if there's a cheaper sort.
  * `size.rb` README excerpt: `File.read(f, 4000, encoding: "UTF-8").scrub` triggers a JSON BINARY warning on some repos. Force-encode before generate.
  * First two `cache/size/*.json` entries (gethostname.rs, fflate) lack `readme` (field added mid-run). `rm` and re-run if they matter; they're not rubygems so currently don't.
  * ~~`situate.rb` deprecation regex~~ done: dropped from heuristics, LLM handles `alternative` and README-based `eol_direct`. `deprecation_text` stays as prompt context only.

## tuning

  * `BROAD_DEPENDENTS = 200` is too low for a critical-packages set (everything qualifies). With `top1_share` populated, reorder `situate.rb` so concentration rules fire before broad, and either raise the threshold to ~500 or make broad the explicit residual after the others.
  * `FEW_LARGE_TOP1 = 0.5` plus `dependent_packages < 20` only matched 7 rubygems; the `top1_share > 0.9` catch-all matched far more. Probably drop the `dependent_packages` cap entirely since concentration is the signal regardless of count.
  * `entry_points > 10 AND code_loc > 3000` matched 1 repo. Either kitchen-sink is genuinely rare in rubygems or the threshold is wrong; check which repo it was and a few of the 35 over-3000-LOC repos by hand.

## questions to answer with the data

  * `accept` ∩ unpatched: `SELECT name, remediation_notes FROM packages p JOIN repos r USING(repository_url) WHERE remediation='accept' AND r.unpatched_advisories_count > 0`. These are the rows where "pin and carry the risk" is already "carry a known vuln".
  * Concentration across ecosystems: once `dependents.rb` runs everywhere, `top1_share >= 0.5` rate per ecosystem. Hypothesis is npm > rubygems > maven/go.
  * Does `eol_direct` correlate with bucket? 55 rubygems are eol_direct; how many are in `active`? That's the misclassification rate.
  * For the 96 packages with `top1_share >= 0.9`, is the dominant dependent itself active? If `docile`'s only real consumer is simplecov and simplecov is dormant too, that changes the story.

## phase 2 (from remediation.md)

  * `alternatives.rb`: fork-graph check first, then category siblings. Would have caught the `sass-embedded-host-ruby` hallucination.
  * Migration-evidence signal: dependent-set overlap between this package's former dependents and candidate alternatives' current dependents.
  * `dead_transitive_count` beyond depth 1 needs the full closure, which means either recursing through ecosyste.ms or pulling the full dep graph.
