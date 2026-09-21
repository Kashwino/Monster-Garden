"""Author the small foundation catalog. Runtime reads JSON, never this generator."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
families = {
    'ocular': {'name':'Ocular', 'silhouette':'eye'},
    'fungal': {'name':'Fungal', 'silhouette':'fungus'},
    'crystalline': {'name':'Crystalline', 'silhouette':'crystal'},
    'tendril': {'name':'Tendril', 'silhouette':'tendril'},
}
rows = [
 ('witness_bud','Witness Bud','It remembers every hand that has touched the soil.','ocular',1,30,2,8,6,6,0.36),
 ('murmur_cap','Murmur Cap','Beneath its gills, a hundred small mouths whisper.','fungal',1,30,3,6,7,7,0.82),
 ('nerve_knot','Nerve Knot','A tangle of roots that recoils from its own shadow.','tendril',2,45,2,14,12,10,0.09),
 ('glass_hunger','Glass Hunger','Every shard is a tooth. Every chime is an appetite.','crystalline',2,60,2,19,18,12,0.49),
 ('sleepless_orb','Sleepless Orb','An unblinking pupil follows moons that are not there.','ocular',3,90,3,22,28,16,0.63),
 ('choir_of_mold','Choir of Mold','It sings through spore sacs in a borrowed voice.','fungal',4,120,3,31,38,20,0.16),
 ('vein_lantern','Vein Lantern','Light crawls through translucent roots like trapped lightning.','tendril',5,240,3,48,60,30,0.43),
 ('prism_wound','Prism Wound','A wound in the ground that heals into impossible angles.','crystalline',6,480,4,65,95,40,0.9),
 ('lidless_saint','Lidless Saint','A halo of eyes blesses nothing and watches everything.','ocular',7,900,4,92,140,55,0.12),
 ('cathedral_rot','Cathedral Rot','Its bell-shaped chambers shelter a breathing darkness.','fungal',8,1800,5,130,210,75,0.71),
 ('umbilical_star','Umbilical Star','A small fallen star still attached to something above.','tendril',9,3600,5,190,330,105,0.02),
 ('echo_obelisk','Echo Obelisk','It casts tomorrow’s shadow and hums yesterday’s name.','crystalline',10,7200,6,270,500,150,0.55),
]
species=[]
for i,(sid,name,desc,family,level,grow,yield_,sell,cost,xp,hue) in enumerate(rows):
    rarity='Common' if level<3 else 'Uncommon' if level<5 else 'Rare' if level<7 else 'Exotic' if level<9 else 'Mythic'
    species.append(dict(id=sid,name=name,description=desc,family=family,rarity=rarity,grow_seconds=grow,
        **{'yield':yield_},sell_value=sell,seed_cost=cost,xp=xp,unlock={'type':'level','value':level},
        genes=dict(hue=hue,scale=0.85+(i%3)*0.1,appendages=3+i%4,glow=0.12+(i%4)*0.15,speed=0.7+(i%3)*0.3),
        mesh=dict(primitive=families[family]['silhouette'])))
species[0]['mesh']['stages']={s:{'scene':f'res://assets/monsters/witness/{s}.glb'} for s in ['seed','sprout','juvenile','mature','blooming']}
(ROOT/'data/foundation_species.json').write_text(json.dumps(dict(version=2,families=families,species=species),indent=2)+'\n')

# Rebuild the expanded library as well; never accidentally shrink the live catalog.
import runpy
runpy.run_path(str(ROOT/'tools/expand_species.py'))
