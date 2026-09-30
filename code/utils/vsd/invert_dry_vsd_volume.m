function volume_um3_cm3 = invert_dry_vsd_volume(alpha_ambient_km_inv, rh_percent, component, scale)
%INVERT_DRY_VSD_VOLUME 由环境态消光系数反演干态 VSD 的体积尺度。
% alpha_n(RH) 已包含相对湿度导致的光学增长，因此对所得干谱不再额外
% 施加吸湿修正，以免重复计算。
if any(~isfinite(alpha_ambient_km_inv(:)) | alpha_ambient_km_inv(:)<0) || ...
        any(~isfinite(rh_percent(:)) | rh_percent(:)<0 | rh_percent(:)>99)
    error('VSD:InvalidInput','Invalid extinction or RH.');
end
alpha_n = interp1(component.alpha_normalized(:,1), ...
    component.alpha_normalized(:,2),rh_percent,'linear',NaN);
volume_um3_cm3 = alpha_ambient_km_inv.*scale./alpha_n;
end
