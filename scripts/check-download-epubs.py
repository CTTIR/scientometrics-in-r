#!/usr/bin/env python3
"""Validate every downloadable EPUB with the same EPUBCheck release."""
from pathlib import Path
import concurrent.futures,json,subprocess,sys
root=Path(sys.argv[1]);jar=Path(sys.argv[2]);files=list(root.glob('*.epub'))+list((root/'downloads/chapters').glob('*.epub'))
def check(path):
    r=subprocess.run(['java','-jar',str(jar),'--quiet',str(path)],capture_output=True,text=True)
    return {'file':str(path.relative_to(root)),'status':r.returncode,'output':r.stdout+r.stderr}
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(check,files))
(root/'epub-validation.json').write_text(json.dumps(results,indent=2)+'\n')
failed=[r for r in results if r['status']]
print(json.dumps({'checked':len(results),'failures':failed},indent=2))
sys.exit(bool(failed))
