# remediation taxonomy

`classify.rb` answers "is anyone home". The next layer is "what shape is this dependency and what should a dependent do about it". The output is guidance for developers who have one of these packages in their tree and need to decide what to do, so each recommendation needs a concrete action, a named alternative where one exists, and enough provenance that someone can disagree with it. Developed against rubygems non-active first (343 packages) since I can sanity-check those by hand, but the schema and scripts are ecosystem-neutral.

## situation

What shape the package is in from a dependent's point of view. One primary value per package, though some straddle.

  * **few-large**: a handful of big projects account for most of the usage. Adopt-a-highway territory; one of those dependents effectively owns it already. Signal: low `dependent_packages` (under ~20) but high `dependent_repos` or downloads, and the dependent list is top-heavy. Needs the actual dependent list from `/dependent_packages` to see concentration.
  * **broad**: thousands of small dependents, no obvious steward. Signal: high `dependent_packages`, long tail in the same fetch.
  * **inlineable**: small enough to copy into your tree. Signal: LOC from the clone (already have non-active clones via `clone.rb`), single file or under ~300 source lines, `runtime_deps = 0`. The npm micro-utility pattern, but every ecosystem has one-function packages.
  * **alternative**: a maintained drop-in or near-drop-in exists. Signal: category siblings from a curated index (ruby-toolbox, crates.io keywords, npms.io, libraries.io related), registry deprecation metadata pointing at a successor, README says "use X instead". Mostly manual.
  * **kitchen-sink**: large surface, dependents typically use a slice, replacing it means several packages rather than one. Signal: high LOC, many top-level modules. Hard to automate; hand-tag from the top of the list.
  * **no-alternative**: fills a niche nothing else does, often a native extension or protocol binding. Signal: absence of the above plus native code in the tree.
  * **eol-direct**: the package itself is deprecated, yanked, or archived with intent. Signal: `repos.archived`, registry deprecation flag, README says so.
  * **eol-transitive**: alive enough on its own but pinned to runtime deps that are themselves dead or archived. Signal: recursive join through the `dependencies` table. Stored as `dead_transitive_count` and `max_dead_depth` rather than a boolean, because one dead transitive is a very different adoption cost than seven, and the count sharpens the adopt-cost estimate more than complexity alone.

The eol values are orthogonal to the size/shape values, so store them separately. Strawman: `situation` enum {few-large, broad, inlineable, alternative, kitchen-sink, no-alternative} plus `eol_direct` boolean, `dead_transitive_count`, `max_dead_depth`.

## remediation

What a dependent should actually do. Derived from situation plus risk (advisories, drift) plus how replaceable the API surface is.

  * **adopt**: fork or take over maintenance. Maps from few-large + no-alternative, or anything where you're already the largest consumer.
  * **vendor**: copy the code in and drop the dependency. Maps from inlineable. Cheapest when `runtime_deps = 0`.
  * **switch**: replace wholesale with one alternative. Maps from alternative.
  * **switch-piecemeal**: replace the slice you use, possibly with two or three different packages. Maps from kitchen-sink.
  * **accept**: you're keeping it and carrying the risk. Pin the version. Maps from low-risk dormant ("done, not dead"), from broad where you can't move unilaterally, and from no-alternative where adopt is too expensive. There is no "monitor" value because for a bernie there is no upstream that will ship a fix; when a vuln lands the only exits are the four options above. `accept` is the honest name for not taking one yet. How bad a given `accept` is comes from the other columns: `situation`, `unpatched_advisories_count`, `dead_transitive_count`. For broad packages the realistic exit is a community fork getting published, at which point the row becomes `switch`; until then `remediation_notes` can say so but the recommendation is still `accept`.

Store the primary recommendation plus `alternative_purl` (where to go for switch/switch-piecemeal), `remediation_notes` (one or two sentences a developer can read), and `remediation_source` (heuristic / llm / human) so downstream consumers can weight it. A package can reasonably have a secondary option ("vendor, or switch to X if you need feature Y") so `remediation_notes` carries that rather than forcing a single enum.

The recommendation is per-package but the right answer is really per-(package, dependent): the largest consumer of a few-large package should adopt while everyone else should monitor and wait for them. We're storing the modal recommendation, which is what a published list needs, and `remediation_notes` will often carry the conditional ("if you're the primary consumer, adopt; otherwise monitor"). Be explicit downstream that this is ecosystem-level guidance, not personalised to the reader's dependency tree.

## data

Already in the db: `dependent_repos`, `dependent_packages`, `downloads`, `archived`, `runtime_deps`, `advisories`, clones of non-active repos.

To fetch:

  * `dependents.rb`: top-N dependent packages per package from `packages.ecosyste.ms /api/v1/registries/{registry}/packages/{name}/dependent_packages?sort=downloads`, cached under `cache/dependents/`. New `dependents` table (purl, dependent_purl, dependent_downloads, rank). Compute `top1_share` and `top5_share` onto `packages`.
  * `size.rb`: run `brief <clone>` and `scc --format json <source-dir>` on each clone. brief gives a structured toolchain summary (languages, package managers, frameworks, test tools, direct deps, LOC by language) which goes straight into the LLM prompt and is far richer than a README snippet for "what kind of project is this". scc on the primary source dir (per-ecosystem convention: `lib/`, `src/`, package root, so tests and vendored deps don't inflate it) gives `code_loc`, `comment_loc`, `code_files`, `complexity`. Also count top-level entry points in the source dir (`lib/*.rb`, package.json `exports`, top-level `.py` modules) as `entry_points`; it's a rough kitchen-sink discriminator that separates activesupport-shaped from nokogiri-shaped before the LLM sees them. `has_native` derived from brief's language list containing any of C/C++/Rust/Java/Objective-C. Store the full brief JSON in `cache/brief/<repo-hash>.json` and the extracted scalars on `repos`. Complexity feeds two things: the inlineable threshold (low LOC and low complexity is safer to vendor than low LOC and a dense state machine) and an adopt-cost proxy (high complexity plus high `dead_transitive_count` means taking over maintenance is expensive even if LOC is modest).
  * README/manifest grep for `deprecat|unmaintained|no longer|use .* instead|superseded by` happens inside `size.rb` since it's already walking the clone; the matched line goes into `repos.deprecation_text`. That's the only alternative-detection in v1.

Hand-tagged: kitchen-sink vs no-alternative won't fall out of metrics cleanly. Pre-fill everything from heuristics and the LLM pass below, then walk `bernies.csv` filtered to rubygems and correct. 343 rows is an afternoon if the pre-fill is half right.

## llm pass

The heuristics in `situate.rb` cover the easy cases. For the rest, feed an LLM the assembled context per package and have it propose `situation`, `remediation`, a suggested alternative if any, and a one-line justification. This replaces the README regex with actual reading and handles the kitchen-sink / no-alternative split that metrics can't.

`llm.rb` runs after `situate.rb`, only on rows where `situation IS NULL OR tagged_at IS NULL`. Input per package: name, ecosystem, description, bucket + signals, `code_loc`, `code_files`, `complexity`, `entry_points`, `has_native`, `runtime_deps`, `dead_transitive_count`, top-5 dependents with downloads, `deprecation_text` if any, the brief JSON for the repo, and the first ~2k chars of README from the clone. The LLM proposes `alternative_purl` from that context and its own knowledge; without a candidate list to validate against, treat any LLM-named alternative as unverified until a human or `alternatives.rb` (phase 2) confirms it exists and is maintained. Output: JSON `{situation, eol_direct, alternative_purl, remediation, note, confidence}`. Use the `anthropic` SDK, Haiku for cost, batch API since none of it is interactive. Cache raw responses under `cache/llm/<purl-hash>.json` like every other step so reruns are free and the prompt can be iterated without re-paying.

Treat the output as a better pre-fill, not ground truth. `tag.rb` shows the LLM's guess and note alongside the heuristic guess; a human still confirms. Keep `confidence` so the manual pass can sort low-confidence first.

Since this feeds real decisions, never publish a row with `remediation_source = 'llm'` and no human review for anything in the dead bucket or with `unpatched_advisories_count > 0`. Heuristic-only and llm-only rows are fine to surface for the long tail as long as the source is visible, but the high-blast-radius packages get eyes on them.

## process

  1. Add columns: `packages.situation`, `packages.eol_direct`, `packages.dead_transitive_count`, `packages.max_dead_depth`, `packages.remediation`, `packages.alternative_purl`, `packages.remediation_notes`, `packages.remediation_source`, `packages.tagged_at`, `packages.top1_share`, `packages.top5_share`; `repos.code_loc`, `repos.comment_loc`, `repos.code_files`, `repos.complexity`, `repos.entry_points`, `repos.languages`, `repos.has_native`, `repos.deprecation_text`, `repos.size_synced_at`. New `dependents` table.
  2. Write `dependents.rb` and `size.rb` following the existing script pattern: `busy_timeout`, `cache/<step>/`, skip rows already synced, optional `LIMIT` arg, skip `bucket='active'`.
  3. `situate.rb` does the heuristic pre-fill. inlineable if `code_loc < 300 AND complexity < 50 AND runtime_deps = 0`. few-large if `dependent_packages < 20 AND top1_share > 0.5` (threshold is a starting guess, tune against the rubygems set). broad if `dependent_packages > 200`. kitchen-sink if `entry_points > 10 AND code_loc > 3000`. alternative if `deprecation_text` names a successor. eol_direct from `archived` or `deprecation_text`. `dead_transitive_count` / `max_dead_depth` from a recursive deps join. Everything else left null.
  4. `llm.rb` fills the gaps: proposes situation/remediation/alternative/note for anything still null, and second-guesses the heuristic rows. Batch API, cached.
  5. `tag.rb` for the manual pass: print one package at a time with the heuristic guess, repo link, top dependents, LOC; take a keystroke to confirm or override situation and remediation; write back with `tagged_at`. Or skip the TUI and dump to CSV, edit in a spreadsheet, reimport. Decide after seeing how good the pre-fill is.
  6. `report.rb` grows a `remediation.csv`: purl, name, ecosystem, bucket, situation, eol_direct, dead_transitive_count, remediation, alternative_purl, remediation_source, dependent_repos, top dependent, code_loc, complexity, unpatched_advisories, notes. Same data as JSON under `out/remediation.json` for downstream consumption.

As a cross-check on `classify.rb`, run `size.rb` and `llm.rb` over a sample of `--bucket active` repos too. An active-bucketed repo where the README grep or the LLM returns `eol_direct=true` is likely misclassified: still getting commits but the maintainer has already told people to leave. Those should feed back into `classify.rb` as a new signal.

Rubygems only to start because I can sanity-check those by eye, but nothing in the schema or scripts is ecosystem-specific; the only per-ecosystem code is the source-dir convention in `size.rb`. Once the taxonomy survives contact with real packages, rerun fetch/situate/llm across all ecosystems and hand-tag by blast radius (dependent_repos desc) rather than per-ecosystem quotas, since that's the order developers will hit them in.

## later: alternatives.rb

Deferred from v1. Collect candidate replacements from three sources in precedence order: (1) maintained registry-published forks of the repo via the ecosyste.ms fork graph, near-zero migration cost so the highest-value `alternative_purl` there is; (2) the README/manifest pointer already captured in `deprecation_text`; (3) category siblings from a per-ecosystem index (ruby-toolbox, crates.io keywords, libraries.io related). Store as `(purl, candidate_purl, candidate_description, source, rank)` in an `alternatives` table, filter to candidates whose repo is `bucket='active'`. A fourth source if the first three prove thin: packages whose current dependent set overlaps with this one's former dependents, i.e. empirical evidence of where people migrated to. When this lands, feed candidates into the LLM prompt and re-run `llm.rb` so suggestions are grounded in verified-active packages rather than model recall.
