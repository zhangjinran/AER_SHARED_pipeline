function run_plot_with_logging(script_path, run_root, label)
%RUN_PLOT_WITH_LOGGING Execute one plot script with isolated run logging.
script_path=char(script_path); run_root=char(run_root); label=char(label);
plot_dir=fullfile(run_root,'plots',label); log_dir=fullfile(run_root,'logs','plots',label);
if ~isfolder(plot_dir), mkdir(plot_dir); end
if ~isfolder(log_dir), mkdir(log_dir); end
stamp=datestr(now,'yyyymmdd_HHMMss'); diary_path=fullfile(log_dir,[label '_' stamp '.log']); status_path=fullfile(log_dir,[label '_' stamp '.status']);
fid=fopen(status_path,'w'); fprintf(fid,'status=RUNNING\nscript=%s\nstarted=%s\n',script_path,datestr(now,31)); fclose(fid);
old=pwd; c=onCleanup(@()cd(old)); cd(fileparts(script_path)); diary(diary_path);
try
  run(script_path);
  diary off; fid=fopen(status_path,'w'); fprintf(fid,'status=PASS\nscript=%s\nfinished=%s\nlog=%s\noutput_dir=%s\n',script_path,datestr(now,31),diary_path,plot_dir); fclose(fid);
catch ME
  disp(getReport(ME,'extended','hyperlinks','off')); diary off; fid=fopen(status_path,'w'); fprintf(fid,'status=FAIL\nscript=%s\nfinished=%s\nlog=%s\nerror_identifier=%s\n',script_path,datestr(now,31),diary_path,ME.identifier); fclose(fid); rethrow(ME);
end
end
