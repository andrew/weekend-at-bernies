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

| organisation | bernies | active | reading |
|---|---:|---:|---|
| symfony | 11 | 79 | 79 currently active critical packages alongside 11 bernies |
| zendframework | 6 | 0 | superseded by Laminas; account exists for historical artefacts |
| php-http | 6 | 2 | HTTPlug-related; most live work moved to symfony/http-client |
| php-fig | 6 | 0 | the PSR project, finished work; non-active by intent |
| doctrine | 6 | 14 | 14 currently active critical packages alongside 6 bernies |
| thephpleague | 5 | 11 | 11 currently active critical packages alongside 5 bernies |
| sensiolabs | 4 | 0 | absorbed into Symfony |

Several of these are completed work rather than abandoned work. php-fig defined the PSR interfaces and is intentionally done; zendframework completed its rebrand to Laminas and the old account is a tombstone; sensiolabs is now part of Symfony. A bernie classification here is technically accurate (no recent activity) but commercially uninteresting (the maintained successor is obvious and named).

## the individual side is small

| individual | bernies | active | reading |
|---|---:|---:|---|
| sebastianbergmann | 6 | 20 | 20 currently active critical packages (PHPUnit and its surrounds) alongside 6 bernies |
| seldaek | 2 | 1 | Composer's lead; bernies are old Symfony bridges |

Beyond those, no individual holds more than two non-active packages. The personal-account-with-many-bernies pattern that dominates npm barely registers in packagist.

## funding observations

Symfony, Doctrine, ReactPHP, Composer and sebastianbergmann all publish funding links. Each of those accounts has many currently active critical packages in the set. No equivalent to the npm pattern (high bernie count, zero active in the critical set, GitHub Sponsors) appears under any packagist account.

## what this means for outreach

The packagist bernie set is the easiest of the major ecosystems to triage. Most of the org-owned bernies have an obvious successor named in the Composer metadata (`replace`, `abandoned`), and Composer surfaces this to the developer running `composer update`. Where the metadata isn't set, a polite issue on the project-owning account is usually enough to either get it set or get a confirmation that the package is no longer the active home.
