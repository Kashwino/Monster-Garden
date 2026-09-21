"""Compare the same full garden on a desktop display. Never touches a player's save."""
import argparse, json, os, subprocess
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('--godot',default=os.environ.get('GODOT_BIN','godot'))
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
out=root/'builds'/'profile';out.mkdir(parents=True,exist_ok=True)
for variant in ('unbatched','batched'):
    env=os.environ.copy()
    env.update(MONSTER_GARDEN_SAVE_PATH=str(out/f'{variant}-save.json'),MONSTER_GARDEN_CAPTURE_DIR=str(out),MONSTER_GARDEN_UNBATCHED='1' if variant=='unbatched' else '0')
    command=[args.godot,'--path',str(root),'--rendering-method','gl_compatibility','--script','tests/performance_capture.gd']
    result=subprocess.run(command,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90)
    (out/f'{variant}.log').write_text(result.stdout)
    if result.returncode or 'SCRIPT ERROR' in result.stdout: raise SystemExit(result.stdout)
    data=json.loads((out/f'performance-{variant}.json').read_text())
    print(variant,':',data['draw_calls_mean'],'draw calls,',data['frame_ms_median'],'ms median frame')
print('Desktop captures and results:',out)
