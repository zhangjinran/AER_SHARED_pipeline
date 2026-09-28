from pathlib import Path
import numpy as np
from scipy.io import loadmat
from eccodes import codes_grib_new_from_file, codes_get, codes_get_array, codes_release
raw=Path(r'Z:\ERA5\raw\pressure_levels\2007\01\ERA5_PL_R_Z_20070101_global_025_37lev.grib')
mat=Path(r'Z:\ERA5\mat\2007\01\01\ERA5_20070101_14.mat')
ix,iy=289,687; vals={}; rhs={}
with raw.open('rb') as f:
 while True:
  g=codes_grib_new_from_file(f)
  if g is None: break
  try:
   if codes_get(g,'dataDate')==20070101 and codes_get(g,'dataTime')==1400 and codes_get(g,'shortName') in ('z','r'):
    name=codes_get(g,'shortName'); lev=float(codes_get(g,'level')); ni=int(codes_get(g,'Ni')); value=float(np.asarray(codes_get_array(g,'values')).reshape(int(codes_get(g,'Nj')),ni)[iy,ix])
    if name=='z': vals[lev]=value/9.80665
    else: rhs[lev]=value
  finally: codes_release(g)
e=loadmat(mat,squeeze_me=False)['ERA5']; mh=np.asarray(e['height'][0,0]); mrh=np.asarray(e['RH'][0,0]); levels=np.asarray(e['lev'][0,0]).ravel(); mv=mh[ix,iy,:].ravel(); mrv=mrh[ix,iy,:].ravel(); order=np.array([np.where(np.isclose(levels,k))[0][0] for k in sorted(vals,reverse=True)])
rv=np.array([vals[k] for k in sorted(vals,reverse=True)])
print('raw_levels',len(rv),'mat_shape',mh.shape); print('maxabsdiff',np.nanmax(np.abs(rv-mv[order]))); print('raw_nonmonotonic',int(np.sum(np.diff(rv)<=0)),'mat_nonmonotonic',int(np.sum(np.diff(mv[order])<=0))); print('raw=',rv); print('mat=',mv[order])
rr=np.array([rhs[k] for k in sorted(rhs,reverse=True)])
rh_order=np.array([np.where(np.isclose(levels,k))[0][0] for k in sorted(rhs,reverse=True)])
print('rh_raw_levels',len(rr),'rh_maxabsdiff',np.nanmax(np.abs(rr-mrv[rh_order])))
print('rh_raw=',rr); print('rh_mat=',mrv[rh_order])
