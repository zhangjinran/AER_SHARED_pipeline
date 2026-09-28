function [beta_dust, beta_nondust, regime] = split_mixed_dust(backscatter, depol, cfg)
%SPLIT_MIXED_DUST Split Type 5/7 backscatter into dust/non-dust components.

if nargin < 3 || isempty(cfg)
    cfg = ccn_v2_config();
end
if ~isequal(size(backscatter), size(depol))
    error('CCNv2:ShapeMismatch', 'backscatter and depol must have identical sizes.');
end
if any(~isfinite(backscatter(:)) | backscatter(:) < 0)
    error('CCNv2:InvalidBackscatter', 'backscatter must be finite and non-negative.');
end
if any(~isfinite(depol(:)))
    error('CCNv2:InvalidDepol', 'depol must be finite for mixed aerosol types.');
end

beta_dust = zeros(size(backscatter));
regime = zeros(size(backscatter), 'uint8'); % 1 non-dust, 2 mixed, 3 dust

is_nondust = depol < cfg.depol_nondust;
is_dust = depol > cfg.depol_dust;
is_mixed = ~(is_nondust | is_dust);

beta_dust(is_dust) = backscatter(is_dust);
beta_dust(is_mixed) = backscatter(is_mixed) .* ...
    ((depol(is_mixed) - cfg.depol_nondust) .* (1 + cfg.depol_dust)) ./ ...
    ((cfg.depol_dust - cfg.depol_nondust) .* (1 + depol(is_mixed)));
beta_dust = min(max(beta_dust, 0), backscatter);
beta_nondust = max(backscatter - beta_dust, 0);

regime(is_nondust) = 1;
regime(is_mixed) = 2;
regime(is_dust) = 3;
end
