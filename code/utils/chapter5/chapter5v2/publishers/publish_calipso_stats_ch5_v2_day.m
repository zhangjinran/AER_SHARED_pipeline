function final_mat = publish_calipso_stats_ch5_v2_day(date_text,candidate_path,gate_path)
%PUBLISH_CALIPSO_STATS_CH5_V2_DAY Atomically publish one gated daily MAT.
cfg=chapter5_v2_config();
d=datetime(date_text,'InputFormat','yyyy-MM-dd'); yyyy=char(string(d,'yyyy')); mm=char(string(d,'MM')); dd=char(string(d,'dd')); ymd=char(string(d,'yyyyMMdd'));
final_dir=fullfile(cfg.stats_product_root,yyyy,mm,dd); final_mat=fullfile(final_dir,['CALIPSO_STATS_CH5_V2_' ymd '.mat']);
if isfolder(final_dir),error('Chapter5v2:Immutable','Final day directory already exists: %s',final_dir);end
if ~isfile(candidate_path) || dir(candidate_path).bytes==0,error('Chapter5v2:Candidate','Missing/empty candidate: %s',candidate_path);end
if ~isfile(gate_path),error('Chapter5v2:Gate','Missing daily Gate report: %s',gate_path);end
G=readtable(gate_path); if height(G)~=1 || G.max_component_sum_error(1)~=0,error('Chapter5v2:Gate','Daily Gate report is not PASS.');end
S=builtin('load',candidate_path,'CALIPSO_STATS_CH5_V2');
if ~strcmp(S.CALIPSO_STATS_CH5_V2.meta.status,'candidate_unpublished'),error('Chapter5v2:Status','Candidate status is invalid.');end
tall=S.CALIPSO_STATS_CH5_V2.meta.source_tall;
if ~isfile(tall) || ~isfile(fullfile(fileparts(tall),'_SUCCESS')),error('Chapter5v2:TAll','Formal T_all contract missing.');end
if ~contains(tall,fullfile('products','tall')),error('Chapter5v2:TAll','Source T_all must be under formal products.');end
parent=fileparts(final_dir);if ~isfolder(parent),mkdir(parent);end
tmp=[final_dir '__publishing'];if isfolder(tmp),error('Chapter5v2:PublishTemp','Stale publishing directory exists: %s',tmp);end
mkdir(tmp);
[ok,msg]=movefile(candidate_path,fullfile(tmp,['CALIPSO_STATS_CH5_V2_' ymd '.mat']));if ~ok,error('Chapter5v2:Move',msg);end
ti=dir(tall); pi=dir(cfg.parameter_file); ei=dir(cfg.extinction_file);
inv=table(string({'T_all';'Parameter_OMCAM_v2';'Extinction_Normalized_v2';'daily_gate'}), ...
    string({tall;cfg.parameter_file;cfg.extinction_file;gate_path}),[ti.bytes;pi.bytes;ei.bytes;dir(gate_path).bytes], ...
    string({ti.date;pi.date;ei.date;dir(gate_path).date}),'VariableNames',{'Kind','Path','Bytes','LastModified'});
writetable(inv,fullfile(tmp,'input_inventory.csv'));
fid=fopen(fullfile(tmp,'manifest.txt'),'w');fprintf(fid,['manifest_version=manifest-v2\nproduct_type=CALIPSO_STATS_CH5_V2\nproduct_key=%s\nstatus=PASS\ndate=%s\nproducer=build_calipso_stats_ch5_v2_day.m\n', ...
    'prior_contract=omcam_v2__acp-table4-unitgate-v1\nvolume_scale_conversion=1e9\nsource_tall=%s\ndaily_gate=PASS\nsuccess_marker=_SUCCESS\n'],cfg.stats_product_key,char(date_text),tall);fclose(fid);
[ok,msg]=movefile(tmp,final_dir);if ~ok,error('Chapter5v2:PublishMove',msg);end
fid=fopen(fullfile(final_dir,'_SUCCESS'),'w');fprintf(fid,'status=PASS\nproduct_key=%s\ndate=%s\n',cfg.stats_product_key,char(date_text));fclose(fid);
fprintf('CHAPTER5_V2_DAY_PUBLISHED date=%s path=%s\n',ymd,final_mat);
end
