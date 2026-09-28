function [Nd_dry, Nd_wet] = Calc_Nd_OMCAM(T, Para_Particle, Ext_Norm_Input)
% 计算气溶胶数浓度 (OMCAM算法)
% 改进点：修复了 Para_Particle 结构体的 .data 嵌套层级读取问题

    % =========================================================
    % 1. 解析 Extinction_Normalized 结构体并提取 532nm 数据
    % =========================================================
    if isfield(Ext_Norm_Input, 'Extinction_N')
        EN_struct = Ext_Norm_Input.Extinction_N;
    else
        EN_struct = Ext_Norm_Input;
    end
    
    EN_Matrix = nan(7, 100); 
    try
        if isfield(EN_struct, 'CM'), EN_Matrix(1, :) = EN_struct.CM(:, 1)'; end 
        if isfield(EN_struct, 'DU'), EN_Matrix(2, :) = EN_struct.DU(:, 1)'; end 
        if isfield(EN_struct, 'PC'), EN_Matrix(3, :) = EN_struct.PC(:, 1)'; end 
        if isfield(EN_struct, 'CC'), EN_Matrix(4, :) = EN_struct.CC(:, 1)'; end 
        if isfield(EN_struct, 'PD'), EN_Matrix(5, :) = EN_struct.PD(:, 1)'; end 
        if isfield(EN_struct, 'SM'), EN_Matrix(6, :) = EN_struct.SM(:, 1)'; end 
    catch ME
        error('提取归一化消光系数失败，请确认结构体内各类型矩阵至少包含1列数据。');
    end
    
    % =========================================================
    % 2. 提取并规整化先验参数 (精准匹配 .data 层级)
    % =========================================================
    % 兼容处理：检查是否存在 data 嵌套
    if isfield(Para_Particle, 'data')
        P = Para_Particle.data;
    else
        P = Para_Particle;
    end
    
    v_i_f = P.v_i_fine(:);     r_m_f = P.r_mean_fine(:);     gsd_f = P.GSD_fine(:);
    v_i_c = P.v_i_coarse(:);   r_m_c = P.r_mean_coarse(:);   gsd_c = P.GSD_coarse(:);
    
    % =========================================================
   % =========================================================
    % 3. 读取当前 Chunk 数据并计算吸湿因子
    % =========================================================
    Ext = T.Ext; Back = T.Back; Depol = T.Depol; RH = T.RH; Type = T.Type;
    N_pixels = height(T);
    
    % ★ 核心修复：确保 RH 是 0~1 之间的小数 ★
    if max(RH) > 1.5 
        RH_frac = RH / 100; % 如果是百分比(如60)，转为0.6
    else
        RH_frac = RH;
    end
    
    % 物理限制：相对湿度最高限制在 99%，防止颗粒物无限吸湿膨胀导致算出 Inf
    RH_frac(RH_frac > 0.99) = 0.99; 
    RH_frac(RH_frac < 0.01) = 0.01;
    RH_frac(isnan(RH_frac)) = 0.01;
    
    % RH 查找表索引约束 (1-100)
    Idx_RH = round(RH_frac * 100);
    Idx_RH(Idx_RH > 100) = 100;
    Idx_RH(Idx_RH < 1) = 1;
    
    % 吸湿因子计算
    Kappa = zeros(N_pixels, 1);
    Kappa(Type == 3 | Type == 4 | Type == 6) = 0.3; % 大陆型/烟尘
    Kappa(Type == 1 | Type == 7) = 0.7;             % 海洋型
    
    % 使用小数形式的 RH_frac 进行计算，彻底杜绝复数和 Inf
    f_RH = (1 + Kappa .* RH_frac ./ (1 - RH_frac)).^(1/3);
    % ========================================================
    % 4. 向量化计算体积缩放因子 Vt 和 Vt_ND 
    % ========================================================
    Vt = zeros(N_pixels, 1);
    Vt_ND = zeros(N_pixels, 1);
    typ_f = Type; 
    
    is_du = (Type == 2);
    is_mix = (Type == 5 | Type == 7);
    is_pure_nd = ~(is_du | is_mix | isnan(Type) | Type < 1 | Type > 7);
    
    % A. 纯沙尘
    if any(is_du)
        val = EN_Matrix(2, Idx_RH(is_du));
        Vt(is_du) = (Ext(is_du) ./ val(:)) .* 1e6;
        typ_f(is_du) = 2;
    end
    
    % B. 纯非沙尘
    if any(is_pure_nd)
        idx_nd = sub2ind(size(EN_Matrix), Type(is_pure_nd), Idx_RH(is_pure_nd));
        val = EN_Matrix(idx_nd);
        Vt_ND(is_pure_nd) = (Ext(is_pure_nd) ./ val(:)) .* 1e6;
    end
    
    % C. 混合型 (Polluted Dust=5, Dusty Marine=7)
    if any(is_mix)
        typ_nd_mix = 3 * (Type(is_mix) == 5) + 1 * (Type(is_mix) == 7); 
        idx_nd_mix = sub2ind(size(EN_Matrix), typ_nd_mix, Idx_RH(is_mix));
        
        Ext_Norm_ND = EN_Matrix(idx_nd_mix); Ext_Norm_ND = Ext_Norm_ND(:);
        Ext_Norm_DU = EN_Matrix(2, Idx_RH(is_mix)); Ext_Norm_DU = Ext_Norm_DU(:);
        
        f_dust = (Depol(is_mix) - 0.05) * 1.31 ./ (0.26 .* (1 + Depol(is_mix)));
        f_dust = max(0, min(1, f_dust)); 
        
        LR_nd = 70 * (Type(is_mix) == 5) + 23 * (Type(is_mix) == 7);
        LR_du = 44;
        
        Vt_ND(is_mix) = LR_nd .* Back(is_mix) .* (1 - f_dust) ./ Ext_Norm_ND .* 1e6;
        Vt(is_mix)    = LR_du .* Back(is_mix) .* f_dust       ./ Ext_Norm_DU .* 1e6;
        typ_f(is_mix) = typ_nd_mix;
    end
    
    % ========================================================
    % 5. 向量化调用 numerical integral (通过 arrayfun 实现)
    % ========================================================
    % 将类型数组提取为对应的微物理参数数组
    vi_f_nd = v_i_f(typ_f);  rm_f_nd = r_m_f(typ_f);  gsd_f_nd = gsd_f(typ_f);
    vi_c_nd = v_i_c(typ_f);  rm_c_nd = r_m_c(typ_f);  gsd_c_nd = gsd_c(typ_f);
    
    vi_f_du = v_i_f(2); rm_f_du = r_m_f(2); gsd_f_du = gsd_f(2);
    vi_c_du = v_i_c(2); rm_c_du = r_m_c(2); gsd_c_du = gsd_c(2);
    
    % --- 沙尘计算 (沙尘疏水，Dry & Wet 使用相同的中值半径) ---
    Nd_du_f = calc_N_using_integral(Vt, vi_f_du, rm_f_du, gsd_f_du, 0.1, 15);
    Nd_du_c = calc_N_using_integral(Vt, vi_c_du, rm_c_du, gsd_c_du, 0.1, 15);
    Nd_du = Nd_du_f + Nd_du_c;
    
    % --- 非沙尘计算 (Dry) ---
    Nd_nd_dry_f = calc_N_using_integral(Vt_ND, vi_f_nd, rm_f_nd, gsd_f_nd, 0.05, 15);
    Nd_nd_dry_c = calc_N_using_integral(Vt_ND, vi_c_nd, rm_c_nd, gsd_c_nd, 0.05, 15);
    Nd_nd_dry = Nd_nd_dry_f + Nd_nd_dry_c;
    
    % --- 非沙尘计算 (Wet，中值半径按 f_RH 增长) ---
    Nd_nd_wet_f = calc_N_using_integral(Vt_ND, vi_f_nd, rm_f_nd .* f_RH, gsd_f_nd, 0.05, 15);
    Nd_nd_wet_c = calc_N_using_integral(Vt_ND, vi_c_nd, rm_c_nd .* f_RH, gsd_c_nd, 0.05, 15);
    Nd_nd_wet = Nd_nd_wet_f + Nd_nd_wet_c;
    
    % 最终总数浓度
    Nd_dry = Nd_du + Nd_nd_dry;
    Nd_wet = Nd_du + Nd_nd_wet;
    
    % 异常值赋空
    invalid_mask = (Type < 1 | Type > 7 | isnan(Type));
    Nd_dry(invalid_mask) = NaN;
    Nd_wet(invalid_mask) = NaN;
end

% ==========================================================
% 局部辅助函数：结合 arrayfun 和 integral 实现无循环数值积分
% ==========================================================
% ==========================================================
% 局部辅助函数：结合 arrayfun 和 integral 实现无循环数值积分
% ==========================================================
% ==========================================================
% 局部辅助函数：基于高密度对数网格的矩阵化梯形数值积分 (极速版)
% ==========================================================
% ==========================================================
% 局部辅助函数：基于高密度对数网格的矩阵化梯形数值积分 (极速版)
% ==========================================================
function N_out = calc_N_using_integral(Vt, v_i, rm, gsd, r_min, r_max)
    % 预分配输出
    N_out = zeros(size(Vt));
    
    % 只对有效且大于 0 的体积因子进行积分
    valid = (Vt > 0) & isfinite(Vt);
    if ~any(valid)
        return; 
    end
    
    % 提取有效像元 (列向量 Nx1)
    v_Vt  = Vt(valid);
    n_valid = sum(valid);
    
    % 兼容标量输入
    if isscalar(v_i), v_vi = repmat(v_i, n_valid, 1); else, v_vi = v_i(valid); end
    if isscalar(rm),  v_rm = repmat(rm, n_valid, 1);  else, v_rm = rm(valid);  end
    if isscalar(gsd), v_gsd= repmat(gsd, n_valid, 1); else, v_gsd= gsd(valid); end
    
    % ===================================================
    % 核心提速：构建固定对数网格与矩阵运算
    % ===================================================
    num_pts = 500;
    r_grid = logspace(log10(r_min), log10(r_max), num_pts);
    log_r_grid = log(r_grid);
    
    % ★ 分批处理，防止中间矩阵（N_valid × 500）撑爆内存 ★
    % 每批最多处理 200,000 个像元 → 200K × 500 × 8B ≈ 800 MB
    BATCH_SIZE = 200000;
    N_valid = zeros(n_valid, 1);
    
    for batch_start = 1:BATCH_SIZE:n_valid
        batch_end = min(batch_start + BATCH_SIZE - 1, n_valid);
        batch_idx = batch_start:batch_end;
        n_batch = length(batch_idx);
        
        % ★ 更名与概念澄清：这里算出来的其实是 dN/dlnr 
        dN_dlnr = v_Vt(batch_idx) .* (3 ./ (4 * pi * r_grid.^3)) .* ...
                  (v_vi(batch_idx) ./ (sqrt(2 * pi) * log(v_gsd(batch_idx)))) .* ...
                  exp(-(log_r_grid - log(v_rm(batch_idx))).^2 ./ (2 * log(v_gsd(batch_idx)).^2));
                
        % ★★★ 惊天修复：使用 trapz 积分时，X轴必须是对数 log(r_grid)！★★★
        N_valid(batch_idx) = trapz(log_r_grid, dN_dlnr, 2);
    end
    
    N_out(valid) = N_valid;
end