"""Freeze a local, read-only shared Synapse candidate outside the public app repo."""
from pathlib import Path
import hashlib,json,shutil,subprocess
source=Path('/Users/denisonosov/dev/mascot-synapse-wip-cTglRL/worktree')
dest=Path('/Users/denisonosov/Downloads/Helper codex/typefree-flutter-private-runtime-20261025')
dest.mkdir(exist_ok=True)
inventory={}
for name in ['synapse_advisor','synapse_pet']:
 src=source/'packages'/name
 target=dest/name
 if not target.exists():
  shutil.copytree(src,target,ignore=shutil.ignore_patterns('build','.dart_tool','example','test','.git','pubspec.lock'))
 for p in target.rglob('*'):
  if p.is_file():inventory[str(p.relative_to(dest))]=hashlib.sha256(p.read_bytes()).hexdigest()
manifest=dest/'manifest.json'
if manifest.exists():
 report=json.loads(manifest.read_text())
 if report['files'] != inventory:
  raise SystemExit('Frozen private runtime changed; inspect before continuing')
else:
 report={'source':str(source),'sourceHead':subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'],text=True).strip(),'files':inventory,'scope':'LOCAL candidate only; owner package was not edited; no production acceptance claimed'}
(dest/'manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
Path('pubspec_overrides.yaml').write_text('dependency_overrides:\n  synapse_pet:\n    path: '+str(dest/'synapse_pet')+'\n  synapse_advisor:\n    path: '+str(dest/'synapse_advisor')+'\n')
Path('docs/synapse-runtime-manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print('Frozen shared source with',len(inventory),'hashes; private code stays outside public checkout')
