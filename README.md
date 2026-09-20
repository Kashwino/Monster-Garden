# Monster Garden

A portrait isometric farming game about cultivating the beautifully strange.
Built with **Godot 4.3 / GDScript / Mobile renderer** for Android.

## Play in the editor

1. Clone this repository, open Godot 4.3, and import `project.godot`.
2. Wait for imports, then press **F6 on `scenes/Main.tscn`** or **F5**.
3. Tap the starter Witness Bud marked **READY**, then **Harvest**.
4. Select an empty plot and choose a seed. Commons grow in 30 real seconds.
5. Sell from **Basket**, or use **Orders** for double-value courier deliveries.
6. Gain XP, unlock stranger species, and expand the garden.

Touch: tap plots, drag to pan, pinch to zoom. Desktop: click, drag, mouse wheel.
The game saves after transactions, every 15 seconds, and when paused.
Growth continues while closed; reopen to see a completion summary.

## Implemented foundation

- Six open plots within a 16-plot floating garden, level/coin expansion.
- Twelve authored monster species, four silhouettes, five rarity tiers.
- Real-time timestamp growth, planting costs, harvested inventory, selling, XP.
- Gene-aware inventory stacks from day one (species + stable gene hash).
- A courier order with expiry and cooldown, catalogue/shop and field notes.
- Central procedural AssetFactory; plants pulse and pop into each growth stage.
- Versioned local JSON saves, backup, legacy inventory migration, future-version protection.
- Android ARM64 export preset. No paid services, store SDK, or account required.

This repository started empty. There was no previous game or real legacy save to inspect.
The legacy fixtures describe this project's supported schema; they do not claim compatibility
with an unseen earlier implementation.

## Android build

Install Godot **4.3 export templates**, OpenJDK **17**, and the Android SDK. Set the
Java SDK and Android SDK paths in Godot's Editor Settings, as described in the
[Godot 4.3 Android export guide](https://docs.godotengine.org/en/4.3/tutorials/export/exporting_for_android.html).
Create a `builds` directory, then use **Project → Export → Android → Export Project**
with debug export enabled for local device testing. The preset creates
`builds/monster-garden.apk` for ARM64. Release signing is intentionally not checked in.

No APK or physical-device performance certification is implied by the source preset.

## Automated checks

After importing in Godot 4.3:

```sh
MONSTER_GARDEN_SAVE_PATH=user://integration-test.json godot --headless --path . --script tests/run_tests.gd
```

The isolated test save is deleted afterwards. The future-version protection test
intentionally logs one save-version error. `RESULT: ... 0 failures` is the verdict.

## Architecture

| Module | Responsibility |
| --- | --- |
| `data/catalog.json` | Names, descriptions, families, economy, unlocks, genes, art specs |
| `Catalog` | Data loading and validation, stage/availability queries |
| `Game` | Plot commands, timestamp growth, session orchestration |
| `Inventory` / `Economy` / `LevelXP` | Gene stacks, atomic transactions, progression |
| `BuyerOrders` | Courier request, expiry, cooldown, fulfillment |
| `SaveManager` | Only save interface: `save_data(payload)` / `load_data()` |
| `AssetFactory` | Exclusive mesh construction and resolution |
| `GridManager` / `CameraRig` | World presentation and touch navigation |
| `Events` | Gameplay signals for later quests, analytics and audio |
| `HUD` | Presentation and command dispatch, no economy mutations |

## Roadmap / boundaries

The next content/system phases from the design brief are **not implemented**:
100+ species and event unlock manager; breeding bench; quests/dailies; a three-slot
order board with gene requests and reputation; Android notifications; gems/boosters;
cloud save/auth; audio/particles; quest-driven tutorial; settings/analytics and real
Android profiling. There are no pretend cloud or purchase integrations.

Breeding integration is easier because planted instances and harvested stacks already
retain normalized genes. Species-only selling/order fulfillment currently consumes
stacks in reverse insertion order; a breeding bench will need explicit stack-key
selection so the player controls which genes are consumed.

Original monster geometry and icon are authored for this project. Godot is MIT-licensed.
