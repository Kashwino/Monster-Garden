"""Reproducible 120-species content library. Preserve all foundation IDs and art specs."""
import json
from pathlib import Path
R=Path(__file__).resolve().parents[1]
base=json.loads((R/'data/foundation_species.json').read_text())
family_specs=[('ocular','eye','Pupils stare from rooted flesh'),('fungal','fungus','A breathing mass of gills and mouths'),('crystalline','crystal','Living shards fracture around a hungry core'),('tendril','tendril','Blind tendrils taste the air'),('carnivore','maw','Petal jaws fold around a tooth-lined throat'),('spore','spore','Hollow sacs release luminous dreams'),('parasite','parasite','A second organism coils around its host'),('voidling','void','Floating flesh circles an absence'),('chitin','chitin','Rooted plates hide twitching feelers'),('coralline','coral','Branching bone grows tiny blinking mouths')]
names={
'ocular':['Witness Bud','Sleepless Orb','Lidless Saint','Borrowed Gaze','Pupil Nest','Iris Furnace','Scrying Blister','Gaze Leech','Weeping Lens','Many-Eyed Oracle','Vigil Morrow','Moonlit Retina'],
'fungal':['Murmur Cap','Choir of Mold','Cathedral Rot','Gilled Tongue','Mouth Morel','Sobbing Mycelium','Velvet Fever','Throat Cluster','Pale Communion','Dreaming Ossuary','Spore Cantor','Equinox Choir'],
'crystalline':['Glass Hunger','Prism Wound','Echo Obelisk','Quartz Jaw','Shiver Geode','Nerve Prism','Fracture Heart','Singing Splinter','Glass Malice','Catoptric Hunger','Mirror Fever','Solstice Fang'],
 'tendril':['Nerve Knot','Vein Lantern','Umbilical Star','Tongue Tangle','Blind Grasp','Coiled Sigh','Threaded Maw','Ligament Bloom','Knuckle Vine','Astral Umbilicus','Root Whispers','Autumn Artery'],
'carnivore':['Throat Bud','Velvet Jaws','Crying Tooth','Molar Choir','Drooling Chalice','Biting Halo','Gullet Crown','Serrated Sigh','Hunger Cathedral','Endless Appetite','Maw Ambassador','Bloodmoon Throat'],
'spore':['Sneeze Sac','Hush Bladder','Dream Pouch','Fever Balloon','Thousand Exhales','Lung Orchard','Breath Censer','Pollen Phantom','Contagion Choir','Spore Singularity','Drifting Lullaby','Equinox Lung'],
'parasite':['Borrowed Root','Host Whisper','Pale Hitchhiker','Twin Hunger','Nerve Lodger','Womb Thief','Vein Impostor','Marrow Guest','Skin Pilgrim','Perfect Intruder','Drifting Stranger','Bloodmoon Host'],
'voidling':['Hollow Mote','Absent Tongue','Gap Larva','Unseen Grin','Nothing Nest','Rift Sucker','Dark Interval','Void Halo','Unbirth Star','Impossible Silence','Drifting Absence','Equinox Null'],
'chitin':['Shell Murmur','Clicking Bud','Mandible Knot','Antenna Choir','Carapace Lung','Plate Oracle','Clicking Halo','Molting Saint','Amber Parasite','Endless Molt','Shell Envoy','Bloodmoon Carapace'],
'coralline':['Bone Polyp','Chalk Mouth','Fang Branch','Marrow Fan','Ivory Swarm','Bleached Choir','Tooth Reef','Spinal Crown','Ossuary Bloom','Skeletal Oracle','Drifting Tooth','Equinox Marrow']}
old={s['id']:s for s in base['species']}
families={f:{'name':f.capitalize(),'silhouette':shape,'mesh':{'primitive':shape},'description':desc} for f,shape,desc in family_specs}
species=[]; events={}; recipes=[]
tiers=['Common','Uncommon','Rare','Exotic','Mythic'];times=[30,180,900,3600,10800];costs=[8,30,100,350,950];prices=[9,22,55,150,410];xps=[7,14,30,65,140]
for fi,(family,shape,desc) in enumerate(family_specs):
 for j,name in enumerate(names[family]):
  sid=name.lower().replace('-','_').replace(' ','_')
  tier=min(j//2,4) if j<9 else (2 if j==10 else 4)
  unlock={'type':'level','value':max(1,1+j*4+fi//3)}
  if j>=9:
   key='discover_'+sid if j==9 else 'event_'+sid
   unlock={'type':'event','value':key}
   if j==9:
    events[key]={'kind':'breeding','label':'Breed a luminous '+family+' lineage'}
    recipes.append({'species_id':sid,'event':key,'family':family,'glow_min':0.40,'scale_min':0.85,'chance':0.18})
   elif j==10:
    kind='reputation' if fi in [0,4,8] else 'quest' if fi in [1,2,3] else 'drift'
    events[key]={'kind':kind,'label':{'reputation':'Courier reputation 30','quest':'Complete the keeper quest chain','drift':'Claim a rare spore drift'}[kind],'threshold':30,'quest_id':'keeper_master'}
   else:
    season='bloodmoon' if fi in [0,2,4,6,8] else 'equinox'
    events[key]={'kind':'season','label':season.title()+' 2026','start':'2026-10-01' if season=='bloodmoon' else '2026-09-01','end':'2026-11-01' if season=='bloodmoon' else '2026-10-01'}
  genes={'hue':round((fi*.097+j*.047)%1,2),'scale':round(.85+(j%4)*.12,2),'appendages':3+j%5,'glow':round(.10+(j%5)*.18,2),'speed':round(.6+(j%4)*.3,2)}
  entry={'id':sid,'name':name,'description':desc+'; '+['it remembers your footsteps.','its shadow moves before it does.','it dreams beneath the soil.','it answers in a voice of spores.'][j%4], 'family':family,'rarity':tiers[tier],'grow_seconds':times[tier], 'yield':2+tier,'seed_cost':costs[tier]+fi,'sell_value':prices[tier]+fi,'xp':xps[tier],'genes':genes,'unlock':unlock,'mesh':{'primitive':shape}}
  if sid in old:
   entry=old[sid]
   # Preserve existing unlocks/economy; only the library grows around them.
  species.append(entry)
assert len(species)==120 and len({s['id'] for s in species})==120
(R/'data/catalog.json').write_text(json.dumps({'version':3,'families':families,'species':species,'events':events},indent=2)+'\n')
(R/'data/breeding.json').write_text(json.dumps(recipes,indent=2)+'\n')
print('120 species / 10 families /',sum(s['unlock']['type']=='level' for s in species),'level unlocks')
