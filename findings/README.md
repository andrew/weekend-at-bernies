# findings

Per-ecosystem writeups on critical open-source packages whose repositories are not actively maintained: how big they are, who actually depends on them, whether a successor exists, and what a dependent should do about it.

| ecosystem | unmaintained packages | writeup |
|---|---:|---|
| rubygems | 343 | [ruby.md](ruby.md) |
| go | 360 | [go.md](go.md) |
| pypi | 123 | [pypi.md](pypi.md) |
| cargo | 232 | rust.md (in progress) |

## what dependents should do, by ecosystem

| | rubygems | go | pypi | cargo |
|---|---:|---:|---:|---:|
| accept | 50% | 41% | 39% | — |
| switch | 19% | 32% | 28% | — |
| vendor | 27% | 21% | 20% | — |
| switch-piecemeal | 1% | 4% | 8% | — |
| adopt | 2% | 1% | 4% | — |
| packages with a named successor | 51 | 96 | 27 | — |
| repos explicitly archived | 8% | 18% | 14% | — |
| repos under 300 lines of code | 41% | 10% | 4% | 30% |

rubygems has the most very small packages and the highest share with no exit beyond pinning and accepting the risk. Go authors are the most likely to archive a repo and point at where to go next, so more Go dependents have a named successor to switch to. PyPI has the smallest unmaintained set of any large registry and the most large multi-purpose libraries needing piecemeal replacement.

## terms

Each package gets a recommended action:

  * **accept** — keep it, pin the version, carry the risk. No good exit exists. A package with zero published security advisories has usually just not been audited; that says nothing about whether problems exist.
  * **vendor** — copy the source into your own project and drop the dependency. Removes the supply-chain exposure but you now own the code and whatever is wrong with it.
  * **switch** — move to a named, maintained successor.
  * **switch-piecemeal** — replace the part you use with two or three smaller packages.
  * **adopt** — take over maintenance. Usually because you are already the largest consumer.

And a description of its shape:

  * **few-large** — a handful of large dependents account for most usage. The fix is a conversation with them.
  * **broad** — many small dependents, no single one could take it on.
  * **inlineable** — small enough that copying the code in is mechanically easy.
  * **alternative** — a maintained drop-in replacement exists.
  * **kitchen-sink** — large library, most dependents use one corner of it, several replacements needed.
  * **no-alternative** — fills a niche nothing else covers, often native bindings or protocol code.

A per-package recommendation is general advice. For any specific project the right answer depends on which dependent you are: the dominant consumer of a `few-large` package should adopt it, while everyone else should wait for them to.
