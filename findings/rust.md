# non-active cargo crates: shape and remediation (May 2026)

232 critical crates whose repos are not actively maintained, across 215 repos. Cargo's non-active share is 37% (215/580 repos), between PyPI's 27% and rubygems' 49%, with 11.9% dead.

| bucket | n | meaning |
|---|---:|---|
| dormant | 104 | no maintainer activity in a year, but no evidence they've left |
| dead | 73 | archived, or people have knocked and nobody answered |
| unknown | 55 | too quiet to tell; nobody has filed anything to test responsiveness |

## summary

Cargo has the highest vendor share of the four registries: a third of these crates are small enough to copy into your tree. The Rust crate model favours small, focused units the way rubygems does, and unlike rubygems many of them have a community-designated successor — 49 named, with the RustSec advisory database and `cargo audit` actively steering users toward replacements. Accept is the lowest of the four at 39%.

| remediation | n | % | rubygems % | go % | pypi % | meaning |
|---|---:|---:|---:|---:|---:|---|
| accept | 90 | 39% | 50% | 41% | 39% | keep it, pin the version, carry the risk; no good exit exists |
| vendor | 79 | 34% | 27% | 21% | 20% | copy the source into your tree and drop the dependency; you now own it |
| switch | 54 | 23% | 19% | 32% | 28% | move to a named, maintained successor |
| adopt | 6 | 3% | 2% | 1% | 4% | take over maintenance |
| switch-piecemeal | 3 | 1% | 1% | 4% | 8% | replace the slice you use with two or three smaller packages |

| situation | n | % | rubygems % | go % | pypi % | meaning |
|---|---:|---:|---:|---:|---:|---|
| broad | 86 | 37% | 19% | 56% | 52% | many small dependents, no obvious steward |
| few-large | 67 | 29% | 60% | 20% | 24% | a handful of large dependents account for most usage |
| inlineable | 53 | 23% | 14% | 7% | 7% | small enough that copying the code in is mechanically easy |
| alternative | 17 | 7% | 4% | 7% | 4% | a maintained drop-in replacement exists |
| no-alternative | 7 | 3% | 2% | 1% | 4% | fills a niche nothing else covers |
| kitchen-sink | 2 | 1% | <1% | 9% | 10% | large surface, dependents use a slice |

## small and focused

Of 212 repos measured, 63 (30%) are under 300 lines and 26 (12%) over 3,000. Mean is 2,349 lines, the closest of the four to rubygems' 1,784. 9 carry C (mostly `-sys` crates wrapping a vendored library). Kitchen-sink barely registers; Rust crates do one thing.

| size | cargo | rubygems | go | pypi |
|---|---:|---:|---:|---:|
| under 300 lines | 30% | 41% | 10% | 4% |
| 300–3,000 | 58% | 49% | 55% | 59% |
| 3,000+ | 12% | 11% | 35% | 37% |

## usage concentration

Of 221 with concentration data, 45 (20%) have a single dependent at ≥90% of downstream downloads and 129 (58%) have one above 50%, in line with rubygems and PyPI. Captives at the top:

  * `winapi-x86_64-pc-windows-gnu`, `winapi-i686-pc-windows-gnu` → winapi (100%, packaging split)
  * `foreign-types-shared` → foreign-types (100%)
  * `proc-macro-error-attr` → proc-macro-error (100%)
  * `same-file` → walkdir (99.9%)
  * `try-lock` → want (99.9%)
  * `ppv-lite86` → c2-chacha (99.3%)

## explicit end-of-life

22 repos (10%) are archived and 26 packages flagged end-of-life from README or archive. Lower than Go (18%) but the RustSec advisory database serves a similar role: `cargo audit` reports unmaintained crates with RUSTSEC IDs and named replacements, which is why so many of the successors below are well-established.

## named successors

49 of 232. Official handoffs and community-adopted forks where RustSec or the README points the way:

  * `winapi`, `winapi-build`, `kernel32-sys` → windows-sys
  * `failure`, `failure_derive` → anyhow / thiserror
  * `structopt`, `structopt-derive` → clap
  * `ansi_term` → nu-ansi-term
  * `net2` → socket2
  * `tempdir` → tempfile
  * `dotenv` → dotenvy
  * `instant` → web-time
  * `lazycell` → once_cell
  * `quick-error` → thiserror
  * `cache-padded` → crossbeam-utils
  * `dirs-next` → dirs
  * `linked-hash-map` → indexmap
  * `trust-dns-proto`, `trust-dns-resolver` → hickory-dns / hickory-resolver
  * `yaml-rust` → serde_yaml → serde-yaml-ng
  * `difference`, `difflib` → similar
  * `serde_cbor` → ciborium
  * `rustls-pemfile` → rustls-pki-types
  * `mio-uds` → mio
  * `fuchsia-cprng` → getrandom
  * `semver-parser` → semver
  * `urlencoding` → percent-encoding
  * `tiny-keccak` → sha3
  * `sha1_smol` → sha1

Editorial; maintained alternatives rather than designated successors:

  * `nom` → winnow
  * `tokio-native-tls` → tokio-rustls
  * `fxhash` → ahash
  * `threadpool` → rayon
  * `lru-cache` → lru
  * `float-cmp` → approx
  * `yansi` → colored
  * `globwalk` → glob
  * `num_threads` → num_cpus
  * `downcast` → downcast-rs

Wrong: `pin-utils` → pin-project-lite (different purpose), `oorandom` → rand (oorandom is deliberately minimal; rand is the opposite), `futures-intrusive` → tokio (far too broad), and two self-references (`dirs-sys-next`, `lz4-sys`).

## open questions

Whether the high vendor share survives review: a 200-line crate with `unsafe` blocks is mechanically small but not something you want to own without reading every line. And whether the `yaml-rust` → `serde_yaml` → `serde-yaml-ng` chain (each successor itself going unmaintained) is a one-off or a pattern worth tracking.
