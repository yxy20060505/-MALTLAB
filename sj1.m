%% 基于MATLAB的车牌识别系统 - 主入口
% 信息处理系统综合设计
% 支持蓝牌（7字符）和绿牌（8字符）
% 运行方式：在MATLAB中输入 sj1

clear; clc;
fprintf('========================================\n');
fprintf('  基于MATLAB的车牌识别系统\n');
fprintf('  支持蓝牌(7字符) / 绿牌(8字符)\n');
fprintf('========================================\n');

% 检查模板库
template_dir = fullfile(fileparts(mfilename('fullpath')), 'templates');
if exist(template_dir, 'dir')
    template_count = length(dir(fullfile(template_dir, '*.jpg')));
    fprintf('[初始化] 模板库已就绪 (%d个模板)\n', template_count);
else
    fprintf('[警告] 模板库不存在\n');
end

% 启动GUI
fprintf('[启动] 正在打开图形界面...\n');
gui_main;
