function G=grid_aod_profiles(P,cfg)
% One vote per native profile, including zero contribution to absent types.
v=P.valid_for_grid; lat=P.latitude(v); lon=P.longitude(v);
i=min(floor((lat+90)/5)+1,36); j=min(floor((lon+180)/5)+1,72);
idx=[i,j]; D=P.aod_direct(v,:); R=D;
R(:,[5 7 8])=P.aod_reconstructed_5_7_total(v,:);
assert(all(isfinite(D),'all')&&all(isfinite(R),'all'),'AOD:Grid','Invalid accepted profile value.');
count=accumarray(idx,ones(size(i)),[36 72],@sum,0);
sd=zeros(36,72,8); sr=sd;
for t=1:8
    sd(:,:,t)=accumarray(idx,D(:,t),[36 72],@sum,0);
    sr(:,:,t)=accumarray(idx,R(:,t),[36 72],@sum,0);
end
den=count; den(den==0)=NaN;
md=sd./den; mr=sr./den;
assert(isequaln(md(:,:,[1 2 3 4 6]),mr(:,:,[1 2 3 4 6])),'AOD:PureTypes','Pure type maps changed.');
assert(max(abs(sum(sd(:,:,1:7),3)-sd(:,:,8)),[],'all')<1e-8,'AOD:Total','Direct sum consistency failed.');
assert(max(abs(sum(sr(:,:,1:7),3)-sr(:,:,8)),[],'all')<1e-8,'AOD:Total','Reconstructed sum consistency failed.');
G=struct('profile_count',uint32(count),'sum_direct_ext',sd,'sum_component_reconstruction',sr, ...
    'mean_direct_ext',md,'mean_component_reconstruction',mr, ...
    'lat_edges',cfg.lat_edges,'lon_edges',cfg.lon_edges);
end
