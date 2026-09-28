% Minimal smoke test for the existing CCN core using real CSV records.
% This file is intentionally separate from the production pipeline.
clc; clear;
project_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(project_dir, '函数'));
addpath(fullfile(project_dir, '先验数据'));

csv_file = fullfile(project_dir, 'CALIPSO_results_Batch_1.csv');
assert(isfile(csv_file), '找不到现有 CSV: %s', csv_file);

T = readtable(csv_file);

good = isfinite(T.Ext) & T.Ext > 0 & isfinite(T.Back) & T.Back > 0 & ...
        isfinite(T.Depol) & T.Depol > 0.05 & T.Depol < 0.31 & ...
        isfinite(T.RH) & T.RH > 0 & T.RH < 100 & isfinite(T.Type) & ...
        T.Type >= 1 & T.Type <= 7;
T = T(good,:);
T = T(1:min(100,height(T)),:);
assert(~isempty(T), 'CSV 中没有可用于 CCN 冒烟测试的有效记录。');

R = load(fullfile(project_dir, 'result', 'AERONET_dVdlnr_R.mat'));
P = load(fullfile(project_dir, '先验数据', 'Parameter_Particle_CALISPO.mat'));
E = load(fullfile(project_dir, '先验数据', 'Extinction_Normalized.mat'));
Radius = R.AERONET_dVdlnr_R;
P = P.data;
E = E.Extinction_N;

% Match the production table layout: rows are aerosol type, columns are RH bins.
ExtNorm = zeros(6, size(E.CM,1));
ExtNorm(1,:) = E.CM(:,2)'; ExtNorm(2,:) = E.DU(:,2)';
ExtNorm(3,:) = E.PC(:,2)'; ExtNorm(4,:) = E.CC(:,2)';
ExtNorm(5,:) = E.PD(:,2)'; ExtNorm(6,:) = E.SM(:,2)';

D = struct();
D.Out_ExtCoef_Particle = T.Ext;
D.Out_Backscatter_Coefficient = T.Back;
D.Out_Depolarization_Ratio = T.Depol;
D.Out_RH = T.RH;
D.Out_Type_Aer2 = T.Type;

% Empty targets exercise the existing Nd and fixed-factor CCN path.
Out = Fun_CALIPSO_Calculation_dVdlnr_dNdlnr_Nd_Consider_Hyg_Integral(...
    D, Radius, P, ExtNorm, [], []);

fprintf('CCN minimal test records: %d\n', height(T));
fprintf('finite Nd dry: %d/%d\n', sum(isfinite(Out.Nd_CALIPSO_dry(:))), numel(Out.Nd_CALIPSO_dry));
fprintf('finite CCN_15: %d/%d\n', sum(isfinite(Out.CCN_15(:))), numel(Out.CCN_15));
fprintf('finite CCN_25: %d/%d\n', sum(isfinite(Out.CCN_25(:))), numel(Out.CCN_25));
fprintf('finite CCN_40: %d/%d\n', sum(isfinite(Out.CCN_40(:))), numel(Out.CCN_40));
save(fullfile(project_dir, 'test_CCN_minimal_existing_data_output.mat'), 'Out', 'T');
fprintf('saved: test_CCN_minimal_existing_data_output.mat\n');
