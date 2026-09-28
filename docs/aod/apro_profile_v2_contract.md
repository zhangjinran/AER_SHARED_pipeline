# APro profile-first AOD v2

Approved scope: replace the T_all-based AOD experiment with global native
APro MAT, first produce 2007-01-01, then render two grouped figures.

Input: `Z:\CALIPSO_MAT_FINAL\CHAPTER5_AP\05kmAP\YYYY\YYYY_MM_DD.mat`.
This is the global APro-only collection; no regional AP/ALay/VFM collection
and no T_all is used. Inspection of 2007-01-01 found 29 orbit structures,
399 native heights and profile-by-height-by-2 AVD. Extinction_QC_Flag_532
is absent in this MAT. Products must state qc_used=false for this source.
No formal NASA complete-QA equivalence is claimed.

The native heights have approximately 0.06 km spacing below 20.2 km and
0.18 km above it. Widths are derived separately from the complete native
axis, and adjacent center spacings are checked against half the sum of
neighboring widths. The two AVD planes are upper/lower sub-bins: each gets
half of its parent bin thickness. Above the native sub-bin-resolution
region the two identical descriptions therefore add to one bin, not two.
Reference: https://ntrs.nasa.gov/api/citations/20260000776/downloads/cal_lid_l2_pro_v5-00_desc_qs.pdf

One source_file_index + native profile_index is one sampling unit. For each
profile retain direct Type1..7 plus Total. For Type5 and Type7 also retain
reconstructed dust+PC and dust+marine respectively, and reconstructed Total.
The five unchanged categories are stored once. Store the four mixed component
integrals with original-Type provenance; never add Type7 marine to Type1.
No RH, NSD, normalized-extinction priors or OMCAM number conversion are needed.
The shared CCN-v2 split endpoints .05/.31 and lidar ratios 44/70/23 are used.

Known non-aerosol sub-bins contribute zero. A valid zero-aerosol profile is
included in the grid denominator. Invalid/no-signal AVD, unclassified
tropospheric aerosol, or unsupported stratospheric aerosol flags invalidate
the profile for this seven-tropospheric-type product; they are not clear air.
Cloud layers contribute zero aerosol extinction, but this is an observed
column under the source's detectability constraints, not a correction for
undetected aerosol within clouds. Surface/subsurface contribute zero.
Invalid aerosol extinction invalidates the direct profile. Invalid mixed
backscatter/depolarization additionally invalidates reconstructed 5/7/Total.
Direct accepts finite Ext in [0,1.25]; reconstruction requires finite Back in
[0,.05] and Depol in [0,1]. If an input actually supplies Extinction QC, the
explicit project acceptance list is [0,1,16,18]; otherwise no QC values are
invented. Source TAI seconds are preserved and are not mislabeled UTC.

Gridding uses the intersection of direct and reconstructed valid profiles.
The same profiles and same count are used for all eight channels and both
methods. Absent categories contribute zero. This also guarantees identical
Type1/2/3/4/6 maps. Preserve each method's independent validity in the profile
product so extra direct-only observations are not lost without documentation.
Persist sums, profile_count and means. No area weighting or bin weighting
enters the horizontal mean. Empty grid cells remain NaN. Zero remains zero.

Products:
products/aod/aod_profile_day/aod-profile__global-apro__avd2__column-v2/YYYY/MM/DD/
products/aod/aod_grid_day/aod-grid__global-apro__avd2__profile-mean__grid5deg-v2/YYYY/MM/DD/
Run: runs/aod/run_20070101_apro_v2_001/{logs,reports,staging,plots}

Publication moves the validated candidate into the formal location; no second
candidate copy is retained. All formal outputs include manifest,
input_inventory and _SUCCESS. Figures use existing smooth Robinson drawing
with white missing-data regions; true zeros are drawn at the low color end.

Checks: analytic synthetic profiles exercise absent-category zeros, both AVD
planes, QC presence/absence, invalid missing data, pure-type invariance and
the grid denominator. A few actual native profiles are independently summed
with scalar arithmetic. Total is checked against the category partition.
The validation does not rerun the full same producer as its own reference.
