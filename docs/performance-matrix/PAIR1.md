# Four completed native runs, descriptive comparison only

2026-10-24. All four276-source models completed nine workload samples and
authoritative native PASS, with source guards before and after Play,0 CreatorErrors,
8 retained warnings each and save-fixture cleanup. They used viewport1360x436,
fixed weather clocks, ordinary live creatures and the same look-method watcher.
No UI snapshots or heavy local commands ran during measured windows.

| Variant | Native run | Workload frames | Frames >50ms | Scene mean range ms |
|---|---|---:|---:|---:|
| after/full |1792824522568|12616|0|16.66-18.64|
| before/full |1792824986522|12673|2|16.67-19.67|
| after/low |1792825466424|13156|0|16.66-17.27|
| before/low |1792825826218|13095|2|16.67-18.23|

Each includes an on-screen frog at5.010studs, active damselflies and a roughly
150stud garden_a1/a2/a3 walk ending alive/attached. No claim of continuous
support follows: these short observers only recorded the final motor mode.
Startup is separate and retains large gaps; it is not fixed by these runs.
Warnings are the same style/asset/fixture-transport categories as attempt3.

pair1/ retains original bounded native output, parsed data and each manifest.
pair1-builds.json is the earlier immutable preparation record; its
native_executed=false means not yet executed AT THAT PREPARATION checkpoint.
These later native records supersede that status without changing its hashes.
pair1-comparison.json/.md derive all18 scene rows and actual look-method timings.

The comparator refused to qualify the views: actual FOV differed by0.04266
degrees between full runs and0.16454 between low runs. All18 mismatches are
retained at the original .01 tolerance, conditions_matched=false. It did not
relax the threshold to pass. Other observed camera/state/actor conditions
matched within the stated bounds. Frame changes are mixed and are descriptive
only: one pair per tier cannot establish a causal/general FPS improvement.
Low detail is mostly at the60Hz limit. The camera defect exposed by this work
is documented separately in ../camera-handover/README.md; these four source
cohorts PRECEDE that fix. Do not overwrite or reclassify them as corrected runs.

The collector's original requirement for work() in every sample was incorrect:
LookStream returns early with no jobs, so quiet scenes legitimately execute
dew() alone. --require-methods now demands an observed known look method with
positive calls per sample; it still rejects the uninstrumented attempt3 cohort.
No runtime input or original measurement changed to repair collection.
