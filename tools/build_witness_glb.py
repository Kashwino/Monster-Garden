"""Build original low-poly Witness Bud GLB assets; no external art dependencies.
Meshes are authored geometry, with named gene materials and optional appendages.
Coordinates: metres, +Y up, ground-level origin. Regenerate with Python 3.
"""
import json, math, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/monsters/witness'
OUT.mkdir(parents=True,exist_ok=True)
PI=math.pi

def vecsub(a,b): return tuple(x-y for x,y in zip(a,b))
def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def unit(a):
 l=math.sqrt(sum(x*x for x in a)) or 1
 return tuple(x/l for x in a)

class Builder:
 def __init__(self,stage):
  self.stage=stage; self.groups={}
 def triangle(self,group,a,b,c):
  # Flat facets are intentional: a strange, sculptural silhouette.
  b,c=c,b  # glTF uses counterclockwise outward-facing triangles.
  n=unit(cross(vecsub(b,a),vecsub(c,a)))
  self.groups.setdefault(group,[]).extend([(a,n),(b,n),(c,n)])
 def sphere(self,group,center,radii,segments=14,rings=9,warp=False):
  def pt(i,j):
   t=PI*i/rings; p=2*PI*j/segments
   r=math.sin(t)
   asym=1+0.09*math.sin(3*p+2*t) if warp else 1
   return (center[0]+radii[0]*r*math.cos(p)*asym,
           center[1]+radii[1]*math.cos(t),center[2]+radii[2]*r*math.sin(p)*asym)
  for i in range(rings):
   for j in range(segments):
    a,b,c,d=pt(i,j),pt(i+1,j),pt(i+1,j+1),pt(i,j+1)
    if i: self.triangle(group,a,b,d)
    if i<rings-1:self.triangle(group,b,c,d)
 def tube(self,group,points,radii,sides=7):
  rings=[]
  for i,p in enumerate(points):
   tangent=unit(vecsub(points[min(i+1,len(points)-1)],points[max(0,i-1)]))
   n=unit(cross(tangent,(0,0,1) if abs(tangent[2])<0.9 else (1,0,0)))
   b=cross(tangent,n)
   rings.append([tuple(p[k]+radii[i]*(n[k]*math.cos(j*2*PI/sides)+b[k]*math.sin(j*2*PI/sides)) for k in range(3)) for j in range(sides)])
  for a,b in zip(rings,rings[1:]):
   for j in range(sides):
    q=(j+1)%sides
    self.triangle(group,a[j],b[j],a[q]);self.triangle(group,a[q],b[j],b[q])
 def write(self,path,scale):
  materials=[
   {'name':'GeneBody','pbrMetallicRoughness':{'baseColorFactor':[0.42,0.7,0.48,1],'metallicFactor':0,'roughnessFactor':0.9}},
   {'name':'GeneGlow','pbrMetallicRoughness':{'baseColorFactor':[0.75,0.92,0.6,1],'metallicFactor':0,'roughnessFactor':0.7},'emissiveFactor':[0.12,0.2,0.08]},
   {'name':'Ivory','pbrMetallicRoughness':{'baseColorFactor':[0.93,0.89,0.72,1],'metallicFactor':0,'roughnessFactor':0.6}},
   {'name':'Pupil','pbrMetallicRoughness':{'baseColorFactor':[0.025,0.05,0.047,1],'metallicFactor':0,'roughnessFactor':0.4}},
   {'name':'Vein','pbrMetallicRoughness':{'baseColorFactor':[0.13,0.26,0.22,1],'metallicFactor':0,'roughnessFactor':1}},
  ]
  doc={'asset':{'version':'2.0','generator':'Monster Garden original geometry / build_witness_glb.py'},'scene':0,'scenes':[{'nodes':[0]}], 'nodes':[{'name':'Witness_'+self.stage,'children':[]}], 'meshes':[], 'materials':materials,'buffers':[],'bufferViews':[],'accessors':[]}
  binary=bytearray()
  def accessor(values,kind):
   offset=len(binary)
   for row in values: binary.extend(struct.pack('<3f',*row))
   vi=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(binary)-offset,'target':34962})
   ai=len(doc['accessors']);ac={'bufferView':vi,'componentType':5126,'count':len(values),'type':'VEC3'}
   if kind=='POSITION': ac.update(min=[min(x[k] for x in values) for k in range(3)],max=[max(x[k] for x in values) for k in range(3)])
   doc['accessors'].append(ac);return ai
  for group,vertices in self.groups.items():
   name,mat=group
   positions=[tuple(v*scale for v in p) for p,n in vertices];normals=[n for p,n in vertices]
   mi=len(doc['meshes']);doc['meshes'].append({'name':name,'primitives':[{'attributes':{'POSITION':accessor(positions,'POSITION'),'NORMAL':accessor(normals,'NORMAL')},'material':mat,'mode':4}]})
   ni=len(doc['nodes']);doc['nodes'].append({'name':name,'mesh':mi});doc['nodes'][0]['children'].append(ni)
  doc['buffers']=[{'byteLength':len(binary)}]
  encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
  binary+=b'\0'*((-len(binary))%4)
  total=12+8+len(encoded)+8+len(binary)
  path.write_bytes(struct.pack('<III',0x46546c67,2,total)+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary)
  print(path.name, 'triangles',sum(len(v)//3 for v in self.groups.values()),'bytes',total)

for age,stage in enumerate(['seed','sprout','juvenile','mature','blooming']):
 b=Builder(stage)
 body=('Body',0);light=('Lumens',1);ivory=('EyeWhite',2);pupil=('Pupil',3);vein=('Veins',4)
 if age==0:
  b.sphere(body,(0,.34,0),(.37,.44,.32),warp=True)
  b.tube(light,[(0,.65,.17),(.03,.52,.28),(-.03,.35,.32),(0,.18,.26)],[.014]*4)
 else:
  b.sphere(body,(0,.56,0),(.39,.56,.32),warp=True)
  # Pale slanted eye and a black split pupil facing the isometric camera.
  b.sphere(ivory,(.19,.78,.27),(.3,.24,.19))
  b.sphere(pupil,(.30,.79,.42),(.085,.19,.055),segments=12)
  b.sphere(light,(.32,.87,.468),(.025,.045,.02),segments=8,rings=5)
  b.tube(vein,[(-.08,.90,.28),(.06,1.02,.33),(.27,1.03,.30),(.46,.91,.23)],[.04,.05,.045,.018])
  b.tube(vein,[(.05,.56,.30),(.17,.49,.36),(.32,.52,.28)],[.018,.03,.018])
  if age>=2:
   for j in range(3 if age==2 else 5):
    x=(j-2)*.13
    b.tube(body,[(x,.98,0),(x*1.5,1.16,-.07),(x*1.7,1.36,-.02)],[.047,.029,.009])
    if age==4: b.sphere(light,(x*1.7,1.38,-.02),(.06,.075,.06),segments=8,rings=5)
  if age==4:
   for j in range(5):
    a=j*2*PI/5
    b.sphere(light,(math.cos(a)*.28,.65+math.sin(a)*.23,-.26),(.055,.06,.035),segments=8,rings=5)
 for j in range(8):
  a=j*2*PI/8
  pts=[]
  for k in range(6):
   t=k/5
   r=.15+.48*t
   pts.append((math.cos(a+t*.7)*r,.22*(1-t)+.05+math.sin(t*PI)*.05,math.sin(a+t*.7)*r))
  b.tube((f'Appendage_{j}',0),pts,[.09,.085,.065,.045,.024,.006])
 scale=[.45,.52,.7,.88,1][age]
 b.write(OUT/(stage+'.glb'),scale)
