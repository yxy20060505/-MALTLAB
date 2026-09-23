function params = load_params(filename)
%LOAD_PARAMS 从文件加载参数配置
    if nargin < 1 || isempty(filename)
        filename = 'params_config.mat';
    end
    if exist(filename, 'file')
        data = load(filename);
        params = data.params;
        fprintf('参数已从 %s 加载\n', filename);
    else
        fprintf('配置文件不存在，使用默认参数\n');
        params = get_params();
    end
end
