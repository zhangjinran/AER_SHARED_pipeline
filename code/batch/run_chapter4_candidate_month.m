function run_chapter4_candidate_month(project,prior_root,stats_month,aeronet_file,site_file,ch4,ym)
setenv('AER_PRIOR_ROOT',prior_root); setenv('AER_PRIOR_PARAMETER_FILE',fullfile(prior_root,'Parameter_Particle_CALISPO_candidate.mat')); setenv('AER_PRIOR_EXTINCTION_FILE',fullfile(prior_root,'Extinction_Normalized_candidate.mat'));
setenv('CHAPTER4_CALIPSO_STATS_FILE',stats_month); setenv('CHAPTER4_AERONET_FILE',aeronet_file); setenv('CHAPTER4_AERONET_SITE_INFO_FILE',site_file);
match=fullfile(ch4,['AERONET_CALIPSO_Matched_' ym '_marine_v2.mat']); col=fullfile(ch4,['AERONET_CALIPSO_Column_Integrated_DB_' ym '_marine_v2.mat']);
setenv('CHAPTER4_MATCH_OUTPUT_FILE',match); setenv('CHAPTER4_MATCH_INPUT_FILE',match); setenv('CHAPTER4_COLUMN_OUTPUT_FILE',col);
addpath(fullfile(project,'code','consumers','chapter4'),'-begin'); addpath(fullfile(project,'code','functions'),'-begin');
if ~isfile(match), run(fullfile(project,'code','consumers','chapter4','ARONET_CALIPSO_Fast_Collocation.m')); else, fprintf('CHAPTER4_MATCH_ALREADY_READY %s\n',match); end
if ~isfile(col), run(fullfile(project,'code','consumers','chapter4','PostProcess_Column_Integration_OneToOne_Weighted_WithTime.m')); else, fprintf('CHAPTER4_COLUMN_ALREADY_READY %s\n',col); end
end
