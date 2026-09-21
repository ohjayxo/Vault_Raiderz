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
