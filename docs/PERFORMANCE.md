# Performance measurements

**Desktop only, 21 September 2026. No Android device was available.**
Godot 4.3, Compatibility renderer, Mesa llvmpipe LLVM 20.1.2 software rendering,
480 × 900 viewport, shadows enabled. Same deterministic fixture: 24 mature plants,
12 placed decorations, estate landscaping and HUD. Warm-up: four seconds; sample:
90 frames. Raw results: `performance-desktop.json`.

| Metric | Individual pieces | Batched pieces |
|---|---:|---:|
| Mean draw calls / frame | 3,460.6 | 478.1 |
| Live scene nodes | 1,113 | 380 |
| Median frame interval | 47.08 ms | 45.12 ms |
| 95th percentile frame interval | 54.97 ms | 60.66 ms |
| Mean rendered primitives / frame | 334,763 | 358,337 |

Draw calls fell **86.2%** and node count **65.9%**. Frame timing is noisy on the shared
software renderer, and the upper percentile worsened; these numbers do **not** prove
an Android FPS target. Batching also draws more primitives because culling operates
on combined pieces instead of individual details. This is an explicit tradeoff.

## Changes

- AssetFactory caches primitive meshes and materials, then merges static pieces.
- Flat, opaque colors become vertex colors in one surface per object; textured or
  emissive art preserves its material. Plant roots still sway independently.
- The static estate is batched; crop/decoration objects batch separately for swaps.
- Twenty-four plot holders remain alive. Soil rebuilds only when ownership changes;
  plant models swap only when the species/genes or growth stage changes.
- Three reused GPUParticles emitters, 24 particles each: **72 maximum** at full detail,
  36 at half detail, zero when off. No unbounded burst-node spawning.
- Codex/shop pages contain at most twelve species cards instead of all 120 at once.

Reproduce on a desktop display with `python tools/profile_garden.py --godot /path/to/godot`.
The two runs differ only in the batching toggle. Files under `builds/profile` are
isolated from normal saves. Never point the fixture at a player's save.

## Required Android follow-up

1. Connect a named mid-range ARM64 device; record model, SoC, Android version and
   thermal/battery conditions. Install the Godot 4.3 export templates and SDK.
2. Export a debug build with the Mobile renderer; deploy with remote debugging.
3. Populate all 24 plots and 12 decor sites, matching `tests/performance_capture.gd`.
   Keep camera, resolution, shadows and growth stages identical between runs.
4. Record Godot's rendering monitors (draw calls, primitives, CPU/GPU frame time)
   for 60 seconds after warm-up, plus memory, loading, touch pan/pinch and pause/resume.
5. Compare default batching against project setting
   `monster_garden/rendering/batch_meshes=false`, then restore it to true. Repeat at
   half/no particles and shadows off if needed. Confirm no thermal throttling.
6. Exercise harvest/discovery/level-up bursts together; active particles must remain
   within the cap. Test reminders only with the native Android plugin installed.

No device figures, signed build, native reminder delivery or Mobile-renderer pass
are claimed by the desktop benchmark.
