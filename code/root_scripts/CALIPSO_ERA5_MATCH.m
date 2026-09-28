clc; clear;
addpath('F:\AER_RETRA_CASE\函数');
%% ===================== 路径与配置 ==========================
calipso_dir    = 'F:\AER_RETRA_CASE\CALISPO_data\APro';  
ERA5_DIR       = './ERA5_CACHE'; 
files = dir(fullfile(calipso_dir, 'CAL_LID_L2_05kmAPro*')); 
if isempty(files)
    files = dir(fullfile(calipso_dir, '*.hdf')); 
end
file_num = length(files);
batch_size = 100; 
meta = get_ERA5_meta(ERA5_DIR);
fprintf('============================================================\n');
fprintf('🚜 终极一维推土机引擎启动：总计文件数 %d，每批次 %d 个\n', file_num, batch_size);
fprintf('============================================================\n\n');
%% ===================== 主循环 =============================
for b = 1:ceil(file_num/batch_size)
    
    out_csv = sprintf('./CALIPSO_results_Batch_%d.csv', b);
    start_idx = (b-1)*batch_size + 1;
    end_idx   = min(b*batch_size, file_num);
    
    if isfile(out_csv)
        fprintf('>>> [已跳过] 批次 %d\n', b);
        continue;
    end
    
    batch_data = cell(end_idx - start_idx + 1, 1); 
    for i = start_idx:end_idx
        file_name = files(i).name;
        file_path = fullfile(calipso_dir, file_name);
        fprintf('------------------------------------------------------------\n');
        fprintf('【当前进度: 第 %d 个文件 / 共 %d 个】\n', i, file_num);
        fprintf('文件名: %s\n', file_name);
        try
            %% 1. 读取基础光学参数、分类掩膜 与 ★温度数据
            Ext_raw   = double(hdfread(file_path, '/Extinction_Coefficient_532'));
            Back_raw  = double(hdfread(file_path, '/Total_Backscatter_Coefficient_532'));
            Depol_raw = double(hdfread(file_path, '/Particulate_Depolarization_Ratio_Profile_532'));
            AVD_raw   = uint16(hdfread(file_path, '/Atmospheric_Volume_Description'));
            Temp_raw  = double(hdfread(file_path, '/Temperature')); % ★ 新增：读取温度
            
            % 取出第一层切片，强制消除第三维
            Ext = Ext_raw(:,:,1); Back = Back_raw(:,:,1); Depol = Depol_raw(:,:,1); AVD = AVD_raw(:,:,1);
            Temp = Temp_raw(:,:,1); % ★ 新增
            
            % 规范方向：确保高度层 (399) 在第二维 (列)
            if size(Ext, 1) == 399, Ext = Ext'; end
            if size(Back, 1) == 399, Back = Back'; end
            if size(Depol, 1) == 399, Depol = Depol'; end
            if size(AVD, 1) == 399, AVD = AVD'; end
            if size(Temp, 1) == 399, Temp = Temp'; end %  新增
            
            N_prof = size(Ext, 1);
            N_bin  = 399;
            total_elements = N_prof * N_bin; % 预期的一维总长度
            
            %% 2. 强行拍扁为 1D 列向量 (Bulldozer!)
            ext_1d   = reshape(Ext, [], 1);
            back_1d  = reshape(Back, [], 1);
            depol_1d = reshape(Depol, [], 1);
            avd_1d   = reshape(AVD, [], 1);
            temp_1d  = reshape(Temp, [], 1); % 新增
            
            % 裁剪多余部分，确保所有向量长度绝对一致
            ext_1d   = ext_1d(1:total_elements);
            back_1d  = back_1d(1:total_elements);
            depol_1d = depol_1d(1:total_elements);
            avd_1d   = avd_1d(1:total_elements);
            temp_1d  = temp_1d(1:total_elements); % 新增
            
            %% 3. 读取一维坐标与时间并彻底抹平
            Lon_raw = double(hdfread(file_path, '/Longitude'));
            Lat_raw = double(hdfread(file_path, '/Latitude'));
            Time_raw = double(hdfread(file_path, '/Profile_Time'));
            
            % 如果读出来的是 N x 3 (包含起始、中心、结束点)，取中心点
            if numel(Lon_raw) >= N_prof * 3
                Lon = reshape(Lon_raw(1:N_prof*3), 3, N_prof)'; Lon = Lon(:, 2);
                Lat = reshape(Lat_raw(1:N_prof*3), 3, N_prof)'; Lat = Lat(:, 2);
                Time_vec = reshape(Time_raw(1:N_prof*3), 3, N_prof)'; Time_vec = Time_vec(:, 2);
            else
                Lon = Lon_raw(:); Lat = Lat_raw(:); Time_vec = Time_raw(:);
            end
            
            % 裁剪并转换时间
            Lon = Lon(1:N_prof); Lat = Lat(1:N_prof); Time_vec = Time_vec(1:N_prof);
            utc_dn_prof = Time_vec / 86400 + datenum(1993, 1, 1); 
            
            %% 4. 生成 2D 扩充矩阵并拍扁成 1D
            metadata = hdfread(file_path, '/metadata', 'Fields', 'Lidar_Data_Altitudes');
            alt_axis = double(metadata{1});
            
            Lon_Mat  = repmat(Lon(:), 1, N_bin);
            Lat_Mat  = repmat(Lat(:), 1, N_bin);
            Time_Mat = repmat(utc_dn_prof(:), 1, N_bin);
            Alt_Mat  = repmat(alt_axis(:)', N_prof, 1);
            Prof_Mat = repmat((1:N_prof)', 1, N_bin); % 追踪原始的廓线 ID
            
            lon_1d  = reshape(Lon_Mat, [], 1);  lon_1d  = lon_1d(1:total_elements);
            lat_1d  = reshape(Lat_Mat, [], 1);  lat_1d  = lat_1d(1:total_elements);
            time_1d = reshape(Time_Mat, [], 1); time_1d = time_1d(1:total_elements);
            alt_1d  = reshape(Alt_Mat, [], 1);  alt_1d  = alt_1d(1:total_elements);
            prof_1d = reshape(Prof_Mat, [], 1); prof_1d = prof_1d(1:total_elements);
            
            %% 5. 气溶胶分类位运算 (直接在 1D 上进行)
            Feature_Type_1d = bitand(avd_1d, uint16(7)); 
            type_1d = bitand(bitshift(avd_1d, -9), uint16(7)); 
            type_1d(Feature_Type_1d ~= 3) = 0; % 非气溶胶置 0
            type_1d = double(type_1d);
            
            %% 6. 创建 1D 逻辑索引
            % 现在所有的变量全都是一根长度为 total_elements 的线，绝不越界！
            valid_mask = (type_1d > 0) & (ext_1d > 0) & (back_1d > 0) & (depol_1d >= 0) & ...
                         isfinite(ext_1d) & isfinite(back_1d) & isfinite(depol_1d);
            if ~any(valid_mask)
                error('该文件完全无有效气溶胶，或为纯云/纯晴空轨道。'); 
            end
            N_valid = sum(valid_mask);
            
            %% 7. 安全提取向量 (百分百无错)
            ext_v   = ext_1d(valid_mask); 
            back_v  = back_1d(valid_mask); 
            type_v  = type_1d(valid_mask);
            depol_v = depol_1d(valid_mask); 
            temp_v  = temp_1d(valid_mask); % ★ 新增：提取有效温度
            lr_v    = ext_v ./ back_v;  
            
            h_v     = alt_1d(valid_mask); 
            lon_v   = lon_1d(valid_mask); 
            lat_v   = lat_1d(valid_mask);
            utc_v   = time_1d(valid_mask); 
            prof_idx= prof_1d(valid_mask);
            if contains(file_name, 'ZN') || contains(file_name, 'Night')
                daynight_flag = "Night"; else, daynight_flag = "Day";
            end
            
            %% 8. ERA5 空间插值 
            RH_v = NaN(N_valid, 1);
            t_match_idx = round(interp1(datenum(meta.time), 1:numel(meta.time), utc_v, 'nearest', 'extrap'));
            unique_ts = unique(t_match_idx);
            
            for ut = unique_ts'
                era_f = fullfile(ERA5_DIR, sprintf('ERA5_%s.mat', datestr(meta.time(ut),'yyyymmdd_HH')));
                if isfile(era_f)
                    E = load(era_f, 'ERA5');
                    curr_pts = find(t_match_idx == ut);
                    for ii = 1:numel(curr_pts)
                        idx = curr_pts(ii);
                        lon_ix = min(max(round(mod(lon_v(idx),360)/meta.dlon)+1, 1), numel(meta.lon));
                        lat_ix = min(max(round((90-lat_v(idx))/meta.dlat)+1, 1), numel(meta.lat));
                        h_p = squeeze(E.ERA5.height(lon_ix, lat_ix, :));
                        r_p = squeeze(E.ERA5.RH(lon_ix, lat_ix, :));
                        if ~any(isnan(h_p))
                            RH_v(idx) = interp1(h_p, r_p, h_v(idx)*1000, 'linear', NaN);
                        end
                    end
                end
            end
            
            %% 9. 存储表格 (将 Temp 加入输出列)
            % ★ 新增了 temp_v 变量，并在 VariableNames 里增加了 'Temp'
            batch_data{i-start_idx+1} = table(repmat({file_name}, N_valid, 1), repmat(daynight_flag, N_valid, 1), ...
                prof_idx, h_v, type_v, ext_v, back_v, lr_v, depol_v, temp_v, lon_v, lat_v, RH_v, ...
                cellstr(datestr(utc_v)), utc_v, ...
                'VariableNames', {'FileName','DayNight','RayID','Height','Type','Ext','Back','LR','Depol','Temp','Lon','Lat','RH','UTC','DN'});
            fprintf('    * 提取成功，收获 %d 个优质气溶胶像元！\n', N_valid);
        catch ME
            fprintf('    ! 处理跳过: %s\n', ME.message);
        end
    end
    
    %% 10. 保存批次
    final_table = vertcat(batch_data{:});
    if ~isempty(final_table)
        writetable(final_table, out_csv);
        fprintf('\n>>> [批次 %d 已存档] 文件位置: %s\n\n', b, out_csv);
    end
    clear batch_data final_table; 
end
fprintf('\n======= CALIPSO 任务全部结束！共处理 %d 个文件 =======\n', file_num);