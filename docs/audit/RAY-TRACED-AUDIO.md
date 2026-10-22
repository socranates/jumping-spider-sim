# Acoustic simulation for The Windowsill

Research only, 2026-10-22. No runtime audio changes or performance claims. Requested during the foundation audit; candidate source remains frozen at `5ee048a` / `c7af2726574c44cc`.

## Recommendation

Try Roblox's built-in Acoustic Simulation in a small, separate prototype before considering a custom sound ray tracer. The desired result is spatial presence: a wasp becomes muffled behind the hut wall, its buzz reaches the player around an open doorway, and the room contributes restrained reflections. These are proposed listening tests, not effects verified in our build yet.

Roblox announced full release on September 22, 2026. It supports occlusion, diffraction and reverberation through the advanced Audio API. The announcement still describes legacy `Sound` support as work in progress. This does not establish a particular ray-tracing implementation, GPU requirement or physical accuracy at spider scale. [Official announcement](https://devforum.roblox.com/t/full-release-acoustic-simulation-emit-audio-with-presence/4307121), [official weekly recap](https://devforum.roblox.com/t/weekly-recap-september-21-25-2026/4894110).

## Current game integration

`roblox_port/src/Client/Soundscape.luau` creates legacy Sounds for the wasp and other ambience; `Client/TrainPass.luau` also uses Sound. A source search found no existing AudioEmitter/AudioListener/acoustic simulation setup. The Soundscape header explicitly keeps audio separate from senses, AI and simulation time; preserve that contract.

The modular path is `AudioPlayer -> Wire -> AudioEmitter`, then spatial propagation to `AudioListener -> Wire -> AudioDeviceOutput`. Non-spatial music can go directly from a player to output. Both emitter and listener participate in the acoustic feature; SoundService provides its global enable. Validate the current API in the installed Studio before writing the adapter. [Audio objects](https://create.roblox.com/docs/audio/objects), [AudioEmitter](https://create.roblox.com/docs/reference/engine/classes/AudioEmitter), [AudioListener](https://create.roblox.com/docs/reference/engine/classes/AudioListener), [SoundService](https://create.roblox.com/docs/reference/engine/classes/SoundService).

This is a migration of one audio path, not a checkbox that improves all existing Sounds. Preserve asset permission checks, volume preferences, pause behavior, music ducking and resource cleanup. Reuse the existing wasp asset for the first test; no new upload is necessary to attempt it.

## Geometry and listener choices

BasePart.AudioCanCollide controls acoustic obstruction/reflection independently of physical collision. Audit our invisible support boxes and visible scenery so two representations do not accidentally behave like two walls. Exclude spider hairs, tiny decorative particles, audio source holders and duplicated proxies where appropriate. Keep intentional solid walls and door geometry. Never change CanCollide/CanQuery to tune sound. [BasePart reference](https://create.roblox.com/docs/reference/engine/classes/BasePart).

Prototype a listener at the spider rather than blindly using the third-person camera: the camera can pass outside a room while the spider remains inside. Compare orientation tied to camera versus spider for comprehensible stereo direction. This is a design choice to test, not a documented requirement.

Our scale is one stud per centimetre. Test the hut, can and Crack instead of assuming ordinary human-room reverb settings suit them. SoundService.DistanceFactor is documented for legacy Sound Doppler; it is not a demonstrated solution for advanced acoustic scale. The installed Studio API probe confirms `PhysicalProperties.AcousticAbsorption` exists. Test its constructor/update behavior before tuning it, preserving density, friction and elasticity.

## Bounded first experiment

1. A separate branch/local test flag, off by default. One stationary source followed by the existing moving wasp. One listener and output graph; cap the prototype at four active spatial emitters. Four is our initial budget, not a Roblox platform limit.
2. Walk the same route with legacy and simulated audio: room centre, opposite side of a wall, open door, around a corner, Crack entrance, and inside/outside transition. Listen on headphones at matched source volume.
3. Capture frame-time median/p95, audio-related profiler work, memory, startup and emitter creation/destruction. Repeat full/low detail and a physical phone when available. Keep a legacy fallback until these measurements justify release.
4. Check mute/volume controls, looping, pause/resume, slow motion, source deletion, repeated region crossings and respawn. No duplicate listener, double-playing source, lingering wire or disconnected silent graph.
5. Assess whether the wasp remains understandable as a threat. Acoustic quality can adapt to device performance, so simulated audibility must never drive deterministic predator senses, damage or hunt outcomes. Keep visual information usable independently.

Music, menu sounds and bite feedback need not all become spatial. A wider rollout could later include the cat's bell, passing train and rain outside the hut, but each needs its own mix check. This research does not authorize or implement those changes.

## Acceptance and remaining questions

Accept only if the doorway/wall distinction is clearly audible without distracting pumping or stereo jumps, existing volume controls work, and measured frame times stay within the game's agreed device budgets. Record actual numbers before choosing a platform default. There are no before/after audio measurements yet.

Open questions: material tuning and correct small-scale reverberation; streamed-out geometry behavior; camera-versus-spider listener comfort; performance on Nathan's laptop and phone; whether useful threat cues remain understandable when quality adapts. Resolve in the prototype, after the foundation correctness checks, rather than changing the current audit candidate.

## Installed Studio API check

After stopping the completed native self-test, an edit-mode probe created only unparented temporary AudioEmitter, AudioListener and Part instances, read their properties, and destroyed them. `audio-api-probe.txt` records global simulation **false**, emitter/listener participation **true**, Part.AudioCanCollide **true**, and default-part AcousticAbsorption approximately **0.3**. This confirms API availability in the installed Studio; it does not establish audible output or performance. No setting, source module or published place was changed.
