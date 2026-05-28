# non-active go modules: shape and remediation (May 2026)

360 critical Go modules whose repos are not actively maintained, across 342 repos. Go has the highest dead share of any large registry in the dataset: 20.2% of repos vs 10.8% for rubygems and 11.3% for npm. Dependent-concentration data is available for 131 of the 360; the largest modules are missing.

| bucket | n | meaning |
|---|---:|---|
| dormant | 124 | no maintainer activity in a year, but no evidence they've left |
| dead | 122 | archived, or people have knocked and nobody answered |
| unknown | 114 | too quiet to tell; nobody has filed anything to test responsiveness |

Go differs from rubygems in ways that affect every section below. There are no download counts, so concentration and the direct/transitive split use dependent-repo counts instead. Vendoring is a first-class workflow (`go mod vendor`, `replace` directives) so the mechanical cost of copying code in is lower, though the maintenance burden is the same. Module paths are repo URLs, so a package going dead can mean the import path itself disappears if the repo is deleted, which has no rubygems equivalent.

## summary

Compared to rubygems, fewer Go modules end up at "pin and accept the risk" (41% vs 50%) and far more have a named successor to switch to (32% vs 19%, with 96 named successors against rubygems' 51). Go authors archive more readily (18% of repos vs 8%) and more often point at where to go next, which gives dependents an exit that rubygems users frequently lack. Vendoring is recommended for a fifth of modules despite `go mod vendor` making it mechanically trivial, because the codebases are an order of magnitude larger and absorbing them means owning a lot of code.

| remediation | n | % | rubygems % | meaning |
|---|---:|---:|---:|---|
| accept | 149 | 41% | 50% | keep it, pin the version, carry the risk; no good exit exists |
| switch | 115 | 32% | 19% | move to a named, maintained successor |
| vendor | 76 | 21% | 27% | copy the source into your tree and drop the dependency; you now own it |
| switch-piecemeal | 16 | 4% | 1% | replace the slice you use with two or three smaller packages |
| adopt | 4 | 1% | 2% | take over maintenance (you are, or should be, the primary consumer) |

| situation | n | % | rubygems % | meaning |
|---|---:|---:|---:|---|
| broad | 202 | 56% | 19% | many small dependents, no obvious steward |
| few-large | 73 | 20% | 60% | a handful of large dependents account for most usage |
| kitchen-sink | 31 | 9% | <1% | large surface, dependents use a slice, several replacements needed |
| inlineable | 26 | 7% | 14% | small enough that copying the code in is mechanically easy |
| alternative | 26 | 7% | 4% | a maintained drop-in replacement exists |
| no-alternative | 2 | 1% | 2% | fills a niche nothing else covers |

The broad/few-large split is unreliable here: concentration data is missing for 229 of 360 modules, and those default toward broad in its absence. rubygems showed 60% few-large with full data; Go is likely similar.

## most of them are not tiny

Of 337 repos measured the source ranges from 45 lines (`kr/pty`) to 5 million (`aws/aws-sdk-go` v1). Mean is 29,191 lines, sixteen times the rubygems figure, and the distribution leans the other way:

| size | go | rubygems |
|---|---:|---:|
| under 300 lines | 33 (10%) | 134 (41%) |
| 300–3,000 | 185 (55%) | 160 (49%) |
| 3,000+ | 119 (35%) | 35 (11%) |
| of which 30,000+ | 23 (7%) | 1 (<1%) |

The giants are real code rather than measurement artefacts: `aws/aws-sdk-go`, `docker/distribution`, `gogo/protobuf`, `go-playground/locales` are generated SDKs and protocol bindings in the hundreds of thousands of lines. Go counts the whole repo as source where rubygems counts only `lib/`, which inflates the comparison somewhat, but the pattern holds: a Go module is usually a substantial codebase. 17 (5%) use cgo. Copying the code into your own tree is a realistic option for about one in ten of these against four in ten for rubygems.

## usage concentration (partial)

For the 131 smaller modules with concentration data, 39 (30%) have a single dependent accounting for at least 90% of downstream use and 81 (62%) have one above 50%, broadly matching rubygems. The 229 without data are the modules with the largest dependent sets, which are likely the most concentrated since `golang.org/x/*` and similar are pulled in by a small number of widely-used intermediaries.

## explicit end-of-life

61 repos (18%) are archived, more than double rubygems' 8%, and 76 packages (21%) are flagged end-of-life from the archive flag or the README. Go authors appear more willing to pull the archive lever, possibly because the module path is the repo URL and archiving is the clearest available signal that the path should not be imported.

## what dependents should do

Accept covers 149 modules and skews to infrastructure that has nowhere left to go: hashing, encoding, small utilities pinned by half the registry. None currently has a published unpatched advisory, which mostly tells you how little auditing dormant code receives; when somebody does find something there is no maintainer to ship the fix.

Vendor covers 76. With `go mod vendor` and `replace` directives the mechanics are easier than in rubygems, but the median codebase is larger and 17 carry cgo, so the maintenance you absorb is correspondingly heavier.

96 modules have a named successor, almost twice rubygems' rate. Official handoffs and community-adopted forks where the original README points the way:

  * `gopkg.in/yaml.v2` → gopkg.in/yaml.v3
  * `github.com/golang/protobuf`, `github.com/gogo/protobuf` → google.golang.org/protobuf
  * `github.com/golang/mock` → go.uber.org/mock
  * `github.com/dgrijalva/jwt-go` → github.com/golang-jwt/jwt
  * `github.com/aws/aws-sdk-go` → aws-sdk-go-v2
  * `github.com/kr/pty` → github.com/creack/pty
  * `github.com/kr/logfmt` → github.com/go-logfmt/logfmt
  * `github.com/hpcloud/tail` → github.com/nxadm/tail
  * `github.com/coreos/etcd` → go.etcd.io/etcd
  * `github.com/armon/go-metrics` → github.com/hashicorp/go-metrics
  * `github.com/armon/consul-api` → github.com/hashicorp/consul/api
  * `github.com/BurntSushi/xgb` → github.com/jezek/xgb
  * `github.com/cncf/udpa/go` → github.com/cncf/xds/go
  * `github.com/satori/go.uuid`, `github.com/pborman/uuid` → github.com/google/uuid
  * `github.com/opentracing/opentracing-go` → go.opentelemetry.io/otel
  * `github.com/grpc-ecosystem/go-grpc-prometheus` → go-grpc-middleware/providers/prometheus
  * `github.com/Azure/go-autorest/*` → github.com/Azure/azure-sdk-for-go
  * `golang.org/x/lint` → golangci-lint
  * `github.com/prometheus/tsdb` → github.com/prometheus/prometheus

A second tier are reasonable but editorial; the targets are maintained alternatives rather than designated successors:

  * `gopkg.in/check.v1`, `github.com/smartystreets/assertions`, `github.com/go-playground/assert/v2` → testify
  * `github.com/kr/pretty`, `github.com/niemeyer/pretty` → go-spew
  * `github.com/OneOfOne/xxhash` → cespare/xxhash
  * `github.com/julienschmidt/httprouter` → chi
  * `github.com/russross/blackfriday/v2` → goldmark
  * `github.com/coreos/go-semver` → Masterminds/semver
  * `github.com/pierrec/lz4` → klauspost/compress
  * `github.com/rogpeppe/fastuuid`, `github.com/hashicorp/go-uuid` → google/uuid

Needs checking: `github.com/gorilla/websocket` → nhooyr.io/websocket is stale advice (gorilla was revived in 2023 and nhooyr's repo has itself moved to `github.com/coder/websocket`), and `github.com/chzyer/logex` → logrus points at another dormant package.

## open questions

Whether Go's higher dead share reflects something about module publishing (low barrier, import-path coupling to repos that vanish) or about how activity reads on Go repos (fewer issues filed, so more land in `dead` on the no-response criterion). And whether the broad/few-large split converges on rubygems' 60% few-large once concentration data is complete.
