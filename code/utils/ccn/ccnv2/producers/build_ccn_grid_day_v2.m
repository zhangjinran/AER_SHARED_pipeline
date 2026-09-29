function result = build_ccn_grid_day_v2(tall_path, prior_root, output_path)
%BUILD_CCN_GRID_DAY_V2 Build a candidate 2deg x 5deg x 133-level CCN v2 day grid.
if ~isfile(tall_path),error('CCNv2:MissingTAll','Missing T_all: %s',tall_path);end
if ~isfolder(prior_root),error('CCNv2:MissingPrior','Missing candidate prior root: %s',prior_root);end
this=fileparts(mfilename('fullpath')); v2root=fileparts(this);
addpath(fullfile(v2root,'config'),'-begin'); addpath(fullfile(v2root,'science_core'),'-begin'); cfg=ccn_v2_config();
P=load(fullfile(prior_root,'Extinction_Normalized_v2.mat'),'Extinction_N');
S=load(tall_path,'T_all'); T=S.T_all; clear S;
if ~ismember('Height',T.Properties.VariableNames) || ~all(ismember({'Lat','Lon'},T.Properties.VariableNames))
    error('CCNv2:Schema','T_all must contain Height, Lat, and Lon for a 3-D product.');
end
sample=compute_ccn_sample_contributions_v2(T,P.Extinction_N,cfg);

h=double(T.Height(:)); finite_h=h(isfinite(h));
if isempty(finite_h),error('CCNv2:Altitude','T_all has no finite height.');end
if median(abs(finite_h))>100, h=h./1000; height_unit='m_to_km'; else, height_unit='km'; end
altitude_km=unique(h(isfinite(h)&h>=cfg.grid.altitude_min_km&h<=cfg.grid.altitude_max_km));
if numel(altitude_km)~=cfg.grid.expected_altitude_levels
    error('CCNv2:AltitudeAxis','Expected %d canonical levels in 0--8 km, found %d.',cfg.grid.expected_altitude_levels,numel(altitude_km));
end
[has_z,iz]=ismember(h,altitude_km);
lat=double(T.Lat(:)); lon=double(T.Lon(:));
ilat=floor((lat+90)./2)+1; ilon=floor((lon+180)./5)+1;
ilat(lat==90)=90; ilon(lon==180)=72;
in_grid=ilat>=1&ilat<=90&ilon>=1&ilon<=72&has_z;
keep=sample.valid&in_grid;
linear=sub2ind([90 72 cfg.grid.expected_altitude_levels],ilat(keep),ilon(keep),iz(keep));
sample_count=reshape(accumarray(linear,1,[90*72*cfg.grid.expected_altitude_levels 1],@sum,0),[90 72 cfg.grid.expected_altitude_levels]);
sum_component=zeros(90,72,cfg.grid.expected_altitude_levels,5,3);
for branch=1:3
    for q=1:5
        v=sample.ccn020_component_cm3(keep,q).*cfg.supersaturation_factor(branch);
        sum_component(:,:,:,q,branch)=reshape(accumarray(linear,v,[90*72*cfg.grid.expected_altitude_levels 1],@sum,0),[90 72 cfg.grid.expected_altitude_levels]);
    end
end
sum_total=squeeze(sum(sum_component,4));
meta=struct('schema_version',cfg.schema_version,'product_status','CANDIDATE_PHASE2_DAY_GATE', ...
    'source_tall',tall_path,'source_prior_root',prior_root,'grid_lat_deg',2,'grid_lon_deg',5, ...
    'altitude_km',altitude_km,'altitude_source',cfg.grid.altitude_source,'height_input_unit',height_unit, ...
    'supersaturation_percent',cfg.supersaturation_percent,'component_names',{cfg.component_names}, ...
    'retained_samples',sum(keep),'input_rows',height(T),'clear_air_in_denominator',false);
outdir=fileparts(output_path); if ~isfolder(outdir),mkdir(outdir);end
save(output_path,'sum_component','sum_total','sample_count','meta','-v7.3');
result=struct('output_path',output_path,'retained_samples',sum(keep),'input_rows',height(T),'altitude_levels',numel(altitude_km));
end
