function result = compare_ccn_v2_vs_legacy_20070101(v2_path, legacy_path, report_dir)
%COMPARE_CCN_V2_VS_LEGACY_20070101 Phase-3 diagnostic only; no parity claim.
% V2 (2x5x133) is vertically pooled then mapped by 2-degree latitude-cell
% centres into legacy 5-degree latitude bands.  This is solely for trend
% comparison because the native latitude grids are not commensurate.

if ~isfile(v2_path),error('CCNv2:MissingV2','Missing v2 candidate.');end
if ~isfile(legacy_path),error('CCNv2:MissingLegacy','Missing legacy grid.');end
if ~isfolder(report_dir),mkdir(report_dir);end
V=load(v2_path,'sum_total','sample_count','meta'); L=load(legacy_path);
if ~isfield(L,'M')||~isfield(L,'cnt'),error('CCNv2:LegacySchema','Legacy grid must contain M and cnt.');end
assert(isequal(size(V.sum_total),[90 72 133 3]),'CCNv2:V2Shape','Unexpected v2 total shape.');
assert(isequal(size(L.M),[36 72 3]),'CCNv2:LegacyShape','Expected legacy 5x5 grid.');

v2_count=sum(V.sample_count,3);
legacy_count=double(L.cnt);
v2_sum=squeeze(sum(V.sum_total,3));
v2_on_legacy_sum=zeros(36,72,3); v2_on_legacy_count=zeros(36,72);
lat2=-89:2:89; ilat_old=floor((lat2+90)./5)+1; ilat_old=min(max(ilat_old,1),36);
for il=1:90
    for j=1:72
        k=ilat_old(il); v2_on_legacy_count(k,j)=v2_on_legacy_count(k,j)+v2_count(il,j);
        for branch=1:3,v2_on_legacy_sum(k,j,branch)=v2_on_legacy_sum(k,j,branch)+v2_sum(il,j,branch);end
    end
end
v2_on_legacy_mean=nan(36,72,3);
for branch=1:3
    z=v2_on_legacy_sum(:,:,branch); z(v2_on_legacy_count>0)=z(v2_on_legacy_count>0)./v2_on_legacy_count(v2_on_legacy_count>0);
    v2_on_legacy_mean(:,:,branch)=z;
end

% Legacy branches 2/3 and v2 branches 2/3 are 0.25% and 0.40% respectively.
ss=[0.25;0.40]; rows=cell(2,10);
for q=1:2
    a=v2_on_legacy_mean(:,:,q+1); b=double(L.M(:,:,q+1));
    overlap=isfinite(a)&isfinite(b)&v2_on_legacy_count>0&legacy_count>0;
    av=a(overlap); bv=b(overlap);
    if numel(av)>=2, R=corrcoef(av,bv); spatial_r=R(1,2); else, spatial_r=NaN; end
    rows(q,:)={ss(q),numel(av),nnz(v2_on_legacy_count>0),nnz(legacy_count>0), ...
        spatial_r,prctile(av,5),median(av),prctile(av,95),prctile(bv,5),median(bv)};
end
comparison=cell2table(rows,'VariableNames',{'supersaturation_percent','overlap_cells','v2_covered_cells','legacy_covered_cells','spatial_pearson_r','v2_p05','v2_p50','v2_p95','legacy_p05','legacy_p50'});
writetable(comparison,fullfile(report_dir,'phase3_legacy_vs_v2_20070101.csv'));
coverage=table(V.meta.input_rows,V.meta.retained_samples,nnz(v2_count>0),nnz(legacy_count>0), ...
    'VariableNames',{'v2_input_rows','v2_retained_samples','v2_horizontal_covered_cells','legacy_horizontal_covered_cells'});
writetable(coverage,fullfile(report_dir,'phase3_coverage_20070101.csv'));
save(fullfile(report_dir,'phase3_legacy_vs_v2_20070101_diagnostic.mat'),'comparison','coverage','v2_on_legacy_mean','v2_on_legacy_count','legacy_count','-v7.3');
result=struct('comparison_path',fullfile(report_dir,'phase3_legacy_vs_v2_20070101.csv'), ...
    'coverage_path',fullfile(report_dir,'phase3_coverage_20070101.csv'),'comparison',comparison,'coverage',coverage);
disp(comparison); disp(coverage);
end
