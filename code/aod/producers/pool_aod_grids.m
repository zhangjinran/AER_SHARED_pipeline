function G=pool_aod_grids(G,D)
% Pool sums and native-profile counts; never average daily means.
assert(isequaln(D.sum_direct_ext(:,:,[1 2 3 4 6]),D.sum_component_reconstruction(:,:,[1 2 3 4 6])),'AOD:Pure','Daily pure-type sums differ.');
if isempty(G)
    G=D; G.profile_count=uint64(D.profile_count);
else
    assert(isequal(G.lat_edges,D.lat_edges)&&isequal(G.lon_edges,D.lon_edges),'AOD:Geometry','Different grid geometry.');
    G.profile_count=G.profile_count+uint64(D.profile_count);
    G.sum_direct_ext=G.sum_direct_ext+D.sum_direct_ext;
    G.sum_component_reconstruction=G.sum_component_reconstruction+D.sum_component_reconstruction;
end
den=double(G.profile_count);den(den==0)=NaN;
G.mean_direct_ext=G.sum_direct_ext./den;
G.mean_component_reconstruction=G.sum_component_reconstruction./den;
assert(isequaln(G.mean_direct_ext(:,:,[1 2 3 4 6]),G.mean_component_reconstruction(:,:,[1 2 3 4 6])),'AOD:Pure','Pooled pure types differ.');
for field={'sum_direct_ext','sum_component_reconstruction'}
    a=G.(field{1}); delta=abs(sum(a(:,:,1:7),3)-a(:,:,8));
    assert(all(delta<=1e-10*max(1,abs(a(:,:,8))),'all'),'AOD:Total','Pooled Total is not category sum.');
end
end
