# non-active npm packages: shape and remediation (May 2026)

1,111 critical npm packages whose repos are not actively maintained, across 1,021 repos. npm has the largest non-active set of any registry, three times the next (Go's 360). 11.3% of repos are dead, 64% non-active overall.

| bucket | n | meaning |
|---|---:|---|
| dormant | 468 | no maintainer activity in a year, but no evidence they've left |
| unknown | 456 | too quiet to tell; nobody has filed anything to test responsiveness |
| dead | 187 | archived, or people have knocked and nobody answered |

## summary

npm has the highest vendor share of any registry (41%): four in ten of these are small enough to copy in. It also has the most concentrated usage (37% have one dependent at ≥90% of installs, 69% at ≥50%), the lowest archive rate (4%), and the most non-active packages owned by a handful of prolific authors. 105 named successors, the most in raw count but the noisiest as a list because npm has so many overlapping micro-utilities that "successor" and "alternative" blur.

| remediation | n | % | rubygems % | go % | pypi % | cargo % | packagist % | meaning |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| vendor | 456 | 41% | 27% | 21% | 20% | 34% | 27% | copy the source into your tree and drop the dependency; you now own it |
| accept | 435 | 39% | 50% | 41% | 39% | 39% | 31% | keep it, pin the version, carry the risk; no good exit exists |
| switch | 188 | 17% | 19% | 32% | 28% | 23% | 38% | move to a named, maintained successor |
| switch-piecemeal | 20 | 2% | 1% | 4% | 8% | 1% | 1% | replace the slice you use with two or three smaller packages |
| adopt | 12 | 1% | 2% | 1% | 4% | 3% | 2% | take over maintenance |

| situation | n | % | meaning |
|---|---:|---:|---|
| broad | 616 | 55% | many small dependents, no obvious steward |
| inlineable | 265 | 24% | small enough that copying the code in is mechanically easy |
| few-large | 181 | 16% | a handful of large dependents account for most usage |
| alternative | 23 | 2% | a maintained drop-in replacement exists |
| kitchen-sink | 22 | 2% | large surface, dependents use a slice |
| no-alternative | 4 | <1% | fills a niche nothing else covers |

## the micro-utility layer

Of 1,009 repos measured, 404 (40%) are under 300 lines. Mean is 3,436 but the median is far lower; the distribution is npm's signature long tail of one-function packages. 6 (under 1%) carry native code. Only 45 (4%) are archived, the lowest of any registry; npm authors leave repos in place rather than pulling the lever.

| size | npm | rubygems | packagist | cargo | go | pypi |
|---|---:|---:|---:|---:|---:|---:|
| under 300 lines | 40% | 41% | 40% | 30% | 10% | 4% |
| 300–3,000 | 52% | 49% | 41% | 58% | 55% | 59% |
| 3,000+ | 8% | 11% | 19% | 12% | 35% | 37% |

## a few authors, many packages

23% of these 1,021 repos belong to four GitHub accounts:

| owner | non-active repos |
|---|---:|
| sindresorhus | 97 |
| jonschlinkert | 59 |
| inspect-js | 45 |
| ljharb | 30 |
| es-shims | 24 |
| indutny | 16 |
| wooorm | 15 |
| isaacs | 15 |
| jshttp | 14 |
| mafintosh | 13 |

Several of these authors are very much active elsewhere; a 30-line utility with no commits in two years is "done", and the same person would likely respond to a security report. The per-repo activity test undercounts maintainer presence when one maintainer has hundreds of repos. That said, the publish-token bus factor is real: 97 packages behind one rubygems-equivalent account is 97 packages that go dark together.

## usage concentration

For 808 with concentration data, 300 (37%) have one dependent at ≥90% of downstream installs and 559 (69%) have one above 50%. Both the highest of any registry, confirming the hypothesis from the rubygems writeup that npm's micro-package culture would be the most concentrated.

  * `forwarded` → proxy-addr (100%)
  * `snapdragon-node`, `snapdragon-util` → snapdragon (100%)
  * `ret` → randexp (99.9%)
  * `set-blocking` → npmlog (99.8%)
  * `has-values` → has-value (99.7%)

The `jonschlinkert` micromatch/snapdragon family alone accounts for a dozen of the captives.

## named successors

105 of 1,111. Official handoffs:

  * `@babel/preset-modules` → @babel/preset-env
  * `@ampproject/remapping` → @jridgewell/remapping
  * `esprima` → acorn
  * `acorn-import-assertions` → acorn (merged upstream)
  * `json-stable-stringify-without-jsonify` → json-stable-stringify
  * `combined-stream` → combined-stream2
  * `neo-async` → async
  * `crypto-random-string` → nanoid
  * `throat` → p-limit

Editorial; maintained alternatives in the same space, often one of several:

  * `minimist`, `optionator`, `coa` → yargs
  * `rc`, `lilconfig` → cosmiconfig
  * `ansi-colors`, `kleur` → chalk
  * `prompts` → inquirer
  * `faye-websocket`, `sockjs` → ws / socket.io
  * `glob-to-regexp`, `micromatch` → minimatch
  * `big.js` → decimal.js
  * `html-entities` → entities
  * `encoding` → iconv-lite

Wrong or backwards: `picocolors` → nanocolors (picocolors is the *successor* to nanocolors), `fsevents` → chokidar (chokidar uses fsevents), `braces` → brace-expansion (different things), `clone-deep` → lodash (too broad), `base64-js` → base64-js (self-reference). npm's overlapping micro-utility space makes successor-vs-alternative harder to call than in any other registry; this list needs more correction than the others.

## open questions

Whether the prolific-author packages should be bucketed differently: a sindresorhus utility with no commits since 2023 is unmaintained by the per-repo test but the maintainer is demonstrably reachable. A per-author activity signal (any commit to any repo in the past year) would separate "done, author present" from "done, author gone". And whether the 69% concentration figure holds once dependent data is complete for the largest packages.
