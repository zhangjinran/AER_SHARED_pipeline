function y = nansum(x, dim)
% 这是一个为了替代缺失的内置 nansum 而创建的兼容函数
    
    % 针对本次报错的特殊修复：如果输入是逻辑值 (logical)，强制转为数字 (double)
    if islogical(x)
        x = double(x);
    end

    if nargin == 1
        y = sum(x, 'omitnan');
    else
        y = sum(x, dim, 'omitnan');
    end
end