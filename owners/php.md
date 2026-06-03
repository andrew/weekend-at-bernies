# packagist owners

547 critical packagist packages from 72 distinct owners.

| | organisation | individual | unknown |
|---|---:|---:|---:|
| owners | 49 | 22 | 1 |
| packages | 428 | 118 | 1 |
| non-active packages | 96 | 31 | 1 |
| non-active % | 22.4 | 26.3 | 100.0 |

Packagist has the smallest individual/organisation gap on non-active rates in the dataset, and the most org-skewed ownership. That's partly Composer's design: most PHP packages live under a project-namespaced vendor (`symfony/console`, `doctrine/orm`, `laminas/form`) rather than a personal account.

## the bernies cluster around historical migrations

| organisation | bernies | active | hist maint | active maint | reading |
|---|---:|---:|---:|---:|---|
| symfony | 11 | 79 | 38 | 20 | active distributed |
| zendframework | 6 | 0 | 15 | 0 | wound down: rebranded to Laminas, account exists for artefacts |
| php-http | 6 | 2 | 13 | 0 | wound down: HTTPlug-related work moved to symfony/http-client |
| php-fig | 6 | 0 | 14 | 4 | active small team despite no critical packages currently active; the PSR project, mostly finished work |
| doctrine | 6 | 14 | active | active | active distributed alongside 6 bernies |
| thephpleague | 5 | 11 | active | active | active distributed alongside 5 bernies |
| sensiolabs | 4 | 0 | 7 | 0 | wound down: absorbed into Symfony |

The org activity data confirms what the migration patterns suggest. zendframework has 15 historical maintainers but zero active; sensiolabs has 7 historical and zero active. Both have completed their migrations to a successor and no maintenance happens on the old org accounts any more.

## the individual side is small

| individual | bernies | active in set | activity status | reading |
|---|---:|---:|---|---|
| sebastianbergmann | 6 | 20 | engaged (6 active_maint, 33 push 30d) | 20 currently active critical packages (PHPUnit and its surrounds) alongside 6 bernies |
| seldaek | 2 | 1 | engaged (5 push 30d, 15 push 365d) | Composer's lead; bernies are old Symfony bridges |

Beyond those, no individual holds more than two non-active packages. The personal-account-with-many-bernies pattern that dominates npm barely registers in packagist. Of packagist's 22 bernie-holding individuals, 18 are engaged, 2 trickling, 2 quiet, 0 gone.

## funding observations

Symfony, Doctrine, ReactPHP, Composer and sebastianbergmann all publish funding links. Each of those accounts has many currently active critical packages in the set. No equivalent to the npm pattern (high bernie count, zero active in the critical set, GitHub Sponsors) appears under any packagist account.

## what this means for outreach

The packagist bernie set is the easiest of the major ecosystems to triage. Most of the org-owned bernies have an obvious successor named in the Composer metadata (`replace`, `abandoned`), and Composer surfaces this to the developer running `composer update`. Where the metadata isn't set, a polite issue on the project-owning account is usually enough to either get it set or get a confirmation that the package is no longer the active home.

For the remediation taxonomy in [`../findings/README.md`](../findings/README.md), the packagist owner picture is what supports the 38% switch share, the highest of any ecosystem here. The migration clusters (zendframework → Laminas, sensiolabs → Symfony, swiftmailer → symfony/mailer) leave bernies whose remediation is unambiguously switch-to-named-successor, and Composer's `replace`/`abandoned` metadata fields surface that to dependents without any per-package conversation. For the remaining bernies under still-active orgs (symfony, doctrine, league), outreach about a specific sub-package lands on a team that's still curating other critical packages, which makes adopt and switch-piecemeal conversations more likely to produce a useful answer than in ecosystems with more individual ownership.
