function plot_layout_day_20070101()
% Render only products freshly generated in layout attempt 20260929_003.
restoredefaultpath;
root='F:\AER_SHARED_PIPELINE';
attempt='20260929_003';
code=fullfile(root,'code');
addpath(fullfile(code,'utils','shared','current'),'-begin');
addpath(fullfile(code,'utils','shared','common'),'-begin');
addpath(fullfile(code,'utils','shared','config'),'-begin');
addpath(fullfile(code,'utils','ccn','ccnv2','consumers'),'-begin');
addpath(fullfile(code,'utils','aod','aodv2','config'),'-begin');
addpath(fullfile(code,'utils','aod','aodv2','utils'),'-begin');
addpath(fullfile(code,'utils','aod','aodv2','consumers'),'-begin');
addpath(fullfile(code,'test','chapter5','chapter5v2'),'-begin');
addpath(fullfile(root,'plots','common'),'-begin');
day=fullfile('2007','01','01');
ccn_dir=fullfile(root,'products','ccn','ccn_v2','ccn_grid_day', ...
 'ccnv2__tall-v2-geotime__era5-rh__omcam-v2__grid2x5-z60','test', ...
 ['code_layout_ccnv2_' attempt],day);
ch5_dir=fullfile(root,'products','chapter5','calipso_stats_chapter5_v2', ...
 'stats-ch5v2__tall-v2-geotime__era5-rh__omcam-v2__grid5deg__stats-v2', ...
 'test',['code_layout_ch5v2_' attempt],day);
clear_dir=fullfile(root,'products','chapter5','clear_air_stats_v2', ...
 'clear__ap-final-v1__geotime-v2','test',['code_layout_clearv2_' attempt],day);
aod_dir=fullfile(root,'products','aod','aod_grid_day', ...
 'aod-grid__global-apro__avd2__profile-mean__grid5deg-v2','test', ...
 ['code_layout_aodv2_' attempt],day);
folders={ccn_dir,ch5_dir,clear_dir,aod_dir};
for k=1:numel(folders)
 report=fullfile(folders{k},'gate_report.txt');
 assert(isfile(report)&&contains(fileread(report),'status=PASS'), ...
  'LayoutPlot:Gate','Current-attempt PASS report missing: %s',report);
end
ccn_file=fullfile(ccn_dir,'CCN_GRID_V2_20070101.mat');
ch5_file=fullfile(ch5_dir,'CALIPSO_STATS_CH5_V2_20070101.mat');
clear_file=fullfile(clear_dir,'CLEAR_AIR_STATS_20070101.mat');
aod_file=fullfile(aod_dir,'AOD_GRID_20070101.mat');
assert(isfile(ccn_file)&&isfile(ch5_file)&&isfile(clear_file)&&isfile(aod_file), ...
 'LayoutPlot:Input','One or more current-attempt daily MAT files are missing.');
ccn_plots=fullfile(ccn_dir,'plots');
ch5_plots=fullfile(ch5_dir,'plots');
aod_plots=fullfile(aod_dir,'plots');
fprintf('LAYOUT_PLOT_CCN_START %s\n',ccn_file);
if ~isfolder(ccn_plots)
 outputs=plot_ccn_v2_monthly_diagnostics(ccn_file,ccn_plots,'smooth_surface','2007-01-01 single-day test');
 assert(all(cellfun(@isfile,{outputs.total,outputs.components,outputs.fractions,outputs.vertical})), ...
  'LayoutPlot:CCN','CCN images incomplete.');
end
ccn_expected={'CCN_V2_20070101_total.png','CCN_V2_20070101_components_ccn025.png', ...
 'CCN_V2_20070101_component_fractions_ccn025.png', ...
 'CCN_V2_20070101_vertical_profile_ccn025.png'};
assert_files(ccn_plots,ccn_expected);
fprintf('LAYOUT_PLOT_CCN_PASS\n');
fprintf('LAYOUT_PLOT_CH5_START %s\n',ch5_file);
if ~isfolder(ch5_plots)
 output=plot_chapter5v2_day_gate_20070101(ch5_file,clear_file,ch5_plots);
 assert(isfile(output),'LayoutPlot:Chapter5','Chapter5 image missing.');
end
assert_files(ch5_plots,{'Figure_5_1_Chapter5_v2_day_20070101.png'});
fprintf('LAYOUT_PLOT_CH5_PASS\n');
fprintf('LAYOUT_PLOT_AOD_START %s\n',aod_file);
if ~isfolder(aod_plots)
 outputs=plot_aod_grid_day(aod_file,aod_plots);
 assert(all(cellfun(@isfile,outputs)),'LayoutPlot:AOD','AOD images incomplete.');
end
assert_files(aod_plots,{'AOD_Direct_Extinction_20070101.png', ...
 'AOD_Chapter5_CCN_Components_20070101.png'});
fprintf('LAYOUT_PLOT_AOD_PASS\n');
fprintf('LAYOUT_PLOT_ALL_PASS attempt=%s\n',attempt);
end

function assert_files(folder,names)
for i=1:numel(names)
 item=dir(fullfile(folder,names{i}));
 assert(numel(item)==1 && item.bytes>0,'LayoutPlot:MissingImage', ...
  'Missing or empty test image: %s',fullfile(folder,names{i}));
end
end
