# non-active packagist packages: shape and remediation (May 2026)

167 critical Packagist packages whose repos are not actively maintained. Packagist's non-active share is 31% (167/547 repos) with 12.1% dead, close to npm and rubygems.

| bucket | n | meaning |
|---|---:|---|
| dead | 66 | archived, or people have knocked and nobody answered |
| dormant | 62 | no maintainer activity in a year, but no evidence they've left |
| unknown | 39 | too quiet to tell; nobody has filed anything to test responsiveness |

## summary

Packagist has the clearest exit signals of any registry looked at. 28% of these repos are archived (Go: 18%, rubygems: 8%) and 35% carry an explicit deprecation notice, and Composer's `abandoned` field in `composer.json` gives authors a first-class way to name a successor that the tooling surfaces on install. The result is the highest switch share (38%) and lowest accept share (31%) of the five.

Several large migrations account for much of that. Zend Framework rebranded to Laminas, and every `zendframework/*` package has a `laminas/*` successor. `swiftmailer` was retired in favour of `symfony/mailer`. `fzaninotto/faker` was archived and `fakerphp/faker` took over. Each of those moved a cluster of packages at once.

| remediation | n | % | rubygems % | go % | pypi % | cargo % | meaning |
|---|---:|---:|---:|---:|---:|---:|---|
| switch | 64 | 38% | 19% | 32% | 28% | 23% | move to a named, maintained successor |
| accept | 52 | 31% | 50% | 41% | 39% | 39% | keep it, pin the version, carry the risk; no good exit exists |
| vendor | 45 | 27% | 27% | 21% | 20% | 34% | copy the source into your tree and drop the dependency; you now own it |
| adopt | 4 | 2% | 2% | 1% | 4% | 3% | take over maintenance |
| switch-piecemeal | 2 | 1% | 1% | 4% | 8% | 1% | replace the slice you use with two or three smaller packages |

| situation | n | % | meaning |
|---|---:|---:|---|
| broad | 69 | 41% | many small dependents, no obvious steward |
| few-large | 50 | 30% | a handful of large dependents account for most usage |
| inlineable | 23 | 14% | small enough that copying the code in is mechanically easy |
| alternative | 20 | 12% | a maintained drop-in replacement exists |
| no-alternative | 3 | 2% | fills a niche nothing else covers |
| kitchen-sink | 2 | 1% | large surface, dependents use a slice |

The 12% `alternative` share is three times any other registry's, again reflecting the `abandoned` field doing its job.

## small, like rubygems

Of 167 repos measured, 66 (40%) are under 300 lines and 32 (19%) over 3,000. Mean is 3,633 lines. The size profile is closest to rubygems of the five.

| size | packagist | rubygems | cargo | go | pypi |
|---|---:|---:|---:|---:|---:|
| under 300 lines | 40% | 41% | 30% | 10% | 4% |
| 300–3,000 | 41% | 49% | 58% | 55% | 59% |
| 3,000+ | 19% | 11% | 12% | 35% | 37% |

2 carry C extensions.

## usage concentration

Of 165 with concentration data, 40 (24%) have a single dependent at ≥90% of downstream downloads and 93 (56%) have one above 50%, in the same range as the other registries.

  * `jakub-onderka/php-console-color` → php-console-highlighter (100%)
  * `facade/flare-client-php` → facade/ignition (100%)
  * `phar-io/version` → phar-io/manifest (99.9%)
  * `egulias/email-validator` → swiftmailer (98.6%)
  * `composer/xdebug-handler` → phpmd (97.5%)

## explicit end-of-life

46 repos (28%) are archived and 58 (35%) have a deprecation notice in the README or `composer.json`, both the highest of any registry. Composer's `abandoned` field means a deprecation pointer is structured metadata rather than a README sentence, which is why so many of the successors below are unambiguous.

## named successors

53 of 167 (32%), the highest rate of the five. Official handoffs and rebrands:

  * `swiftmailer/swiftmailer`, `symfony/swiftmailer-bundle` → symfony/mailer
  * `fzaninotto/faker` → fakerphp/faker
  * `zendframework/zend-diactoros`, `-eventmanager`, `-stdlib`, `-code` → laminas/laminas-*
  * `facade/ignition`, `facade/flare-client-php` → spatie/laravel-ignition, spatie/flare-client-php
  * `jakub-onderka/php-console-highlighter`, `-color` → php-parallel-lint/*
  * `mtdowling/cron-expression` → dragonmantank/cron-expression
  * `symfony/debug` → symfony/error-handler
  * `container-interop/container-interop` → psr/container
  * `php-http/message-factory` → psr/http-factory
  * `guzzle/guzzle` → guzzlehttp/guzzle
  * `laravelcollective/html` → spatie/laravel-html
  * `sensio/generator-bundle` → symfony/maker-bundle
  * `namshi/jose` → firebase/php-jwt
  * `doctrine/reflection` → roave/better-reflection
  * `phpoffice/phpexcel` → phpoffice/phpspreadsheet
  * `facebook/webdriver` → php-webdriver/php-webdriver
  * `fabpot/goutte` → symfony/browser-kit
  * `jeremeamia/superclosure` → opis/closure
  * `hashids/hashids` → sqids/sqids
  * `knplabs/gaufrette` → league/flysystem
  * `webmozart/path-util` → symfony/filesystem
  * `behat/mink-extension` → friends-of-behat/mink-extension
  * `sensiolabs/security-checker` → fabpot/local-php-security-checker
  * `php-cs-fixer/diff` → sebastian/diff
  * `kriswallsmith/assetic` → assetic/framework
  * `symfony/inflector` → symfony/string
  * `nette/finder` → nette/utils
  * `sentry/sdk` → sentry/sentry

Editorial: `phar-io/version` → composer/semver, `league/mime-type-detection` → symfony/mime, `league/event` → symfony/event-dispatcher, `doctrine/cache` → symfony/cache, `nikic/fast-route` → symfony/routing, `michelf/php-markdown` → league/commonmark, `beberlei/assert` → webmozart/assert, `phpmd/phpmd` → phpstan, `setasign/fpdf` → tcpdf.

Wrong: `doctrine/common` → package-versions-deprecated (unrelated), `aws/aws-crt-php` → aws/aws-sdk-php (crt is a dependency of the SDK, not replaced by it).

## open questions

Whether Composer's `abandoned` field is the reason Packagist has the highest switch share, or whether the Zend→Laminas rebrand alone accounts for most of the gap. And how many of the `accept` cases are Symfony or Laravel internals that are effectively maintained by the framework even when the individual repo is quiet.
