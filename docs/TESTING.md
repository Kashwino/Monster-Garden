# Verification and editor acceptance

Tested with the official **Godot 4.3 stable Linux binary**. All six suites pass:

| Suite | Checks | Coverage |
|---|---:|---|
| `run_tests.gd` | 30 | Foundation economy, planting, gene stacks, saves and corruption protection |
| `phase2_tests.gd` | 85 | 120 species, unlocks, breeding, quests, orders, offline, boosters, decorations, v1/v2 migrations |
| `tutorial_tests.gd` | 11 | Six steps, matching growth target, offline resume, completion and skip |
| `cloud_tests.gd` | 11 | Conflict resolution, heartbeat equality, network failure, ETags, concurrent local changes |
| `art_tests.gd` | 616 | All species/stages, real GLBs, catalog-only swap, fallback and gene isolation |
| `settings_tests.gd` | 7 | Saved audio/graphics, actual mute, reset currencies/plots, newer save stamp |

**760 headless checks, zero failures.** Editor import also passes.
The separate rendered `ui_flow.gd` suite adds **17 passing checks**: pointer input
completes the entire six-step tutorial through its actual masks, menus and buttons.
Growth is accelerated through the same gem command used by players. The real rendered UI smoke
test opens eight panels and dispatches a synthetic touch through the viewport to
select plot 6. Screenshots are actual Godot captures, not mockups.

Run `GODOT_BIN=/path/to/godot python tools/verify.py`. It uses a disposable save under
`builds/`, reports script errors even if the engine exits zero, and writes logs there.
Individual script paths may be passed after `tools/verify.py`.

## Test each system in the editor

| System | What to try |
|---|---|
| 1 · Art | Edit only Witness Bud's blooming GLB path in the catalog. Run and compare. Set a nonexistent path to verify the family fallback. |
| 2 · Species | Open Seeds and Codex; filter ten families and page through 120 entries. Level-locked purchases stay disabled. Events expose UTC windows. |
| 3 · Breeding | Reach level 2, buy the bench, harvest two crops and graft. Inspect the seed's glow, plant it free, harvest it and compare genes. Bright, large same-family parents can discover a rare species. |
| 4 · Quests | Open Goals. Harvest, claim the first quest once, then fulfil an order for its successor. Three daily goals reset by stored UTC date. Automated tests advance the date without changing the device clock. |
| 5 · Orders | See three couriers; deliver and reroll a slot. At reputation 10/30, mixed/gene requests appear. Let an order expire: reputation falls once and the slot enters its cooldown. |
| 6 · Offline | Plant, close for 30+ seconds, reopen: the crop is ready and the summary reports completions. Android reminder scheduling requires the native plugin described below. |
| 7 · Boosters | Open Seeds → Gems & fertiliser. Apply fertiliser once, observe shorter remaining time, finish using gems and verify repeat finish cannot charge again. Locked plots still require their level. |
| 8 · Cloud | Default is offline/local. Run cloud tests for conflict/failure cases. Configure your own Firebase project for live testing, following CLOUD_SAVE.md. |
| 9 · Estate/audio | Start with six plots. Buy a level-1 lantern, place it at a named site, move it, return it to storage. Harvest, sell and level up to see feedback and hear sounds. |
| 10 · Tutorial | New save: complete plant/wait/harvest/sell/order/breed, using Close to gather more crops as needed. Reopen during the wait. Skip once; it stays skipped. Old saves do not replay onboarding. |
| 11 · Settings | Change volumes, shadows and particles, then reopen. Try canceling Reset before confirming it. A confirmed reset creates exactly six owned starter plots and a new save timestamp. |

The first order needs two Witness Bud crops. Selling one from the tutorial harvest
leaves one; harvest the mature starter as well. The order tutorial grants enough XP
and coins to reach the bench. Harvest the starter Murmur Cap for another parent.

## Save compatibility

Schema increments were committed with each system. The actual pre-change v1 and v2
fixtures were loaded through `SaveManager.load_data()` after each system; plot data,
inventory, gene values and coins are compared without loss. The old flat v0 inventory
fixture is also covered. Added plot sites are appended during restoration: old owned
plots remain owned. New systems receive migration defaults. Tests never overwrite a
normal player save.

## Notification seam

Optional Android singleton `MonsterGardenNotifications` must implement:
`request_permission()`, `schedule_ready(unix_seconds)`, `cancel_ready()`.
Scheduling chooses the longest pending crop completion. The editor is a no-op.
Native notification code, OS permission behavior and delivery are not validated here.

## Limits of this verification

The project defaults to Mobile, but this execution environment cannot create a Vulkan
surface. Visual checks use **desktop Compatibility / Mesa llvmpipe**. The supplied
Android preset is source configuration, not a built or signed APK. No physical Android
device, native notification plugin, store SDK or live Firebase account was available.
Cloud tests simulate HTTP responses; they do not establish a live service connection.

Godot's dummy headless renderer can emit null-mesh cleanup errors during art tests;
these are separate from GDScript errors and the explicit test verdict. Desktop visual
runs may report pending objects on immediate test shutdown; the benchmark's final
batched run exits without that warning.
