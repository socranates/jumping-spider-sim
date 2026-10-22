# Pinned Linux verification tools

The previous workflow fetched Luau/LSP from `releases/latest` and the Roblox definitions from `main`. Identical source could therefore be checked against different tools without a repository change. The workflow now names exact release URLs, an immutable definition commit and the checkout action commit. All four downloaded files must pass SHA-256 verification before extraction or execution. The runner family is Ubuntu 24.04; GitHub still updates that hosted image, so this is not a fully hermetic operating-system image.

Pins selected on 2026-10-22:

| Input | Version / identity | SHA-256 of downloaded bytes |
| --- | --- | --- |
| Luau Ubuntu archive | 0.743 | `99d45afb4afaee00ba631c526c8e8c76c67b60f6f119953ce6409be6d6953663` |
| luau-lsp Linux x86_64 archive | 1.70.1 | `1a2ea1ae4f98f8946cefd970a4b54853e11ab4775e6932faa7f60cf920346567` |
| Rojo Linux x86_64 archive | v7.7.1 | `00feb4fa0829a1dd72b49df2639da519a352bfe13cadcd83969e2ba2bb5693c4` |
| globalTypes.d.luau | commit `7a10f6d2dc6067934c66f9e3ad6cb4095594ac62` | `71698e2454aacef1a144a498ffc1d7ea80654b9593025344672bc9106997bf6a` |

The three archive hashes were read from official GitHub release asset metadata and independently matched against actual downloads (7,733,849; 4,475,341; and 5,832,480 bytes respectively). The definition file's downloaded 872,306 bytes were hashed directly. Checkout v4 resolved through the official tag API to `11d5960a326750d5838078e36cf38b85af677262` and is referenced by that commit. These establish the selected inputs; successful installation and game checks need the actual CI result.

Official sources: [Luau 0.743](https://github.com/luau-lang/luau/releases/tag/0.743), [luau-lsp 1.70.1](https://github.com/JohnnyMorganz/luau-lsp/releases/tag/1.70.1), [Rojo v7.7.1](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1), [frozen definitions](https://github.com/JohnnyMorganz/luau-lsp/blob/7a10f6d2dc6067934c66f9e3ad6cb4095594ac62/scripts/globalTypes.d.luau).

Validation: GitHub accepted workflow source `2b7f49982957c7aaad19bb5657a5e50d12a0ad52` in run [39767706811](https://github.com/socranates/jumping-spider-sim/actions/runs/39767706811), completed successfully at 2026-10-22T11:12:11Z. Actual retained logs show all four download checksums passed, 216/216 modules compiled at `-O0`, clean strict analysis, 63 suites / 443,469 checks / zero failures, and five passing runner regressions. `ci-final.json` binds these logs to the exact workflow/source and includes the successful job-step metadata. No production source or test expectations changed in that candidate. Windows retains its separately recorded local tool hashes; this change does not claim that its binaries or definitions equal the Linux pins. Later gameplay edits require their own gates.

To update: choose explicit upstream versions/commits, independently hash their downloaded bytes, replace URL and checksum together, and run the complete Linux gate. Do not restore a moving fallback, bypass a checksum failure or silently refresh hashes from a changed asset. Keep the prior receipt when a newer tool rejects source, and resolve the actual incompatibility before promotion.

The local attempt to parse YAML with Python found no installed PyYAML. No YAML-parse success is claimed from it; GitHub's actual successful execution validates this workflow. This work does not interrupt Studio or publish the game.

`fetch-ci.py` observes only that exact run and source. It exits 3 while the run is active, without dispatching another run. After success it retrieves the real logs through the existing Git credential, verifies all four checksum outputs, 216 compilations, 63 suite summaries / 443,469 checks, five runner regressions, and the successful job steps, then retains the bounded logs and a source/workflow/hash-bound receipt. Do not substitute an earlier branch's green result.
