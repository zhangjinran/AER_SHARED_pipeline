function result = build_ccn_grid_month_v2(day_root, yyyymm, output_path, expected_dates)
%BUILD_CCN_GRID_MONTH_V2 Pooled monthly sum/count aggregation; no daily-mean averaging.
if nargin<4,error('CCNv2:Dates','Expected date list required.');end
sum_component=zeros(90,72,133,5,3);sum_total=zeros(90,72,133,3);sample_count=zeros(90,72,133);included={};
for i=1:numel(expected_dates)
    ymd=expected_dates{i};p=fullfile(day_root,ymd(1:4),ymd(5:6),ymd(7:8),sprintf('CCN_GRID_V2_%s.mat',ymd));
    if ~isfile(p),error('CCNv2:MissingDay','Expected daily product missing: %s',ymd);end
    S=load(p,'sum_component','sum_total','sample_count');
    sum_component=sum_component+S.sum_component;sum_total=sum_total+S.sum_total;sample_count=sample_count+S.sample_count;included{end+1}=ymd; %#ok<AGROW>
end
mean_component=nan(size(sum_component));mean_total=nan(size(sum_total));
for b=1:3
    for q=1:5
        z=sum_component(:,:,:,q,b);z(sample_count>0)=z(sample_count>0)./sample_count(sample_count>0);mean_component(:,:,:,q,b)=z;
    end
    z=sum_total(:,:,:,b);z(sample_count>0)=z(sample_count>0)./sample_count(sample_count>0);mean_total(:,:,:,b)=z;
end
meta=struct('yyyymm',yyyymm,'included_dates',{included},'aggregation','pooled_sum_over_pooled_sample_count','clear_air_in_denominator',false);
outdir=fileparts(output_path);if ~isfolder(outdir),mkdir(outdir);end
save(output_path,'sum_component','sum_total','sample_count','mean_component','mean_total','meta','-v7.3');
result=struct('output_path',output_path,'included_dates',{included});
end
