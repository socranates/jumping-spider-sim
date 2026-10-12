# One whole life, round 3: moulting (Claude, 2026-10-12)

Built while Chet's round 2 was paused, on Claude's branch, and merged after his round. Plan: `docs/LIFE_DESIGN.md`. Decisions: LIFE-10 to LIFE-12.

## What changed
- `scripts/life/growth.gd`: stages, readiness, the moult, the soft skin, old skins. It is saved in checkpoints (schema 5).
- `scripts/habitat/habitat_loop.gd`:
  - It reads food from the needs' ledger (`on_food`) and begins the moult when the spider rests while ready. While moulting, the rest cannot end.
  - Moult hours pass via `LifeClock.advance_moult`.
  - It places the old skins (`OldSkin0..2` under the habitat), makes the moult's checkpoint, and emits `moult_ready` and `moulted(stage)`.
  - The caption names the stage, with ready, moulting and soft lines.
- `scripts/core/main.gd`: `apply_reach()` is the player's jump-reach setting times the growth's reach factor (0.7 while soft).
- `scripts/presentation/spider_body.gd`: `set_softness()` makes the spider pale while soft.
- Notebook: three pages (`moult_ready`, `moulted`, `adult`).

## For Chet
**Drawn growth.** The rig is the same size at every stage. If Chet can scale the body and legs per stage without breaking the planted feet, the stage is `world.habitat_loop.growth.stage` (0 to 3). Physics and collider stay the same.

## Verification
Results and evidence: DECISIONS and SESSION_LOG. Stills: `docs/verification/life03/`.
