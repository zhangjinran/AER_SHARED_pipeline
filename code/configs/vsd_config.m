function cfg = vsd_config()
%VSD_CONFIG 干态 VSD 的稳定科学配置；外部路径由调用方提供。
% 参数依据 ESSD 2023 附录表 A1；Marine 亦对应 ACP 2022 表 3。
cfg.components = {'marine','dust','polluted_continental', ...
    'clean_continental','elevated_smoke'};
cfg.prior_fields = {'CM','DU','PC','CC','SM'};
cfg.prior_rows = [1 2 3 4 6]; % 第 5 行为已弃用的污染尘先验。
cfg.depol_nondust = 0.05;
cfg.depol_dust = 0.31;
cfg.lidar_ratio = struct('dust',44,'polluted_continental',70,'marine',23);
% APRO 消光系数单位为 km^-1，MOPSMAP 归一化消光表单位为 Mm^-1。
% 该体积换算系数沿用历史 OMCAM 单位 Gate 的约定，并与 ACP 2022 表 4 对照核验。
cfg.volume_scale_conversion = 1e9;
cfg.spectrum_unit = 'um^3 cm^-3 per dln(r_um)';
cfg.radius_unit = 'um';
cfg.rh_grid = (0:99)';
end
