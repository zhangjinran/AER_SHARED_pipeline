function result = rebuild_marine_prior(varargin)
%REBUILD_MARINE_PRIOR Rebuild the Marine (Type 1 / CM) optical prior in staging.
%
% This is deliberately a candidate-only producer.  It never writes into
% inputs\priors or products.  Every execution is isolated by
% RunRoot/staging/marine_prior/<phase>/<attempt>.
%
% Workflow:
%   1) Phase='legacy_reproduction' recreates the legacy CM dV/dlnr files,
%      executes MOPSMAP for RH 0:99, and compares every CM extinction value
%      against the canonical Extinction_Normalized.mat.
%   2) Phase='new_candidate' is refused unless the selected legacy attempt
%      has passed its numerical replay gate.  It uses the supplied AERONET
%      Marine parameters and writes candidate prior MAT files only.
%
% The supplied Marine values intentionally change only size distribution and
% complex RI.  Hygroscopicity, shape, size support, wavelength and the MOPSMAP
% optical data set are carried over from the legacy CM configuration.

p = inputParser;
p.addParameter('RunRoot', '', @(x)ischar(x) || isstring(x));
p.addParameter('Phase', 'legacy_reproduction', @(x)ischar(x) || isstring(x));
p.addParameter('AttemptId', 'attempt_001', @(x)ischar(x) || isstring(x));
p.addParameter('LegacyAttemptId', 'attempt_001', @(x)ischar(x) || isstring(x));
p.addParameter('PriorRoot', 'F:\AER_SHARED_PIPELINE\inputs\priors', @(x)ischar(x) || isstring(x));
p.addParameter('MopsmapRoot', 'F:\MOPSMAP\mopsmap', @(x)ischar(x) || isstring(x));
p.addParameter('WslDistro', 'Ubuntu', @(x)ischar(x) || isstring(x));
p.addParameter('ExecuteMopsmap', true, @(x)islogical(x) && isscalar(x));
p.addParameter('RelativeTolerance', 5e-6, @(x)isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('AbsoluteTolerance', 1e-3, @(x)isnumeric(x) && isscalar(x) && x > 0);
p.parse(varargin{:});
opt = p.Results;

run_root = char(opt.RunRoot);
phase = lower(char(opt.Phase));
attempt_id = char(opt.AttemptId);
prior_root = char(opt.PriorRoot);
mopsmap_root = char(opt.MopsmapRoot);
wsl_distro = char(opt.WslDistro);

if ~ismember(phase, {'legacy_reproduction','new_candidate'})
    error('MarinePrior:BadPhase', 'Phase must be legacy_reproduction or new_candidate.');
end
if isempty(run_root) || ~isfolder(run_root)
    error('MarinePrior:MissingRunRoot', 'RunRoot must be an existing run directory.');
end
if ~isfolder(prior_root) || ~isfolder(mopsmap_root)
    error('MarinePrior:MissingSource', 'PriorRoot or MopsmapRoot does not exist.');
end

stage_root = fullfile(run_root, 'staging', 'marine_prior', phase, attempt_id);
if isfolder(stage_root)
    error('MarinePrior:AttemptExists', ...
        'Attempt directory already exists: %s. Use a new AttemptId; do not overwrite diagnostics.', stage_root);
end

layout = make_layout(stage_root);
mkdir_all(layout);

canonical_parameter = fullfile(prior_root, 'Parameter_Particle_CALISPO.mat');
canonical_extinction = fullfile(prior_root, 'Extinction_Normalized.mat');
assert(isfile(canonical_parameter), 'MarinePrior:MissingParameter', 'Missing %s', canonical_parameter);
assert(isfile(canonical_extinction), 'MarinePrior:MissingExtinction', 'Missing %s', canonical_extinction);

if strcmp(phase, 'new_candidate')
    legacy_gate = fullfile(run_root, 'staging', 'marine_prior', 'legacy_reproduction', ...
        char(opt.LegacyAttemptId), 'validation', 'legacy_reproduction_gate.txt');
    assert_legacy_gate(legacy_gate);
else
    legacy_gate = '';
end

P = load(canonical_parameter, 'data');
assert(isfield(P, 'data'), 'MarinePrior:BadParameterMat', 'Parameter MAT must contain variable data.');
assert(numel(P.data.v_i_fine) >= 1, 'MarinePrior:BadParameterMat', 'Type 1 is missing from parameter data.');

legacy = read_legacy_type1(P.data);
new = supplied_marine_type1(legacy);
if strcmp(phase, 'legacy_reproduction')
    marine = legacy;
else
    marine = new;
end

write_parameter_record(fullfile(layout.metadata, 'marine_parameters.csv'), marine, phase);
write_parameter_record(fullfile(layout.metadata, 'legacy_reference_parameters.csv'), legacy, 'legacy_reference');
write_text(fullfile(layout.metadata, 'source_paths.txt'), sprintf([ ...
    'canonical_parameter=%s\ncanonical_extinction=%s\nmopsmap_root=%s\nlegacy_gate=%s\n'], ...
    canonical_parameter, canonical_extinction, mopsmap_root, legacy_gate));

radius_um = logspace(log10(0.05), log10(15), 1000).';
if strcmp(phase, 'legacy_reproduction')
    % Strict replay must use the exact historical input grids, not a new
    % formula evaluation that could differ in its final printed decimal.
    fine_file = fullfile(mopsmap_root, 'CMFine.txt');
    coarse_file = fullfile(mopsmap_root, 'CMCoarse.txt');
    assert(isfile(fine_file) && isfile(coarse_file), 'MarinePrior:MissingLegacyDistribution', ...
        'Historical CMFine.txt or CMCoarse.txt is missing from %s.', mopsmap_root);
else
    fine_file = fullfile(layout.inputs, 'CMFine.txt');
    coarse_file = fullfile(layout.inputs, 'CMCoarse.txt');
    write_volume_lognormal(fine_file, radius_um, marine.fine.volume_fraction, ...
        marine.fine.mean_radius_um, marine.fine.geometric_std);
    write_volume_lognormal(coarse_file, radius_um, marine.coarse.volume_fraction, ...
        marine.coarse.mean_radius_um, marine.coarse.geometric_std);
end

write_distribution_moments(fullfile(layout.metadata, 'distribution_moments.csv'), ...
    fine_file, coarse_file);

rh = (0:99).';
for i = 1:numel(rh)
    write_mopsmap_input(fullfile(layout.inputs, sprintf('input_rh%02d.txt', rh(i))), ...
        fine_file, coarse_file, mopsmap_root, marine, rh(i));
end

if ~opt.ExecuteMopsmap
    write_text(fullfile(layout.validation, 'execution_status.txt'), sprintf(...
        'STATUS=PREPARED_ONLY\nMOPSMAP was not executed.\n'));
    result = struct('status','prepared_only','stage_root',stage_root,'phase',phase);
    return;
end

extinction = run_mopsmap_grid(layout, mopsmap_root, rh, wsl_distro);
T = table(rh, extinction, 'VariableNames', {'RH_percent','extinction_per_Mm'});
writetable(T, fullfile(layout.outputs, 'marine_cm_extinction_rh_0_99.csv'));

E = load(canonical_extinction, 'Extinction_N');
assert(isfield(E, 'Extinction_N') && isfield(E.Extinction_N, 'CM'), ...
    'MarinePrior:BadExtinctionMat', 'Extinction MAT must contain Extinction_N.CM.');
Extinction_N = E.Extinction_N;
Extinction_N.CM = [rh, extinction]; %#ok<NASGU>
candidate_extinction = fullfile(layout.candidates, 'Extinction_Normalized_candidate.mat');
save(candidate_extinction, 'Extinction_N', '-v7');

data = P.data; %#ok<NASGU>
data = apply_type1(data, marine);
candidate_parameter = fullfile(layout.candidates, 'Parameter_Particle_CALISPO_candidate.mat');
save(candidate_parameter, 'data', '-v7');

if strcmp(phase, 'legacy_reproduction')
    canonical_cm = E.Extinction_N.CM;
    assert(isequal(canonical_cm(:,1), rh), 'MarinePrior:CanonicalRH', ...
        'Canonical CM RH coordinate is not exactly 0:99.');
    delta = extinction - canonical_cm(:,2);
    rel_delta = abs(delta) ./ max(abs(canonical_cm(:,2)), eps);
    pass = abs(delta) <= opt.AbsoluteTolerance | rel_delta <= opt.RelativeTolerance;
    V = table(rh, canonical_cm(:,2), extinction, delta, rel_delta, pass, ...
        'VariableNames', {'RH_percent','canonical_extinction','reproduced_extinction', ...
        'difference','relative_difference','pass'});
    writetable(V, fullfile(layout.validation, 'legacy_cm_vs_canonical.csv'));
    write_legacy_gate(fullfile(layout.validation, 'legacy_reproduction_gate.txt'), ...
        pass, opt.RelativeTolerance, opt.AbsoluteTolerance);
    if ~all(pass)
        error('MarinePrior:LegacyReplayFailed', ...
            ['Legacy replay did not reproduce the canonical CM table. ', ...
             'New parameters are blocked; inspect %s.'], ...
             fullfile(layout.validation, 'legacy_cm_vs_canonical.csv'));
    end
end

write_manifest(fullfile(layout.metadata, 'candidate_manifest.txt'), phase, marine, ...
    candidate_parameter, candidate_extinction, canonical_parameter, canonical_extinction, mopsmap_root);
write_text(fullfile(layout.validation, 'execution_status.txt'), sprintf('STATUS=PASS\n'));

result = struct('status','pass','stage_root',stage_root,'phase',phase, ...
    'candidate_parameter',candidate_parameter,'candidate_extinction',candidate_extinction);
end

function layout = make_layout(stage_root)
layout.stage_root = stage_root;
layout.inputs = fullfile(stage_root, 'inputs');
layout.outputs = fullfile(stage_root, 'outputs');
layout.logs = fullfile(stage_root, 'logs');
layout.metadata = fullfile(stage_root, 'metadata');
layout.validation = fullfile(stage_root, 'validation');
layout.candidates = fullfile(stage_root, 'candidates');
end

function mkdir_all(layout)
names = fieldnames(layout);
for i = 1:numel(names)
    mkdir(layout.(names{i}));
end
end

function marine = read_legacy_type1(data)
marine = struct();
marine.fine = struct('volume_fraction',data.v_i_fine(1), ...
    'mean_radius_um',data.r_mean_fine(1), 'geometric_std',data.GSD_fine(1), ...
    'ri_real',data.m_r_fine(1), 'ri_imag',data.m_i_fine(1), 'kappa',0.7);
marine.coarse = struct('volume_fraction',data.v_i_coarse(1), ...
    'mean_radius_um',data.r_mean_coarse(1), 'geometric_std',data.GSD_coarse(1), ...
    'ri_real',data.m_r_coarse(1), 'ri_imag',data.m_i_coarse(1), 'kappa',0.7);
end

function marine = supplied_marine_type1(legacy)
marine = legacy;
marine.fine.volume_fraction = 0.14;
marine.fine.mean_radius_um = 0.1137;
marine.fine.geometric_std = 1.6487;
marine.fine.ri_real = 1.5478;
marine.fine.ri_imag = 0.0053;
marine.coarse.volume_fraction = 0.86;
marine.coarse.mean_radius_um = 1.8756;
marine.coarse.geometric_std = 2.0544;
marine.coarse.ri_real = 1.4108;
marine.coarse.ri_imag = 0.0;
end

function data = apply_type1(data, marine)
data.v_i_fine(1) = marine.fine.volume_fraction;
data.r_mean_fine(1) = marine.fine.mean_radius_um;
data.GSD_fine(1) = marine.fine.geometric_std;
data.m_r_fine(1) = marine.fine.ri_real;
data.m_i_fine(1) = marine.fine.ri_imag;
data.v_i_coarse(1) = marine.coarse.volume_fraction;
data.r_mean_coarse(1) = marine.coarse.mean_radius_um;
data.GSD_coarse(1) = marine.coarse.geometric_std;
data.m_r_coarse(1) = marine.coarse.ri_real;
data.m_i_coarse(1) = marine.coarse.ri_imag;
end

function write_volume_lognormal(path, r, volume_fraction, rmean, gsd)
sigma_ln = log(gsd);
dvdlnr = volume_fraction ./ (sqrt(2*pi) * sigma_ln) .* ...
    exp(-0.5 .* ((log(r) - log(rmean)) ./ sigma_ln).^2);
fid = fopen(path, 'w');
assert(fid > 0, 'MarinePrior:WriteFailed', 'Cannot write %s', path);
cleaner = onCleanup(@()fclose(fid)); %#ok<NASGU>
for i = 1:numel(r)
    fprintf(fid, '%.6f %.6f\n', r(i), dvdlnr(i));
end
end

function write_distribution_moments(path, fine_file, coarse_file)
fine = distribution_file_moments(fine_file);
coarse = distribution_file_moments(coarse_file);
T = table(["fine";"coarse"], [fine.volume;coarse.volume], ...
    [fine.rmean;coarse.rmean], [fine.gsd;coarse.gsd], ...
    [string(fine_file);string(coarse_file)], ...
    'VariableNames', {'mode','integrated_volume','geometric_mean_radius_um','geometric_std','source_file'});
writetable(T, path);
end

function m = distribution_file_moments(path)
xy = readmatrix(path, 'FileType', 'text');
assert(size(xy,2) >= 2 && all(isfinite(xy(:,1:2)), 'all'), 'MarinePrior:BadDistribution', ...
    'Invalid dV/dlnr file: %s', path);
r = xy(:,1);
y = xy(:,2);
lnr = log(r);
v = trapz(lnr, y);
mu = trapz(lnr, y .* lnr) ./ v;
var_ln = trapz(lnr, y .* lnr.^2) ./ v - mu.^2;
m = struct('volume',v,'rmean',exp(mu),'gsd',exp(sqrt(max(var_ln, 0))));
end

function write_mopsmap_input(path, fine_file, coarse_file, mopsmap_root, marine, rh)
data_root = win_to_wsl(fullfile(mopsmap_root, 'data'));
scatlib = win_to_wsl(fullfile(mopsmap_root, 'optical_dataset'));
fine_wsl = win_to_wsl(fine_file);
coarse_wsl = win_to_wsl(coarse_file);
stem = sprintf('marine_cm_rh%02d', rh);
fid = fopen(path, 'w');
assert(fid > 0, 'MarinePrior:WriteFailed', 'Cannot write %s', path);
cleaner = onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid, "mode 1 size distr_file dvdlnr '%s'\n", fine_wsl);
fprintf(fid, "mode 2 size distr_file dvdlnr '%s'\n", coarse_wsl);
fprintf(fid, 'mode 1 refrac %.7f %.7f\n', marine.fine.ri_real, marine.fine.ri_imag);
fprintf(fid, 'mode 1 kappa %.7f\n', marine.fine.kappa);
fprintf(fid, "mode 1 shape spheroid distr_file '%s'\n", [data_root '/ar_dubovik']);
fprintf(fid, 'mode 2 refrac %.7f %.7f\n', marine.coarse.ri_real, marine.coarse.ri_imag);
fprintf(fid, 'mode 2 kappa %.7f\n', marine.coarse.kappa);
fprintf(fid, "mode 2 shape spheroid distr_file '%s'\n", [data_root '/ar_dubovik']);
fprintf(fid, 'wavelength 0.532\n');
fprintf(fid, 'rH %d\n', rh);
fprintf(fid, 'size_equ vol\n');
fprintf(fid, "scatlib '%s'\n", scatlib);
fprintf(fid, "water_refrac_file '%s'\n", [data_root '/refr_water_segelstein']);
fprintf(fid, 'output lidar\n');
fprintf(fid, "output ascii_file '%s'\n", stem);
end

function extinction = run_mopsmap_grid(layout, mopsmap_root, rh, wsl_distro)
preflight_cmd = sprintf('wsl.exe -d %s -u root -- /bin/true', wsl_distro);
[wsl_status, wsl_message] = system(preflight_cmd);
if wsl_status ~= 0
    write_text(fullfile(layout.logs, 'wsl_preflight.log'), sprintf([ ...
        'STATUS=FAIL\nREASON=No usable WSL distribution is installed.\n', ...
        'DETAIL=%s\n'], wsl_message));
    error('MarinePrior:WslUnavailable', ...
        ['MOPSMAP is a Linux ELF binary, but WSL has no usable distribution. ', ...
         'Install or select a WSL distribution before attempting the replay.']);
end
stage_wsl = win_to_wsl(layout.stage_root);
exe_wsl = win_to_wsl(fullfile(mopsmap_root, 'mopsmap'));
extinction = nan(numel(rh), 1);
for i = 1:numel(rh)
    input_name = sprintf('inputs/input_rh%02d.txt', rh(i));
    log_name = sprintf('logs/mopsmap_rh%02d.log', rh(i));
    cmd = sprintf('wsl.exe -d %s -u root -- bash -lc "cd ''%s'' && ''%s'' ''%s'' > ''%s'' 2>&1"', ...
        wsl_distro, stage_wsl, exe_wsl, input_name, log_name);
    [status, message] = system(cmd);
    if status ~= 0
        write_text(fullfile(layout.logs, sprintf('launcher_rh%02d_failure.txt', rh(i))), message);
        error('MarinePrior:MopsmapFailure', 'MOPSMAP failed at RH=%d. See %s', rh(i), ...
            fullfile(layout.logs, sprintf('mopsmap_rh%02d.log', rh(i))));
    end
    lidar_file = fullfile(layout.stage_root, sprintf('marine_cm_rh%02d.lidar', rh(i)));
    if ~isfile(lidar_file)
        error('MarinePrior:MissingLidarOutput', 'MOPSMAP created no lidar output at RH=%d.', rh(i));
    end
    fid = fopen(lidar_file, 'r');
    assert(fid > 0, 'MarinePrior:BadLidarOutput', 'Cannot open %s.', lidar_file);
    cleaner = onCleanup(@()fclose(fid)); %#ok<NASGU>
    parsed = textscan(fid, '%f', 'CollectOutput', true);
    out = parsed{1};
    if isempty(out) || numel(out) < 2 || ~isfinite(out(2))
        error('MarinePrior:BadLidarOutput', 'Cannot read extinction column from %s.', lidar_file);
    end
    extinction(i) = out(2);
end
end

function p = win_to_wsl(win_path)
win_path = char(win_path);
if numel(win_path) < 3 || win_path(2) ~= ':'
    error('MarinePrior:BadWindowsPath', 'Expected absolute Windows path: %s', win_path);
end
p = ['/mnt/' lower(win_path(1)) strrep(win_path(3:end), '\', '/')];
end

function assert_legacy_gate(gate_path)
if ~isfile(gate_path)
    error('MarinePrior:LegacyGateMissing', 'New candidate requires a passing legacy gate: %s', gate_path);
end
gate = fileread(gate_path);
if ~contains(gate, 'STATUS=PASS')
    error('MarinePrior:LegacyGateFailed', 'New candidate is blocked because legacy reproduction did not pass: %s', gate_path);
end
end

function write_legacy_gate(path, pass, relative_tolerance, absolute_tolerance)
if all(pass)
    status = 'PASS';
else
    status = 'FAIL';
end
write_text(path, sprintf(['STATUS=%s\nRH_COUNT=%d\nRH_PASS_COUNT=%d\n', ...
    'RELATIVE_TOLERANCE=%.12g\nABSOLUTE_TOLERANCE=%.12g\n'], ...
    status, numel(pass), nnz(pass), relative_tolerance, absolute_tolerance));
end

function write_parameter_record(path, marine, label)
T = table([string(label) + "_fine"; string(label) + "_coarse"], ...
    [marine.fine.volume_fraction; marine.coarse.volume_fraction], ...
    [marine.fine.mean_radius_um; marine.coarse.mean_radius_um], ...
    [marine.fine.geometric_std; marine.coarse.geometric_std], ...
    [marine.fine.ri_real; marine.coarse.ri_real], ...
    [marine.fine.ri_imag; marine.coarse.ri_imag], ...
    [marine.fine.kappa; marine.coarse.kappa], ...
    'VariableNames', {'mode','volume_fraction','mean_radius_um','geometric_std', ...
    'ri_real_532nm','ri_imag_532nm','kappa'});
writetable(T, path);
end

function write_manifest(path, phase, marine, candidate_parameter, candidate_extinction, canonical_parameter, canonical_extinction, mopsmap_root)
text = sprintf([ ...
    'producer=rebuild_marine_prior\nphase=%s\n', ...
    'candidate_parameter=%s\ncandidate_extinction=%s\n', ...
    'canonical_parameter=%s\ncanonical_extinction=%s\nmopsmap_root=%s\n', ...
    'wavelength_um=0.532\nsize_support_um=0.05,15\nsize_grid_count=1000\n', ...
    'shape=spheroid/ar_dubovik\n', ...
    'fine=v:%g,r:%g,gsd:%g,mr:%g,mi:%g,kappa:%g\n', ...
    'coarse=v:%g,r:%g,gsd:%g,mr:%g,mi:%g,kappa:%g\n'], ...
    phase, candidate_parameter, candidate_extinction, canonical_parameter, canonical_extinction, mopsmap_root, ...
    marine.fine.volume_fraction, marine.fine.mean_radius_um, marine.fine.geometric_std, ...
    marine.fine.ri_real, marine.fine.ri_imag, marine.fine.kappa, ...
    marine.coarse.volume_fraction, marine.coarse.mean_radius_um, marine.coarse.geometric_std, ...
    marine.coarse.ri_real, marine.coarse.ri_imag, marine.coarse.kappa);
write_text(path, text);
end

function write_text(path, text)
fid = fopen(path, 'w');
assert(fid > 0, 'MarinePrior:WriteFailed', 'Cannot write %s', path);
cleaner = onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', text);
end
