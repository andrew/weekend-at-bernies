# cargo owners

811 critical cargo packages from 118 distinct owners.

| | organisation | individual | unknown |
|---|---:|---:|---:|
| owners | 37 | 76 | 5 |
| packages | 451 | 339 | 21 |
| non-active packages | 63 | 104 | 10 |
| non-active % | 14.0 | 30.7 | 47.6 |

The 14% org rate is the lowest in the dataset for any ecosystem over 500 packages. The absolute count of org bernies is small, so cargo's bernie set is primarily individually owned.

## individuals dominate the cargo bernies

| owner | kind | bernies | active | reading |
|---|---|---:|---:|---|
| rust-num | organisation | 8 | 0 | single-person org: cuviper holds 99% of historical maintainer activity, 1 currently active |
| smol-rs | organisation | 7 | 10 | active small team; top maintainer (notgull) holds 61% of activity |
| burntsushi | individual | 6 | 9 | bernies are older small crates; nine other critical crates active |
| retep998 | individual | 5 | 0 | winapi bindings; no active critical crates under this account |
| dtolnay | individual | 5 | 27 | 27 active critical crates; bernies are small historic helpers |
| tokio-rs | organisation | 4 | 24 | active distributed: 60 historical maintainers, 21 currently active, top maintainer holds 14% |
| sergiobenitez | unknown | 4 | 0 | Rocket author; no active critical crates under this account |
| rust-lang-nursery | organisation | 4 | 0 | wound down: the nursery namespace, intended to be moved out of |

tokio-rs has the most-distributed maintenance of any cargo org here (21 active humans, top maintainer holds 14% of total activity). rust-num is the opposite extreme: effectively a single-person org around cuviper. rust-lang-nursery has zero active maintainers, matching its public role as a deprecation namespace.

## the all-bernies-no-active individual tail

Several individuals own multiple non-active critical crates and zero active ones in the set. Two of them publish funding links:

  * `someguynamedjosh`: 2 bernies, 0 active in set, GitHub Sponsors.
  * `hawkw`: 2 bernies, 0 active in set, GitHub Sponsors. Engaged on the activity check (14 active_maint, 1 push 30d, 5 push 365d), so the funded work is presumably elsewhere.

Activity check for cargo's 76 bernie-holding individuals: 43 engaged, 16 trickling, 17 quiet, 0 fully gone. The quiet bucket is unusually large at 22%, matching the cargo pattern of small focused crates that get finished and stay finished; the author may be active on other rust projects without touching the bernie crates again.

## funding observations

The cargo funding picture is less suggestive than npm's. The top funded accounts (burntsushi, dtolnay, tokio-rs, hyperium, seanmonstar) all have many currently active critical crates in the set. There are few high-bernie-count accounts drawing recurring sponsorship, and the all-bernies cohort mostly does not publish funding links.

## what this means for outreach

The Rust ecosystem has explicit institutional handling for old crates: `rust-num`, `rust-lang-nursery`, and `cargo-deprecate` annotations. Many of the org-level bernies have already been routed through those mechanisms. The leftover work is mostly individual-author one-purpose crates, where vendoring is usually the right answer.
