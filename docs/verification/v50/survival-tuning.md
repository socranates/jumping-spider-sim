# Survival tuning and test contract

Published v49 Normal was not immortal in the reproduced model. From reserve0.55
it died after59.2 game hours; full68.4, empty48.4 at the diagnostic's60x clock.
Its grace was48 empty-reserve hours. Nathan's played mode is unknown. The correct
diagnosis is long grace; do not claim to have reproduced his exact session.

Live v50 uses weakness after6 empty-reserve hours, death after12. Drain rates,
starting reserve0.55, feeding grants and gentle floors are unchanged. A fresh,
unfed Normal spider is bounded by72 game hours even using the cheaper sleeping
drain: 1/(0.007*2.4)+12 =71.524h. Actual awake/default reserve dies sooner. Clock
integration adds a bounded tick/2Hz quantization margin; tests allow72.5h at60x.
This is game pacing, not a biological starvation claim.

The live client explicitly calls LifeLoop:useGameRules at startup, fresh life and
checkpoint restore. Legacy pure controllers retain24/48h for frozen Godot
fixtures. Tuning is not serialized as a new unlock or a new save schema. Existing
starving streaks remain meaningful under the new deadline; old already-starving
Normal saves can therefore reach death sooner after updating.

The new suite covers empty/default/full reserves, resting and awake, Normal and
gentle, including an actual NeedsModel/LifeLoop record roundtrip during each
case. Rest restores rest reserve only. It cannot refill hunger. Gentle cases
survive beyond75h at zero. Death emits once. Tiny meals still use the existing
proportional starving-streak relief; no reset exploit was introduced.

Real-client checks press the actual Feed action, verify partial nutrition and
animated mouth placement, then prove starvation reaches the caught/death panel
and a session summary with cause=starved. Free play survives the same forced
streak. Native SelfTest adds the scripted capture and death handler checks.

Returning to an earlier retreat checkpoint intentionally replays that earlier
world/time; this change does not replace the existing checkpoint design with an
irreversible ironman clock. The deadline applies to elapsed play on the current
timeline, not repeated rewinds to a prior well-fed save.
