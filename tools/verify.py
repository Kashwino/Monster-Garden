"""Run genuine Godot imports and integration tests. Set GODOT_BIN if needed."""
import os,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
godot=os.environ.get('GODOT_BIN','godot')
(root/'builds').mkdir(exist_ok=True)
env=os.environ.copy();env['MONSTER_GARDEN_SAVE_PATH']=str(root/'builds/test-session.json')
commands=[['--headless','--editor','--path',str(root),'--import','--quit']]+[['--headless','--path',str(root),'--script',s] for s in (sys.argv[1:] or ['tests/run_tests.gd','tests/phase2_tests.gd'])]
failed=False
for i,args in enumerate(commands):
 p=subprocess.run([godot]+args,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=35)
 (root/f'builds/check_{i}.log').write_text(p.stdout)
 bad=[l for l in p.stdout.splitlines() if any(x in l for x in ['SCRIPT ERROR','Parse Error','FAIL:'])]
 verdict=[l for l in p.stdout.splitlines() if l.startswith('RESULT:')]
 print(('PASS' if p.returncode==0 and not bad else 'FAIL'),args[-1],*verdict,sep=' | ')
 if bad: print('\n'.join(bad[:20]))
 failed |= p.returncode!=0 or bool(bad)
 if failed: break
sys.exit(int(failed))
