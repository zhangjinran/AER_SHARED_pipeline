from pathlib import Path
import numpy as np
from scipy.io import loadmat

root = Path(r"Z:\ERA5\mat\2007\01\01")
for hour in range(13, 20):
    path = root / f"ERA5_20070101_{hour:02d}.mat"
    e = loadmat(path, squeeze_me=False)["ERA5"]
    h = np.asarray(e["height"][0, 0])
    d = np.diff(h, axis=2)
    bad = d <= 0
    profiles = bad.any(axis=2)
    print(f"{hour:02d} UTC shape={h.shape} profiles={h.shape[0]*h.shape[1]} "
          f"bad_profiles={int(profiles.sum())} turning_pairs={int(bad.sum())} "
          f"min_diff={float(np.nanmin(d)):.9g}", flush=True)
