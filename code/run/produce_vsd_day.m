function output_path=produce_vsd_day(date_ymd,cfg)
%PRODUCE_VSD_DAY 按轨道生成一天的 APRO bin 级干态 VSD MAT。
% cfg.apro_root、cfg.era_root、cfg.prior_root、cfg.product_root 和
% cfg.run_root 均由运行配置提供。入口不写死旧管线路径，也不覆盖已有正式产品。
code_root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(code_root,'configs'),fullfile(code_root,'utils','vsd'));
science=vsd_config();
dt=datetime(date_ymd,'InputFormat','yyyyMMdd');
ymd=datestr(dt,'yyyymmdd'); yy=datestr(dt,'yyyy'); mm=datestr(dt,'mm'); dd=datestr(dt,'dd');
apro_path=fullfile(cfg.apro_root,yy,sprintf('%s_%s_%s.mat',yy,mm,dd));
day_dir=fullfile(cfg.product_root,yy,mm,dd);
output_path=fullfile(day_dir,sprintf('VSD_%s.mat',ymd));
if isfolder(day_dir)||isfile(output_path)
    error('VSD:ExistingProduct','Formal day target already exists: %s',day_dir);
end
if ~isfile(apro_path),error('VSD:MissingAPRO','Missing APRO MAT: %s',apro_path);end
prior=load_vsd_priors(fullfile(cfg.prior_root,'Parameter_OMCAM_v2.mat'), ...
    fullfile(cfg.prior_root,'Extinction_Normalized_v2.mat'),science);
stage_dir=fullfile(cfg.run_root,'staging',ymd);
if isfolder(stage_dir),error('VSD:ExistingStage','Stage already exists: %s',stage_dir);end
mkdir(stage_dir); stage_mat=fullfile(stage_dir,sprintf('VSD_%s.mat',ymd));
A=load(apro_path,'day');
if ~isfield(A,'day')||~isfield(A.day,'files')||isempty(A.day.files)
    error('VSD:APROSchema','APRO day.files is empty/missing.');
end
files=A.day.files; clear A;
counts=zeros(numel(files),6); hdf=cell(numel(files),1);
for i=1:numel(files)
    raw=files{i}; hdf{i}=char(raw.filename);
    rh=match_era5_rh_orbit(raw,cfg.era_root);
    [records,diag]=build_vsd_orbit(raw,rh,prior,science);
    varname=sprintf('orbit_%03d',i);
    payload=struct();payload.(varname)=records;
    if i==1
        save(stage_mat,'-struct','payload','-v7.3');
    else
        save(stage_mat,'-struct','payload','-append');
    end
    counts(i,:)=[diag.profiles diag.bins diag.no_aerosol_bins ...
        diag.output_aerosol_bins diag.mixed_bins diag.invalid_aerosol_bins];
    fprintf('VSD_ORBIT %d/%d %s: bins=%d clear=%d valid_aerosol=%d mixed=%d invalid=%d records=%d\n', ...
        i,numel(files),hdf{i},diag.bins,diag.no_aerosol_bins, ...
        diag.output_aerosol_bins,diag.mixed_bins,diag.invalid_aerosol_bins,diag.output_records);
    files{i}=[]; clear raw records payload rh;
end
inventory=table(hdf,counts(:,1),counts(:,2),counts(:,3),counts(:,4), ...
    counts(:,5),counts(:,6),'VariableNames',{'source_hdf','profiles','bins', ...
    'no_aerosol_bins','valid_aerosol_bins','mixed_bins','invalid_aerosol_bins'});
writetable(inventory,fullfile(stage_dir,'input_inventory.csv'));
fid=fopen(fullfile(stage_dir,'manifest.txt'),'w');
if fid<0,error('VSD:Manifest','Cannot write manifest.');end
fprintf(fid,'schema=vsd-dry-parameterized\ndate=%s\nsource=%s\n',ymd,apro_path);
fprintf(fid,'orbit_count=%d\nrecord_layout=one_columnar_struct_per_orbit\n',numel(files));
fprintf(fid,'record_key=source_hdf,profile_id,sample_id,component_id\n');
fprintf(fid,'spectrum=dV/dlnr=volume_um3_cm3*normalized_component_q(r_um)\n');
fprintf(fid,'qc=required_numeric_only;no_ESSD_QC_fields_available\n');
fclose(fid);
% 仅当 MAT 非空且元数据齐全时，才允许发布正式产品。
if dir(stage_mat).bytes<=0,error('VSD:EmptyMAT','Day MAT is empty.');end
parent=fileparts(day_dir);
if ~isfolder(parent),mkdir(parent);end
[ok,msg]=movefile(stage_dir,day_dir);
if ~ok,error('VSD:Publish','Cannot publish day directory: %s',msg);end
fid=fopen(fullfile(day_dir,'_SUCCESS'),'w');
if fid<0,error('VSD:SuccessMarker','Cannot write _SUCCESS.');end
fprintf(fid,'PASS %s\n',ymd);fclose(fid);
fprintf('VSD_DAY_COMPLETE %s orbits=%d mat=%s\n',ymd,numel(files),output_path);
end
