# Moult counter and home prompt — 2026-10-23

Player decision: keep existing growth rules and display actual progress. First moult remains seven housefly-equivalent meals, second ten; the adult moult remains five in Normal or three in gentle modes. Partial food credit is retained. The compact Preserve HUD now shows a small line beneath the wordless hunger bar, derived from saved Growth state rather than another persistent counter. It shows readiness, changes to “Moulting” during the moult, and disappears at adulthood and during modal screens, inspection or death. No future movement unlocks are advertised.

At dusk, the contextual prompt says “It is getting dark. Find a home for the night.” It uses the existing eight-second display budget per night, clears after resting, and keeps the correct device-specific rest button at existing shelters. The current Control Hints opt-out still applies; eating/weakness prompts retain priority.

Future player direction: add suitable places around the map that can be lined with silk and made into homes/checkpoints. This change only adds the message; it does not add buildable homes or alter checkpoint/save behavior. That later feature needs explicit shelter eligibility, construction/completion state, safe rest validation, and persistent checkpoint integration.

Verification: automated shim checks cover growth-derived counters, partial credit, save/load equivalence, mode thresholds, stage reset, readiness and adulthood, plus real Preserve client HUD wiring. Dusk tests cover wording, timeout, correct rest control, dismissal, midnight continuity, the following dusk, and blocked screens. Native Studio appearance/playtesting and publication remain pending.
