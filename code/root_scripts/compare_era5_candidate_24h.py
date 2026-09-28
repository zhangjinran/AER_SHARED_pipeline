from pathlib import Path
import json, time, numpy as np
from scipy.io import loadmat

day='20070101'; cand=Path(r'Z:\ERA5\test_conversion\candidate_single_scan\2007\01\01'); ref=Path(r'Z:\ERA5\mat\2007\01\01'); out=Path(r'Z:\ERA5\manifests\compare_candidate_20070101.json')
rows=[]; ok=True; t=time.perf_counter()
for h in range(24):
    n=f'ERA5_{day}_{h:02d}.mat'; a=loadmat(cand/n,squeeze_me=False)['ERA5'][0,0]; b=loadmat(ref/n,squeeze_me=False)['ERA5'][0,0]
    row={'hour':h,'maxdiff':{},'bad_candidate':0};
    for k in ('lon','lat','lev','time'):
        row['maxdiff'][k]=float(np.max(np.abs(np.asarray(a[k])-np.asarray(b[k])))); ok=ok and row['maxdiff'][k]==0
    for k in ('RH','height'):
        av=np.asarray(a[k]); bv=np.asarray(b[k]); row['maxdiff'][k]=float(np.nanmax(np.abs(av-bv))); ok=ok and row['maxdiff'][k]<=1e-3
        if k=='height': row['bad_candidate']=int(np.sum(np.any(np.diff(av,axis=2)<=0,axis=2))); ok=ok and row['bad_candidate']==0
    rows.append(row); print(f'{h:02d} max_height_diff={row["maxdiff"]["height"]} bad={row["bad_candidate"]}',flush=True)
result={'date':day,'hours':rows,'status':'PASS' if ok else 'FAIL','seconds':time.perf_counter()-t}; out.write_text(json.dumps(result,indent=2),encoding='utf-8'); print('STATUS='+result['status'],flush=True)
