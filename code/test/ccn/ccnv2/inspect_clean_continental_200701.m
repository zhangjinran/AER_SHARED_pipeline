function report=inspect_clean_continental_200701(run_root)
%INSPECT_CLEAN_CONTINENTAL_200701 Diagnose Type-4 availability versus CCN-v2 component 4.
root='F:\AER_SHARED_PIPELINE';month=fullfile(root,'products','ccn','ccn_v2','ccn_grid_monthly','ccnv2__tall-v1__era5-rh__omcam-v2__grid2x5-z60','2007','01','CCN_GRID_V2_MONTH_200701.mat');
M=matfile(month);cc=M.sum_component(:,:,:,4,2);cc_sum=sum(cc(:));cc_nonzero=nnz(cc);cc_max=max(cc(:));
troot=fullfile(root,'products','tall','t_all','tall__ap-final-v1__era5-real__adapter-v1__qc-v1','2007','01');dates={};type4=[];alltypes=zeros(1,7);
for d=1:31
 ymd=sprintf('200701%02d',d);p=fullfile(troot,sprintf('%02d',d),sprintf('T_all_%s.mat',ymd));if ~isfile(p),continue;end
 S=load(p,'T_all');t=double(S.T_all.Type);dates{end+1,1}=ymd;type4(end+1,1)=nnz(t==4); %#ok<AGROW>
 for q=1:7,alltypes(q)=alltypes(q)+nnz(t==q);end
 fprintf('TYPE4_DAY %s rows=%d\n',ymd,type4(end));
 clear S t
end
report=table(string(dates),type4,'VariableNames',{'date','type4_rows'});out=fullfile(run_root,'reports','clean_continental_type4_200701.csv');writetable(report,out);
fid=fopen(fullfile(run_root,'reports','clean_continental_diagnosis_200701.txt'),'w');fprintf(fid,'component=clean_continental\nsource_type=4_only\ntype4_rows_total=%d\nccn025_sum=%g\nccn025_nonzero_voxels=%d\nccn025_max_sum=%g\nall_type_counts=%s\n',sum(type4),cc_sum,cc_nonzero,cc_max,mat2str(alltypes));fclose(fid);
fprintf('TYPE4_TOTAL=%d CC_SUM=%g CC_NONZERO=%d CC_MAX=%g\n',sum(type4),cc_sum,cc_nonzero,cc_max);
end
