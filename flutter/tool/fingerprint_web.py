"""Give local preview entrypoints content-addressed names to prevent stale UI.
Run after flutter build web. Changes generated output only, never app/user data.
"""
from pathlib import Path
import hashlib,json,re
root=Path(__file__).resolve().parents[1]
web=root/'build/web'
sha=lambda b:hashlib.sha256(b).hexdigest()
main=(web/'main.dart.js').read_bytes(); main_sha=sha(main)
main_name='main.'+main_sha[:16]+'.dart.js'
(web/main_name).write_bytes(main)
bootstrap=(web/'flutter_bootstrap.js').read_text()
assert '"mainJsPath":"main.dart.js"' in bootstrap, 'Unsupported Flutter bootstrap; output preserved'
bootstrap=bootstrap.replace('"mainJsPath":"main.dart.js"','"mainJsPath":"'+main_name+'"')
boot_sha=sha(bootstrap.encode());boot_name='flutter_bootstrap.'+boot_sha[:16]+'.js'
(web/boot_name).write_text(bootstrap)
index=(web/'index.html').read_text()
index,n=re.subn(r'src="flutter_bootstrap(?:\.[a-f0-9]+)?\.js"','src="'+boot_name+'"',index)
assert n==1,'Expected one bootstrap script'
index=re.sub(r'\s*<meta name="typefree-preview-build" content="[^"]*">','',index)
index=index.replace('</head>',f'<meta name="typefree-preview-build" content="{main_sha[:16]}">\n</head>')
(web/'index.html').write_text(index)
(web/'preview-build.json').write_text(json.dumps({'mainJsSha256':main_sha,'bootstrapSha256':boot_sha,'mainJs':main_name,'bootstrap':boot_name,'scope':'local generated output; no source or user storage changes'},indent=2)+'\n')
print('Fingerprinted preview:',main_sha[:16])
