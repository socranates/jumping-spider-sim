# Continuous mound crossing, before the lawn-cover follow-up

Native Studio 0.744, production source `80096ec`. The same ordinary-control route runs at full and low detail, in Free play with observer placement. It starts at (-182, -84.29, -190), walks Forward for 5.4 seconds to the earlier problem pose, holds three seconds, continues Forward 6.6 seconds, walks Back for twelve seconds and holds again. No camera override, input assistance or movement-rule change is used. The exact driver is `studio-mound-travel-before-lawn.luau`.

Every phase ends attached and alive. The former endpoint at (-182, -83.89, -203.54) keeps the body visible for the entire three-second hold at both tiers, with the normal camera about 5.16 cm away after settling. The final return is within 0.104 cm of the start. The outward leg proceeds beyond the mound to the next herb-bed wall, where the controller attaches to the vertical face; this is part of the surrounding route, not a fall.

## Local frame samples

| Phase | Full mean/worst ms | Low mean/worst ms | Full/low maximum consecutive body-hide seconds |
| --- | --- | --- | --- |
| Approach | 16.72 / 34.42 | 16.67 / 25.42 | 0.186 / 0.185 |
| Previous endpoint, stopped | 16.67 / 26.49 | 16.90 / 27.39 | 0 / 0 |
| Beyond mound | 18.90 / 34.12 | 16.86 / 29.89 | 0.195 / 0.182 |
| Return | 19.14 / 69.46 | 16.74 / 53.71 | 0.205 / 0.186 |
| Returned, stopped | 25.34 / 43.11 | 16.67 / 18.67 | 0 / 0 |

There are brief body-hide and off-screen transitions while negotiating the steps. No sampled physical camera-to-body ray is obstructed beyond the 0.4 cm endpoint tolerance. These metrics do not prove pixel-perfect visibility through nonqueryable decorative foliage. They establish that the previous hidden endpoint is not a sustained state after the camera settles. The existing camera behaviour is retained, consistent with the user's approval of its feel.

No heavy CLI work overlaps these samples. The full tier's slower final sample and whole-frame variability are retained in the evidence; this is not a constant-60-fps or phone-performance claim. Raw telemetry: `mound-travel-native-before-lawn.txt`. Normal views: `mound-travel-full-return.jpg`, `mound-travel-low-before-lawn.jpg`.

## Visual finding and next comparison

The low-detail return view still has little close upright lawn cover. LivingWorld's grass selector handled verge/meadow soft ground but excluded the station garden's own lawn. The follow-up extends it using Hut's existing surface classifier, retaining the existing part ceilings and avoiding paths, beds and hard props. Current-source comparisons use `studio-mound-travel-review.luau` and a distinct `CHET_MOUND_LAWN_*` prefix, with grass-count/part-count fields appended. These results must be reviewed separately; the old samples above do not cover that later change.
