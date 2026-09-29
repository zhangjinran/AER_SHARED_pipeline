function P = integrate_aod_tall_profiles(T,cfg)
%INTEGRATE_AOD_TALL_PROFILES Profile columns from formal T_all rows.
% Method 1 directly integrates retained APro Ext. Method 2 preserves pure
% Ext and reconstructs Type-5/7 dust/non-dust extinction using frozen
% Chapter5/CCN-v2 beta partition and lidar ratios, then integrates it.
required = {'FileName','Lon','Lat','UTC','Height','Ext','Back','Depol','Type'};
if ~istable(T) || ~all(ismember(required,T.Properties.VariableNames))
    error('AOD:Schema','T_all must contain: %s.',strjoin(required,', '));
end
if isempty(T), error('AOD:EmptyTAll','T_all contains no retained rows.'); end

% T_all stores profile coordinates repeated on each retained vertical row.
% This explicit composite key avoids treating a vertical layer as a profile.
[G,~,profile_lon,profile_lat,~] = findgroups(string(T.FileName), ...
    double(T.Lon),double(T.Lat),double(T.UTC));
nprof = max(G);
if isempty(nprof) || any(G<1), error('AOD:ProfileKey','Could not form profile groups.'); end

% Do not infer thickness from adjacent retained rows: those rows can have
% gaps because T_all has already been QC-filtered. Accept only a verified
% single-resolution Height grid in this initial adapter; fail closed if
% the available centers reveal gaps or a mixed-resolution grid.
h = sort(unique(double(T.Height(:))));
if numel(h)<2 || any(~isfinite(h))
    error('AOD:HeightGrid','At least two finite T_all height centers are required.');
end
dh = diff(h); dz = median(dh);
if dz<=0 || max(abs(dh-dz))>cfg.vertical_uniform_tolerance_km
    error('AOD:NonuniformHeightGrid', ...
        ['T_all retained heights do not define a complete uniform layer grid. ' ...
         'No guessed dz was used; provide/retain the exact APro altitude-bin geometry.']);
end

type = double(T.Type(:)); ext = double(T.Ext(:)); back = double(T.Back(:)); depol = double(T.Depol(:));
geometry_ok=isfinite(double(T.Height(:))) & isfinite(double(T.Lon(:))) & ...
    isfinite(double(T.Lat(:))) & isfinite(double(T.UTC(:)));
type_ok=isfinite(type)&type==round(type)&type>=1&type<=7;
if ~all(geometry_ok)||~all(type_ok)||any(G<1)
    error('AOD:InvalidRetainedRows','T_all has invalid profile coordinates or APRO Type.');
end

% Apply the retrieved-field value bounds used by the inspected APro AOD
% routine. Positive fill/artifact values are not valid optical properties.
ext_valid=isfinite(ext)&ext>0&ext<=cfg.extinction_max_km_inv;
direct_layer=ext.*dz;
direct_by_profile=accumarray([G(ext_valid),type(ext_valid)],direct_layer(ext_valid),[nprof 7],@sum,0);
direct_type_counts=accumarray([G(ext_valid),type(ext_valid)],1,[nprof 7],@sum,0)>0;

component_valid=ext_valid;
component_layer=direct_layer;
mixed=ext_valid&(type==5|type==7);
beta_valid=isfinite(back)&back>0&back<=cfg.backscatter_max_km_inv_sr& ...
    isfinite(depol)&depol>=cfg.depolarization_range(1)&depol<=cfg.depolarization_range(2);
bad_mixed=mixed&~beta_valid;
good_mixed=mixed&beta_valid;
if any(good_mixed)
    [beta_d,beta_nd]=split_mixed_dust(back(good_mixed),depol(good_mixed),cfg.ccn_v2);
    alpha_mix=cfg.lidar_ratio.dust.*beta_d; tm=type(good_mixed);
    alpha_mix(tm==5)=alpha_mix(tm==5)+cfg.lidar_ratio.polluted_continental.*beta_nd(tm==5);
    alpha_mix(tm==7)=alpha_mix(tm==7)+cfg.lidar_ratio.marine.*beta_nd(tm==7);
    component_layer(good_mixed)=alpha_mix.*dz;
end
component_valid(mixed)=good_mixed(mixed);

% If one mixed layer in a profile/type fails the input-value gate, exclude
% that complete profile/type column rather than silently returning a partial
% mixed column. The direct-Ext method remains independently available.
bad_profile_type=false(nprof,7);
if any(bad_mixed)
    bad_profile_type=accumarray([G(bad_mixed),type(bad_mixed)],1,[nprof 7],@sum,0)>0;
    lin=sub2ind([nprof 7],G,type);
    component_valid=component_valid&~bad_profile_type(lin);
end
component_by_profile=accumarray([G(component_valid),type(component_valid)], ...
    component_layer(component_valid),[nprof 7],@sum,0);
component_type_counts=accumarray([G(component_valid),type(component_valid)],1,[nprof 7],@sum,0)>0;
direct_by_profile(:,8) = sum(direct_by_profile(:,1:7),2);
component_by_profile(:,8) = sum(component_by_profile(:,1:7),2);
direct_total_counts=any(direct_type_counts,2);
component_total_counts=any(component_type_counts,2)&~any(bad_profile_type,2);
counts_direct=[direct_type_counts,direct_total_counts];
counts_component=[component_type_counts,component_total_counts];

P = struct('profile_lon',profile_lon,'profile_lat',profile_lat, ...
    'direct_profile_aod',direct_by_profile,'component_profile_aod',component_by_profile, ...
    'direct_profile_count_by_channel',counts_direct, ...
    'component_profile_count_by_channel',counts_component,'height_step_km',dz, ...
    'profiles',nprof,'rows',height(T),'valid_ext_rows',nnz(ext_valid), ...
    'rejected_ext_rows',nnz(~ext_valid),'rejected_mixed_beta_rows',nnz(bad_mixed));
end
