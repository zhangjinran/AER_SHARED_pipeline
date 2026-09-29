function result = resume_component_optical_prior_v2(component_name,varargin)
%RESUME_COMPONENT_OPTICAL_PRIOR_V2 Finish only missing RH outputs in an existing v2 stage.
% Existing valid .lidar results are read and retained; no completed RH is rerun.

p=inputParser;
p.addRequired('component_name',@(x)ischar(x)||isstring(x));
p.addParameter('RunRoot','',@(x)ischar(x)||isstring(x));
p.addParameter('AttemptId','attempt_001',@(x)ischar(x)||isstring(x));
p.addParameter('MopsmapRoot','F:\MOPSMAP\mopsmap',@(x)ischar(x)||isstring(x));
p.addParameter('WslDistro','Ubuntu',@(x)ischar(x)||isstring(x));
p.addParameter('MaxRetries',3,@(x)isnumeric(x)&&isscalar(x)&&x>=1);
p.parse(component_name,varargin{:}); opt=p.Results;

name=char(string(opt.component_name)); run_root=char(opt.RunRoot); root=char(opt.MopsmapRoot);
if isempty(run_root)||~isfolder(run_root),error('CCNv2:MissingRunRoot','RunRoot must exist.');end
stage=fullfile(run_root,'staging','priors','components',name,char(opt.AttemptId));
if ~isfolder(stage),error('CCNv2:MissingStage','Missing existing stage: %s',stage);end
this_dir=fileparts(mfilename('fullpath')); addpath(fullfile(fileparts(this_dir),'config'),'-begin'); cfg=ccn_v2_config();
if ~isfield(cfg.parameters,name),error('CCNv2:BadComponent','Unsupported component: %s',name);end
c=cfg.parameters.(name); rh=(0:99)'; ext=nan(size(rh));
log_path=fullfile(stage,'validation','resume_log.txt');
append_log(log_path,sprintf('RESUME_START=%s\n',datestr(now,31)));

for i=1:numel(rh)
    lidar=fullfile(stage,sprintf('%s_rh%02d.lidar',name,rh(i)));
    [ok,val]=read_extinction(lidar);
    if ok
        ext(i)=val;
        continue
    end
    input=fullfile(stage,'inputs',sprintf('input_rh%02d.txt',rh(i)));
    if ~isfile(input),error('CCNv2:MissingInput','Missing input for RH %d: %s',rh(i),input);end
    last_msg=''; succeeded=false;
    for attempt=1:opt.MaxRetries
        cmd=sprintf('wsl.exe -d %s -u root -- bash -lc "cd ''%s'' && ''%s'' ''inputs/input_rh%02d.txt'' > ''logs/mopsmap_rh%02d_resume%d.log'' 2>&1"', ...
            char(opt.WslDistro),to_wsl(stage),to_wsl(fullfile(root,'mopsmap')),rh(i),rh(i),attempt);
        [s,last_msg]=system(cmd);
        [ok,val]=read_extinction(lidar);
        append_log(log_path,sprintf('RH=%02d attempt=%d exit=%d valid=%d %s\n',rh(i),attempt,s,ok,datestr(now,31)));
        if s==0 && ok, ext(i)=val; succeeded=true; break; end
        pause(2);
    end
    if ~succeeded
        append_log(log_path,sprintf('RH=%02d FINAL_FAILURE message=%s\n',rh(i),last_msg));
        error('CCNv2:ResumeMopsmap','RH %d did not produce valid output after %d retries: %s',rh(i),opt.MaxRetries,last_msg);
    end
end

prior_table=[rh ext]; save(fullfile(stage,'candidates',[name '_alpha_n.mat']),'prior_table','name','c','-v7');
writetable(table(rh,ext,'VariableNames',{'RH_percent','extinction_per_Mm'}),fullfile(stage,'outputs',[name '_alpha_n.csv']));
write_text(fullfile(stage,'validation','status.txt'),sprintf('STATUS=PASS\nRESUMED_AT=%s\n',datestr(now,31)));
append_log(log_path,sprintf('RESUME_PASS=%s\n',datestr(now,31)));
result=struct('status','pass_resumed','stage_root',stage,'prior_table_path',fullfile(stage,'candidates',[name '_alpha_n.mat']));
end

function [ok,val]=read_extinction(path)
ok=false; val=nan;
if ~isfile(path),return;end
try
    x=readmatrix(path,'FileType','text'); x=x(isfinite(x));
    if numel(x)>=2, val=x(2); ok=isfinite(val)&&val>0; end
catch
end
end
function out=to_wsl(in)
in=char(in); out=['/mnt/' lower(in(1)) strrep(in(3:end),'\','/')];
end
function append_log(path,text)
fid=fopen(path,'a'); if fid<0,error('CCNv2:Write','Cannot append %s',path);end
cl=onCleanup(@()fclose(fid)); fprintf(fid,'%s',text);
end
function write_text(path,text)
fid=fopen(path,'w'); if fid<0,error('CCNv2:Write','Cannot write %s',path);end
cl=onCleanup(@()fclose(fid)); fprintf(fid,'%s',text);
end
