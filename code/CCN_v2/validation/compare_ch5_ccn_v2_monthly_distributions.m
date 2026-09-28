function result = compare_ch5_ccn_v2_monthly_distributions(yyyymm, report_dir)
%COMPARE_CH5_CCN_V2_MONTHLY_DISTRIBUTIONS Compare whole-grid value distributions.
% This is a marginal distribution diagnostic: it uses every grid cell from
% each product and does not perform spatial matching between the 5-degree
% Chapter 5 grid and the 2-degree-by-5-degree CCN grid.

if nargin < 1 || isempty(yyyymm)
    error('CH5CCN:MonthRequired','Pass the target month as YYYYMM.');
end
yyyymm = char(string(yyyymm));
if isempty(regexp(yyyymm,'^\d{6}$','once'))
    error('CH5CCN:MonthFormat','yyyymm must use YYYYMM.');
end
if nargin < 2 || isempty(report_dir)
    error('CH5CCN:ReportDirRequired','Pass a dedicated report directory.');
end
if ~isfolder(report_dir), mkdir(report_dir); end

this_dir = fileparts(mfilename('fullpath'));
v2_root = fileparts(this_dir);
project_root = fileparts(fileparts(v2_root));
addpath(fullfile(v2_root,'config'),'-begin');
addpath(fullfile(project_root,'code','Chapter5_v2','config'),'-begin');
ccn_cfg = ccn_v2_config();
ch5_cfg = chapter5_v2_config();
yyyy = yyyymm(1:4); mm = yyyymm(5:6);

ch5_path = fullfile(ch5_cfg.map_product_root,yyyy,mm, ...
    ['CHAPTER5_MAP_STATS_V2_' yyyymm '.mat']);
ccn_path = fullfile(ccn_cfg.month_product_root,ccn_cfg.product_key,yyyy,mm, ...
    ['CCN_GRID_V2_MONTH_' yyyymm '.mat']);
if ~isfile(ch5_path), error('CH5CCN:MissingChapter5','Missing %s',ch5_path); end
if ~isfile(ccn_path), error('CH5CCN:MissingCCN','Missing %s',ccn_path); end

A = load(ch5_path);
B = load(ccn_path,'sum_component','sum_total','sample_count','meta');
if isfield(A,'CHAPTER5_MAP_STATS_V2')
    C = A.CHAPTER5_MAP_STATS_V2;
elseif isfield(A,'CHAPTER5_MAP_STATS')
    C = A.CHAPTER5_MAP_STATS;
else
    error('CH5CCN:Chapter5Schema','Input has neither CHAPTER5_MAP_STATS_V2 nor CHAPTER5_MAP_STATS.');
end
assert(isequal(size(C.nd_sum),[36 72 2 7]),'CH5CCN:Chapter5Shape','Unexpected Chapter 5 nd_sum shape.');
assert(isequal(size(C.aerosol_count),[36 72 2]) && isequal(size(C.clear_count),[36 72 2]), ...
    'CH5CCN:Chapter5CountShape','Unexpected Chapter 5 count shape.');
assert(isequal(size(B.sum_component),[90 72 133 5 3]),'CH5CCN:CCNShape','Unexpected CCN component shape.');
assert(isequal(size(B.sum_total),[90 72 133 3]) && isequal(size(B.sample_count),[90 72 133]), ...
    'CH5CCN:CCNCountShape','Unexpected CCN total/count shape.');

% Reproduce the spatial maps' existing definitions (Chapter 5 daytime, CCN 0.25%).
ch5_den = double(C.aerosol_count(:,:,1) + C.clear_count(:,:,1));
ch5_maps = nan(36,72,7);
for t = 1:7
    z = double(C.nd_sum(:,:,1,t));
    ok = ch5_den > 0;
    z(ok) = z(ok)./ch5_den(ok);
    z(~ok) = NaN;
    ch5_maps(:,:,t) = z;
end

ccn_den = sum(double(B.sample_count),3);
ccn_maps = nan(90,72,5);
ccn_names = {'Marine','Dust','Polluted continental','Clean continental','Elevated smoke'};
for q = 1:5
    z = sum(double(B.sum_component(:,:,:,q,2)),3);
    ok = ccn_den > 0;
    z(ok) = z(ok)./ccn_den(ok);
    z(~ok) = NaN;
    ccn_maps(:,:,q) = z;
end

ch5_names = {'Marine','Dust','Polluted continental','Clean continental', ...
    'Polluted dust (mixed)','Elevated smoke','Dusty marine (mixed)'};
stats_rows = cell(12,1);
for t = 1:7
    stats_rows{t} = describe_grid(ch5_maps(:,:,t),'Chapter5',sprintf('Type%d',t),ch5_names{t});
end
for q = 1:5
    stats_rows{7+q} = describe_grid(ccn_maps(:,:,q),'CCN_v2_0.25pct', ...
        sprintf('Component%d',q),ccn_names{q});
end
all_stats = struct2table(vertcat(stats_rows{:}));
all_stats.month = repmat(string(yyyymm),height(all_stats),1);
all_stats = movevars(all_stats,'month','Before',1);
writetable(all_stats,fullfile(report_dir,['grid_distribution_stats_' yyyymm '.csv']));

% These five links are approximate physical-component correspondences, not
% provenance-exact type matches; CCN components can include mixed CALIPSO types.
ch5_type = [1 2 3 4 6];
ccn_component = [1 2 3 4 5];
pair_names = {'Marine';'Dust';'Polluted continental';'Clean continental';'Elevated smoke'};
pair_rows = cell(5,1);
for k = 1:5
    x = ch5_maps(:,:,ch5_type(k)); x = x(isfinite(x));
    y = ccn_maps(:,:,ccn_component(k)); y = y(isfinite(y));
    sx = describe_values(x); sy = describe_values(y);
    if sx.median_positive > 0 && sy.median_positive > 0
        median_ratio = sy.median_positive/sx.median_positive;
        median_log10_difference = log10(median_ratio);
    else
        median_ratio = NaN; median_log10_difference = NaN;
    end
    if sx.mean_positive > 0 && sy.mean_positive > 0
        positive_mean_ratio = sy.mean_positive/sx.mean_positive;
    else
        positive_mean_ratio = NaN;
    end
    pair_rows{k} = {string(yyyymm),ch5_type(k),string(ch5_names{ch5_type(k)}), ...
        ccn_component(k),string(ccn_names{ccn_component(k)}), ...
        sx.n_finite,sy.n_finite,sx.n_positive,sy.n_positive, ...
        sx.n_zero,sy.n_zero,sx.mean_positive,sy.mean_positive, ...
        sx.p05_positive,sx.median_positive,sx.p95_positive, ...
        sy.p05_positive,sy.median_positive,sy.p95_positive, ...
        positive_mean_ratio,median_ratio,median_log10_difference};
end
paired = cell2table(vertcat(pair_rows{:}),'VariableNames',{ ...
    'month','chapter5_type_id','chapter5_category','ccn_component_id','ccn_component', ...
    'chapter5_n_finite_cells','ccn_n_finite_cells','chapter5_n_positive','ccn_n_positive', ...
    'chapter5_n_zero','ccn_n_zero','chapter5_positive_mean','ccn_positive_mean', ...
    'chapter5_positive_p05','chapter5_positive_median','chapter5_positive_p95', ...
    'ccn_positive_p05','ccn_positive_median','ccn_positive_p95', ...
    'ratio_positive_means_ccn_over_ch5','ratio_positive_medians_ccn_over_ch5', ...
    'log10_median_ratio_ccn_over_ch5'});
writetable(paired,fullfile(report_dir,['approximate_category_comparison_' yyyymm '.csv']));

% Quantify how the clear-air count changes the Chapter 5 map denominator.
aerosol_grid = double(C.aerosol_count(:,:,1));
clear_grid = double(C.clear_count(:,:,1));
denominator_grid = aerosol_grid + clear_grid;
has_denominator = denominator_grid > 0;
both_positive = aerosol_grid > 0 & clear_grid > 0;
clear_to_aerosol = clear_grid(both_positive)./aerosol_grid(both_positive);
dilution = aerosol_grid(has_denominator)./denominator_grid(has_denominator);
total_aerosol = sum(aerosol_grid(:));
total_clear = sum(clear_grid(:));
global_clear_to_aerosol = total_clear/total_aerosol;
global_clear_fraction = total_clear/(total_clear+total_aerosol);
global_retained_fraction = total_aerosol/(total_aerosol+total_clear);
if isempty(clear_to_aerosol)
    clear_p05=NaN; clear_median=NaN; clear_p95=NaN;
else
    clear_p05=pct(clear_to_aerosol,.05); clear_median=pct(clear_to_aerosol,.50);
    clear_p95=pct(clear_to_aerosol,.95);
end
if isempty(dilution)
    dilution_p05=NaN; dilution_median=NaN; dilution_p95=NaN;
else
    dilution_p05=pct(dilution,.05); dilution_median=pct(dilution,.50);
    dilution_p95=pct(dilution,.95);
end
count_diagnostic = table(string(yyyymm),total_aerosol,total_clear, ...
    global_clear_to_aerosol,global_clear_fraction,global_retained_fraction, ...
    log10(1+global_clear_to_aerosol),nnz(has_denominator),nnz(aerosol_grid>0), ...
    nnz(both_positive),clear_p05,clear_median,clear_p95, ...
    nnz(clear_to_aerosol>=9),nnz(clear_to_aerosol>=99), ...
    dilution_p05,dilution_median,dilution_p95, ...
    'VariableNames',{'month','total_aerosol_count','total_clear_count', ...
    'global_clear_over_aerosol','global_clear_fraction_of_denominator', ...
    'global_aerosol_retained_fraction','global_log10_denominator_dilution', ...
    'cells_with_any_count','cells_with_aerosol','cells_with_both_counts', ...
    'cell_clear_over_aerosol_p05','cell_clear_over_aerosol_median', ...
    'cell_clear_over_aerosol_p95','cells_clear_at_least_9x_aerosol', ...
    'cells_clear_at_least_99x_aerosol','cell_aerosol_retained_fraction_p05', ...
    'cell_aerosol_retained_fraction_median','cell_aerosol_retained_fraction_p95'});
count_path=fullfile(report_dir,['clear_vs_aerosol_count_diagnostic_' yyyymm '.csv']);
writetable(count_diagnostic,count_path);

summary_path = fullfile(report_dir,['README_' yyyymm '.txt']);
fid = fopen(summary_path,'w');
if fid < 0, error('CH5CCN:ReportWrite','Cannot write %s',summary_path); end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'Chapter 5 / CCN_v2 whole-grid distribution check: %s\n',yyyymm);
fprintf(fid,'Chapter 5 input: %s\n',ch5_path);
fprintf(fid,'CCN_v2 input: %s\n',ccn_path);
fprintf(fid,'Chapter 5 map definition: Daytime Type Nd_dry_OMCAM, summed over heights <= %.1f km and divided by aerosol_count + clear_count.\n',C.alt_limit_km);
fprintf(fid,'CCN map definition: 0.25%% branch, pooled over all 133 canonical 0-8 km levels as sum_component / sample_count; clear air excluded.\n');
fprintf(fid,'All finite grid cells are summarized independently for each product; no geographic cell matching is performed. Positive-only statistics are included for magnitude comparisons, and zeros/missing cells are counted separately.\n');
fprintf(fid,'Type 1/2/3/4/6 to component links are approximate. CCN component pools may include contributions from mixed original types. Type 5 and Type 7 have no one-to-one CCN component match.\n');
fprintf(fid,'The ratio columns compare marginal distribution statistics (means or medians); they are not per-cell ratios.\n');
fprintf(fid,'Clear-count diagnostic uses Chapter 5 daytime aerosol_count and clear_count over the 5-degree grid. The global denominator-only attenuation is aerosol_total/(aerosol_total+clear_total); it does not account for other scientific differences between products.\n');
fprintf(fid,'\nProducts processed: Chapter 5 dates=%d; CCN included dates=%d.\n', ...
    numel(C.processed_dates),numel(B.meta.included_dates));
fprintf(fid,'Outputs: %s\n%s\n%s\n', ...
    fullfile(report_dir,['grid_distribution_stats_' yyyymm '.csv']), ...
    fullfile(report_dir,['approximate_category_comparison_' yyyymm '.csv']),count_path);

result = struct('all_grid_stats',all_stats,'approximate_category_comparison',paired, ...
    'clear_vs_aerosol_count_diagnostic',count_diagnostic, ...
    'summary_path',summary_path,'chapter5_path',ch5_path,'ccn_path',ccn_path);
disp(paired);
fprintf('CH5_CCN_DISTRIBUTION_CHECK_PASS month=%s report=%s\n',yyyymm,report_dir);
end

function row = describe_grid(D,product,code,name)
s = describe_values(D(:));
row = struct('product',string(product),'category_code',string(code),'category',string(name), ...
    'n_grid_cells',numel(D),'n_finite',s.n_finite,'n_positive',s.n_positive, ...
    'n_zero',s.n_zero,'n_negative',s.n_negative,'n_missing',s.n_missing, ...
    'mean_finite',s.mean_finite,'p05_finite',s.p05_finite,'median_finite',s.median_finite, ...
    'p95_finite',s.p95_finite,'max_finite',s.max_finite, ...
    'mean_positive',s.mean_positive,'p05_positive',s.p05_positive, ...
    'median_positive',s.median_positive,'p95_positive',s.p95_positive, ...
    'max_positive',s.max_positive);
end

function s = describe_values(x)
x = double(x(:)); finite = x(isfinite(x)); positive = finite(finite > 0);
s = struct('n_finite',numel(finite),'n_positive',numel(positive), ...
    'n_zero',nnz(finite == 0),'n_negative',nnz(finite < 0), ...
    'n_missing',numel(x)-numel(finite),'mean_finite',NaN,'p05_finite',NaN, ...
    'median_finite',NaN,'p95_finite',NaN,'max_finite',NaN, ...
    'mean_positive',NaN,'p05_positive',NaN,'median_positive',NaN, ...
    'p95_positive',NaN,'max_positive',NaN);
if ~isempty(finite)
    s.mean_finite = mean(finite); s.p05_finite = pct(finite,.05);
    s.median_finite = pct(finite,.50); s.p95_finite = pct(finite,.95);
    s.max_finite = max(finite);
end
if ~isempty(positive)
    s.mean_positive = mean(positive); s.p05_positive = pct(positive,.05);
    s.median_positive = pct(positive,.50); s.p95_positive = pct(positive,.95);
    s.max_positive = max(positive);
end
end

function q = pct(x,p)
x = sort(double(x(:))); n = numel(x);
if n == 0, q = NaN; return; end
u = 1 + (n-1)*p; lo = floor(u); hi = ceil(u);
if lo == hi, q = x(lo); else, q = x(lo) + (u-lo)*(x(hi)-x(lo)); end
end
