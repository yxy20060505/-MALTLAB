function save_params(params, filename)
%SAVE_PARAMS 保存参数配置到文件
    if nargin < 2 || isempty(filename)
         % nargin：传入实参个数；<2表示filename未传
         % isempty：为空或[]也走默认
        filename = 'params_config.mat';
    end
    save(filename, 'params');
    fprintf('参数已保存到: %s\n', filename);
end
