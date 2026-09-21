# Design changes made during the build

These were applied directly to `docs/` (v5.7, 2026-09-20, with Josh's double
confirmation). **The separate design project still has the old text**: make
the same changes there before the next copy-in, or it will overwrite them.

## v5.7 (2026-09-20)

1. **D111: pickaxes are not tradeable; pickaxe skins are** (supersedes D21).
   Changed: `07-decisions.md` (new D111, D21 marked superseded, D65/D66/R3/
   rejected-options table reworded), `05-items.md` (Taxonomy row, governing
   split, § Gear is tradeable → § Pickaxes are not tradeable, § Loss rules),
   `06-economy.md` (Fragments-only tradeable paragraph).
2. **D92 wording fix:** gear score counts pickaxe upgrade nodes (Extraction /
   Combat / Mobility), not Tech Path nodes. Changed: `07-decisions.md § D92`,
   `05-items.md § Gear score`.
3. **Level curve [PH]:** XP to reach track level n = floor(100 × n^1.5);
   Vaultbreaker Level = sum of track levels; Level derived from XP, not stored.
   Changed: `03-progression.md § Vaultbreaker Level`, `07-decisions.md § D80`
   (build note).
4. Housekeeping: `10-roadmap.md` v5.7 history row; `12-nexus.md` registry
   D1–D111, next D112; `CLAUDE.md` docs-edit rule (double confirmation).

5. Follow-ups (confirmed separately): `08-questions.md` Q17 answer now "No
   (D111)"; `00-README.md` bumped to v5.7; `12-nexus.md` v1.7 history row.
6. **D112: armor in the slice.** Craftable pieces, one chest slot, pickaxe tier
   names, knockback resistance + small damage reduction [PH], spares stealable
   / worn never (R1), not tradeable (armor skins are), gear score + highest owned
   armor tier × 10. Changed: `07-decisions.md` (new D112, D92), `05-items.md`
   (Taxonomy row, new § Armor, § Gear score), `10-roadmap.md` (slice table row,
   v5.7 row), `12-nexus.md` (registry D1–D112, next D113; v1.8 row).

## Step 2 design-gap answers (2026-09-20) — NOT yet in `docs/`

Josh's calls while building nodes + Grade. Bring them to the design project;
`docs/` is unchanged until he double-confirms an edit.

1. **Grade is rolled per hit**, not per node (`05-items.md § Why Grade
   carries so much` "every tap is a lottery ticket" vs `§ The Voltstone
   trickle` "a Volatile-grade Ore node"). Suggest rewording the Voltstone
   line to "a Volatile-grade Ore hit".
2. **Grade effects are seen by everyone**, as a short burst at the node
   (Prismatic rainbow column, Vaultborn beam). The 30 s head start still
   holds because the holder walks away. (`05-items.md § Roll 1` Visual column.)
3. **Vaultborn ranks in the middle of the D58 queue**: below raid-owner
   alerts and Chase pings, above cosmetic flex (`06-economy.md § Broadcast
   priority queue`).
4. **Head start interpretation:** the Vaultborn announcement goes out ~30 s
   [PH] after the strike (`05-items.md § Vaultborn announcement`).
5. **Node migration interpretation (D38):** a depleted Reaches node returns
   after a random 45–90 s [PH] at a *different* spawn point; Homestead nodes
   return at the same spot after a fixed 30 s [PH].

## Flagged for redesign (step 2 review, 2026-09-20) — Josh will revisit

Not decided yet. Take these to the design project; the build keeps the
current behavior until then.

1. **Vaultborn beam vs "zone-level, not coordinates" (review M2).** The
   beam appears at the exact node, instantly, for every player, while the
   announcement is zone-only and 30 s late (`05-items.md § Vaultborn
   announcement`, `§ Roll 1` Visual column). The beam gives away the
   position the announcement hides. Options to weigh: beam seen only
   nearby; beam delayed to match the announcement; no beam for Vaultborn;
   keep as is (the holder can walk away).
2. **Riftsalt placement is enforced only by map data (review L1).**
   `05-items.md § The Riftsalt rule`: "contested zones only". Today it holds
   only because no Homestead spawn point is a Riftsalt one. Design question
   first: which zones count as "contested" (Reaches only? Rift later?) and
   should zones carry that as data? Then a start-up check can refuse a
   Riftsalt spawn anywhere else.
