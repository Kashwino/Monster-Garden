# Verification

Tested with the official Godot 4.3 Linux editor binary.

- Editor import: successful, including all five GLBs.
- Gameplay/save integration: 30 checks, zero failures.
- Art integration: 76 checks, zero failures.
- Original foundation save -> art schema migration: plants, inventory, coins unchanged.
- Missing GLB fallback and per-instance material isolation: verified.
- Actual rendered garden and all five panels: visually inspected on desktop Compatibility renderer.
- Synthetic touch through viewport input: selected the intended plot.
- Visual QA fixed inward GLB faces and portrait garden clipping.

## Editor acceptance path

1. Start a new garden, harvest the ready Witness Bud, then fulfil the first order.
2. Select empty plot 3, plant Witness Bud; observe seed, sprout, juvenile, mature,
   and blooming transitions over 30 seconds. No replant/reload is required.
3. Try harvesting early or planting into an occupied plot: neither consumes state.
4. Close while growing, reopen after 30 seconds; crop is ready and can be harvested once.
5. Sell crops, gain XP, unlock a new species and expand a locked plot at its level.
6. Open every tab; scroll the species catalog; pan and zoom behind closed panels.
7. Change only the catalog GLB path as described in ART_PIPELINE.md, then run again.
8. Replace that path with a nonexistent path: the procedural monster still appears.

Automated fixtures are isolated from player saves using MONSTER_GARDEN_SAVE_PATH.
To test the v1 fixture manually, copy it to a disposable path and launch the game
with that environment variable set to the copied file.

## Not verified / not claimed

The project remains configured for the Mobile renderer. This environment lacks
VK_KHR_surface, so visual QA used the desktop Compatibility renderer; Mobile
rendering could not be exercised here. There is no attached Android device,
Android signing key, or store account.
Physical touch behavior, device GPU performance, notification delivery and a signed
Android package have not been validated. Real-device draw-call/FPS measurements
remain part of the later performance phase; no numbers are fabricated here.
