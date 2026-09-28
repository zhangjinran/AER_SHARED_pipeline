function alpha_n = lookup_normalized_extinction(prior_table, rh_percent)
%LOOKUP_NORMALIZED_EXTINCTION Interpolate column-2 extinction by column-1 RH.

if ~isnumeric(prior_table) || size(prior_table,2) < 2
    error('CCNv2:BadPriorTable', 'Prior table must contain RH and extinction columns.');
end
rh_axis = double(prior_table(:,1));
ext_axis = double(prior_table(:,2));
if any(~isfinite(rh_axis)) || any(~isfinite(ext_axis)) || any(ext_axis <= 0)
    error('CCNv2:BadPriorTable', 'RH/extinction columns must be finite and extinction positive.');
end
[rh_axis, order] = sort(rh_axis);
ext_axis = ext_axis(order);
if any(diff(rh_axis) <= 0)
    error('CCNv2:BadPriorTable', 'RH coordinates must be unique and strictly increasing.');
end

alpha_n = nan(size(rh_percent));
if numel(rh_axis) == 1
    alpha_n(isfinite(rh_percent) & double(rh_percent) == rh_axis) = ext_axis;
    return
end
valid = isfinite(rh_percent) & rh_percent >= rh_axis(1) & rh_percent <= rh_axis(end);
alpha_n(valid) = interp1(rh_axis, ext_axis, double(rh_percent(valid)), 'linear');
end
