# System 1: art pipeline

`AssetFactory.create(species_id, stage, genes)` returns an independent `Node3D`.
No gameplay or UI script loads a mesh or an imported model directly.
`GridManager` derives the stage from stored UTC timestamps and asks the factory
for a replacement only when a stage changes. There is no saved model path or timer.

## A catalog-only swap

In `data/catalog.json`, edit `witness_bud.mesh.stages.blooming.scene` to point to
another `.glb`, e.g. the included `res://assets/monsters/witness/juvenile.glb`.
Run again: blooming Witness Buds use that model, without edits to another file.
Restore the blooming path afterwards.

```json
"mesh": {
  "primitive": "eye",
  "stages": {
    "seed": {"scene": "res://assets/monsters/witness/seed.glb"},
    "sprout": {"scene": "res://assets/monsters/witness/sprout.glb"},
    "juvenile": {"scene": "res://assets/monsters/witness/juvenile.glb"},
    "mature": {"scene": "res://assets/monsters/witness/mature.glb"},
    "blooming": {"scene": "res://assets/monsters/witness/blooming.glb"}
  }
}
```

An entry-level `scene` applies to every stage lacking an override. An optional
`scale` applies to imported geometry. A stage can specify `{"scene":""}` to
force the primitive fallback. Family `mesh` defaults are supported; species
specs override them. Missing paths, non-scene resources and non-Node3D roots
fall back to the existing primitive and warn once. Primitive silhouettes:
`eye`, `fungus`, `crystal`, `tendril`.

## Model conventions

- Root is `Node3D`; +Y is up; origin is at ground contact, units are metres.
- Each stage is authored at its intended size. Instance `scale` genes apply on top.
- Materials named `GeneBody*` take the instance hue.
- Materials named `GeneGlow*` take hue and glow. Other materials retain artist colours.
- Nodes named `Appendage_0` through `Appendage_7` are shown by the appendage gene.
- Gene material overrides are duplicated per instance; cached scenes are never modified.
- Cosmetic pulse/sway speed is driven by the `speed` gene, independent of growth.

The included GLBs are **original low-poly monster meshes**, generated reproducibly by
`python tools/build_witness_glb.py`. They are not ordinary vegetable or borrowed art.
They range from 826 to 2,114 triangles before optional appendages are hidden.
No texture downloads or art licenses are needed for these original project assets.

`tools/generate_catalog.py` reproduces the authored catalog and its GLB paths.
If you edit the JSON manually, do not regenerate it unless you also update that source.

## Checks

```sh
MONSTER_GARDEN_SAVE_PATH=user://art-test.json godot --headless --path . --script tests/art_tests.gd
```

The test intentionally requests a missing model. That warning is expected.
Godot 4.3's dummy headless renderer may emit null-mesh messages during mesh cleanup;
those are distinct from script errors and the explicit test verdict.

Save schema 2 adds `catalog_version`. The v1 migration does not change coins,
inventory, genes or growth timestamps. `tests/fixtures/foundation_v1.json` was
created by running the actual pre-art foundation commit, then loaded in v2 tests.
