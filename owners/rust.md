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
| rust-num | organisation | 8 | 0 | older numerics crates, several have named successors |
| smol-rs | organisation | 7 | 10 | async-runtime org with old auxiliary crates |
| burntsushi | individual | 6 | 9 | bernies are older small crates; nine other critical crates active |
| retep998 | individual | 5 | 0 | winapi bindings; no active critical crates under this account |
| dtolnay | individual | 5 | 27 | 27 active critical crates; bernies are small historic helpers |
| tokio-rs | organisation | 4 | 24 | bernies are minor sub-crates against 24 active |
| sergiobenitez | unknown | 4 | 0 | Rocket author; no active critical crates under this account |
| rust-lang-nursery | organisation | 4 | 0 | the nursery namespace, explicitly intended to be moved out of |

The active-in-set numbers split this list cleanly. burntsushi, dtolnay and tokio-rs all hold many currently active critical crates alongside their bernies; rust-num and rust-lang-nursery are well-known historical buckets that the Rust community already treats as "look elsewhere first."

## the all-bernies-no-active individual tail

Several individuals own multiple non-active critical crates and zero active ones in the set. Two of them publish funding links:

  * `someguynamedjosh`: 2 bernies, 0 active in set, GitHub Sponsors.
  * `hawkw`: 2 bernies, 0 active in set, GitHub Sponsors.

This says nothing about what the same accounts may be doing outside the critical set; it only describes the critical-package footprint.

## funding observations

The cargo funding picture is less suggestive than npm's. The top funded accounts (burntsushi, dtolnay, tokio-rs, hyperium, seanmonstar) all have many currently active critical crates in the set. There are few high-bernie-count accounts drawing recurring sponsorship, and the all-bernies cohort mostly does not publish funding links.

## what this means for outreach

The Rust ecosystem has explicit institutional handling for old crates: `rust-num`, `rust-lang-nursery`, and `cargo-deprecate` annotations. Many of the org-level bernies have already been routed through those mechanisms. The leftover work is mostly individual-author one-purpose crates, where vendoring is usually the right answer.
