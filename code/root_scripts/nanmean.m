function y = nanmean(x, dim)
% 这是一个为了替代缺失的内置 nanmean 而创建的兼容函数
    if nargin == 1
        y = mean(x, 'omitnan');
    else
        y = mean(x, dim, 'omitnan');
    end
end