function [q, vsd] = evaluate_dry_vsd(component, radius_um, volume_um3_cm3)
%EVALUATE_DRY_VSD 在以 µm 为单位的半径轴上计算归一化及实际干态 dV/dln(r)。
% 参数式产品只保存体积尺度和组分身份，不为每个 APRO bin 保存密集半径向量。
% 本函数供数值 Gate 和绘图时展开粒径谱。
r = double(radius_um);
if any(~isfinite(r(:)) | r(:)<=0) || ...
        ~isscalar(volume_um3_cm3) || ~isfinite(volume_um3_cm3) || volume_um3_cm3<0
    error('VSD:InvalidInput','Radius and volume must be finite/nonnegative.');
end
q = zeros(size(r));
for k=1:2
    s=log(component.geometric_std(k));
    q=q+component.volume_fraction(k)/(sqrt(2*pi)*s).* ...
        exp(-0.5*(log(r/component.mean_radius_um(k))/s).^2);
end
vsd=volume_um3_cm3.*q;
end
