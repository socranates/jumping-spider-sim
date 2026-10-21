# First preserve mesh library — 2026-10-21

Requested by Nathan through the v42/v43 handoff. Original Blender geometry, exported and uploaded by Chet using Nathan's installed Blender 5.2.2 LTS and Roblox Studio. These are small visual studies for Claude to integrate and refine; none is attached to the preserve yet. No `src/Shared/World/*` or habitat layout was edited.

## Verified Roblox assets

Owner: **socranates**. Model asset **105970842890511** (`preserve_first_set_cm`). Shared color texture **116765351721069**. Use the individual **mesh IDs** below for `SpecialMesh.MeshId`; the model ID is for inspecting the full library with Studio/InsertService.

| Asset | Mesh ID | Native size in studs (X, Y, Z) | Triangles |
|---|---|---|---:|
| Grass clump | `93421946013090` | 9.739530, 26.041445, 11.812691 | 1,400 |
| Milkweed leaf | `128470594939908` | 7, 2.125, 19.5 | 1,466 |
| Coneflower head | `136400030278193` | 10.344988, 3.975, 10.288317 | 4,948 |
| Bark chip | `90087253428470` | 4.599804, 0.684588, 9 | 1,496 |
| Stone | `93673725524671` | 5.345497, 1.815153, 3.794619 | 320 |
| Bench slat end | `109006316168913` | 14, 3.2, 10 | 188 |

All six actual `MeshPart.MeshSize` and `Size` values were read from Roblox after upload and matched the authored dimensions to **0.00001 stud**. Six `SpecialMesh` instances were then made from their IDs; `ContentProvider:PreloadAsync` reported Success for every mesh and texture, ending `[CHET_SPECIALMESH_END] 6 0`. These checks ran in the signed-in owner's Studio session, in the playtest place. A published-client check after integration is still required; another account's inventory access is not implied.

The probe assigned IDs and loaded their content in Studio's edit context. It was not a rendered integration test inside a published client. Both inspected library models remained unparented (`Model nil`); no sample model was inserted into Workspace.

The set has seven curved grass blades, a leaf with raised midrib and lateral veins, a flower with drooping rays and a spiral of cone florets, a ridged closed bark chip, an irregular stone with a flattened base, and a bevelled slat segment. The palette is an original small texture atlas. These are intentionally modest geometry studies rather than final scanned/PBR assets. Their plant dimensions are authoring choices, not biological measurements.

## Rebuild and import

From `roblox_port`, run:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --python tools/meshes/build_preserve_meshes.py
```

Outputs are in `assets/meshes/`: editable `preserve_first_set.blend`, six individual FBX files, combined **`preserve_first_set_cm.fbx`**, color atlas, preview and `manifest.json`. The manifest records file hashes, dimensions, triangle counts and verified uploaded IDs. Rebuilding generates fresh FBX hashes and a fresh unsigned manifest; it does not upload or reuse the recorded asset IDs automatically. Preserve the uploaded manifest before a rebuild if you need that historical mapping.

Blender coordinates use **1 unit = 1 project stud = 1 cm**, +Z up. FBX export uses **global scale 0.01**, `apply_unit_scale=False`, -Z forward / Y up, baked space transforms, meshes only, no animation. Individual objects are centered at their bounding-box centers before export. The saved blend arranges the objects for the preview; exports happen before that arrangement. The texture is packed into newly rebuilt blend files, and FBX texture copies live beside the exports in their `.fbm` directories.

In Studio's Importer:

1. Select `preserve_first_set_cm.fbx`.
2. Import only as a Model; **Upload to Roblox on**, Creator **Me** (socranates), **Add to Workspace off**, package off.
3. File Geometry: **Scale Unit Stud**, **Scale Factor 1**. Check the actual imported dimensions afterward, not just the displayed unit label.
4. Import, copy the resulting model ID, load it without parenting it into the place and inspect its MeshParts. Record mesh/texture IDs and `MeshSize` as in the manifest.

**Discarded scale trial:** model `131555390945988` (`preserve_first_set`) and its six earlier meshes were oversized due to FBX's centimetre conversion and the importer's maximum-dimension normalization. Do not use them. They were never inserted in the place or integrated into code. Corrected exports have `_cm` on the combined filename and the model ID above. No cloud asset was deleted.

## Runtime integration contract

Claude owns integration in `World/PreserveLook` and near-detail patches. Coordinate before editing those files. Use a visual-only Part, not a replacement collider. `SpecialMesh.MeshId` is script-settable; preserve collision/query/touch behavior and budgets of the existing world.

```lua
local part = Instance.new("Part")
part.Anchored = true
part.CanCollide = false
part.CanQuery = false
part.CanTouch = false
part.Color = Color3.new(1, 1, 1)
part.Size = Vector3.new(7, 2.125, 19.5)
local mesh = Instance.new("SpecialMesh")
mesh.MeshType = Enum.MeshType.FileMesh
mesh.MeshId = "rbxassetid://128470594939908" -- milkweed leaf
mesh.TextureId = "rbxassetid://116765351721069"
mesh.Scale = Vector3.one -- natural authored size, independently of part.Size
mesh.Parent = part
```

For another size use `mesh.Scale = desiredSize / nativeMeshSize` component by component. `Part.Size` alone does not resize a FileMesh. Native Y is up; arrange poses with the existing visual transform. Parts should be white when using the atlas to avoid unintended tinting. Use the texture ID with these UVs; omitting it loses the flower's petal/cone color separation.

Keep the high-detail leaf and flower near the camera and retain low-tier primitives; do not multiply the flower's ~5,000 triangles across the whole preserve. Profile instance count, render frame time and transitions on the supported hardware before raising detail density. The geometry is decorative and does not make a sloped bank or change what a spider can stand on. Integration must retain the existing walkable boxes and all save IDs.

Official references checked this session: [Blender setup](https://create.roblox.com/docs/art/blender), [Importer](https://create.roblox.com/docs/studio/importer), [SpecialMesh](https://create.roblox.com/docs/reference/engine/classes/SpecialMesh).
