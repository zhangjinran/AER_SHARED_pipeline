function prior = load_vsd_priors(parameter_file, extinction_file, cfg)
%LOAD_VSD_PRIORS 读取并校验五个纯组分的参数先验和 RH 消光表。
% 输入均为显式路径，此函数不依赖历史管线的固定路径。
p = load(parameter_file,'data');
e = load(extinction_file,'Extinction_N');
if ~isfield(p,'data') || ~isfield(e,'Extinction_N')
    error('VSD:PriorSchema','Missing data or Extinction_N variable.');
end
names = {'v_i_fine','v_i_coarse','r_mean_fine','r_mean_coarse', ...
    'GSD_fine','GSD_coarse','m_r_fine','m_r_coarse','m_i_fine','m_i_coarse'};
for j=1:numel(names)
    if ~isfield(p.data,names{j}) || numel(p.data.(names{j}))<6
        error('VSD:PriorSchema','Missing/short parameter %s.',names{j});
    end
end
prior = struct();
for i=1:numel(cfg.components)
    name = cfg.components{i}; row = cfg.prior_rows(i);
    c = struct('volume_fraction',[p.data.v_i_fine(row) p.data.v_i_coarse(row)], ...
        'mean_radius_um',[p.data.r_mean_fine(row) p.data.r_mean_coarse(row)], ...
        'geometric_std',[p.data.GSD_fine(row) p.data.GSD_coarse(row)], ...
        'ri_real',[p.data.m_r_fine(row) p.data.m_r_coarse(row)], ...
        'ri_imag',[p.data.m_i_fine(row) p.data.m_i_coarse(row)]);
    tab = double(e.Extinction_N.(cfg.prior_fields{i}));
    if ~isequal(size(tab),[100 2]) || ~isequal(tab(:,1),cfg.rh_grid) || ...
            any(~isfinite(tab(:,2))) || any(tab(:,2)<=0)
        error('VSD:PriorSchema','Invalid RH extinction table for %s.',name);
    end
    if abs(sum(c.volume_fraction)-1)>1e-10 || ...
            any(c.mean_radius_um<=0) || any(c.geometric_std<=1)
        error('VSD:PriorSchema','Invalid bimodal parameters for %s.',name);
    end
    c.alpha_normalized = tab;
    prior.(name) = c;
end
end
