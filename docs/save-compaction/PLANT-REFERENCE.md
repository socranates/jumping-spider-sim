# Animated vegetation reference

Nathan supplied [How To Create Animated Plants With Shaders](https://www.youtube.com/watch?v=R-bjXOEQyX8) during the save-compaction work. The web read exposed its title but no usable transcript. No claim is made to have watched it or verified its implementation.

Current `Client/LivingWorld.sway` updates at most 28 nearby parts on full detail and eight on low. It already sets Workspace.GlobalWind, and respects the game's reduced-motion choice. The remaining cost needs measurement before a replacement.

Roblox documents built-in GlobalWind animation for terrain grass and clouds, with particle support as described in its wind guide. That is a useful option to investigate for non-walkable distant decoration; it does not replace our close, individually placed leaf collision and presentation code. [Official wind guide](https://create.roblox.com/docs/environment/global-wind), [terrain grass](https://create.roblox.com/docs/building-and-visuals/studio-modeling/terrain).

For a later vegetation pass: retain the rich close silhouettes and stable walking surfaces, profile sway separately from detail rebuilding, compare stationary/animated views, check reduced motion and both tiers, then select an engine-supported implementation. This reference does not authorize changing the liked lighting or replacing the habitat with sparse terrain grass.
