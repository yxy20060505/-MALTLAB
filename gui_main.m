function gui_main()
%GUI_MAIN 车牌识别系统GUI界面
%   三栏布局：左侧控制面板+参数滑块，中间6步处理结果，右侧识别结果+8字符分块+日志
%   滑块采用200ms防抖定时器，拖动丝滑不卡顿

    %% 创建窗口
    fig = figure('Name', '基于MATLAB的车牌识别系统', ...
        'NumberTitle', 'off', ...
        'Position', [80 40 1280 800], ...
        'Color', [0.94 0.94 0.94], ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Resize', 'off', ...
        'CloseRequestFcn', @onClose);

    %% 防抖定时器（滑块拖动结束200ms后才触发识别）
    debounceTimer = timer('ExecutionMode', 'singleShot', ...
        'StartDelay', 0.2, ...
        'TimerFcn', @(~,~) onRecognize());

    %% 顶部标题栏
    uipanel(fig, 'Position', [0 0.95 1 0.05], ...
        'BackgroundColor', [0.15 0.35 0.65], ...
        'BorderType', 'none');
    uicontrol(fig, 'Style', 'text', ...
        'Position', [0 0.952 1 0.046], ...
        'String', '基于MATLAB的车牌识别系统（蓝牌7字符 / 绿牌8字符）', ...
        'FontSize', 15, 'FontWeight', 'bold', ...
        'ForegroundColor', 'w', 'BackgroundColor', [0.15 0.35 0.65], ...
        'HorizontalAlignment', 'center');

    %% 左侧控制面板 + 参数调节
    ctrlPanel = uipanel(fig, 'Position', [0.01 0.02 0.17 0.91], ...
        'BackgroundColor', [0.97 0.97 0.97], ...
        'Title', '控制面板', 'FontSize', 11, 'FontWeight', 'bold');

    % 功能按钮
    uicontrol(ctrlPanel, 'Style', 'pushbutton', ...
        'Position', [12 650 155 42], ...
        'String', '加载图像', 'FontSize', 12, ...
        'Callback', @onLoad);
    uicontrol(ctrlPanel, 'Style', 'pushbutton', ...
        'Position', [12 590 155 42], ...
        'String', '开始识别', 'FontSize', 12, ...
        'Callback', @onRecognize);
    uicontrol(ctrlPanel, 'Style', 'pushbutton', ...
        'Position', [12 530 155 42], ...
        'String', '重置', 'FontSize', 12, ...
        'Callback', @onReset);
    uicontrol(ctrlPanel, 'Style', 'pushbutton', ...
        'Position', [12 470 155 42], ...
        'String', '退出', 'FontSize', 12, ...
        'Callback', @onClose);

    

    % 边缘阈值
    uicontrol(ctrlPanel, 'Style', 'text', ...
        'Position', [10 405 95 18], 'String', '边缘阈值:', ...
        'FontSize', 9, 'HorizontalAlignment', 'left');
    edgeValLabel = uicontrol(ctrlPanel, 'Style', 'text', ...
        'Position', [105 405 60 18], 'String', '0.18', ...
        'FontSize', 9, 'HorizontalAlignment', 'right');
    edgeSlider = uicontrol(ctrlPanel, 'Style', 'slider', ...
        'Position', [10 387 160 18], ...
        'Min', 0.05, 'Max', 0.40, 'Value', 0.18, ...
        'Callback', @onSliderChange);

    % 形态学大小
    uicontrol(ctrlPanel, 'Style', 'text', ...
        'Position', [10 362 95 18], 'String', '形态学大小:', ...
        'FontSize', 9, 'HorizontalAlignment', 'left');
    morphValLabel = uicontrol(ctrlPanel, 'Style', 'text', ...
        'Position', [105 362 60 18], 'String', '25', ...
        'FontSize', 9, 'HorizontalAlignment', 'right');
    morphSlider = uicontrol(ctrlPanel, 'Style', 'slider', ...
        'Position', [10 344 160 18], ...
        'Min', 10, 'Max', 60, 'Value', 25, ...
        'Callback', @onSliderChange);

    % 分割阈值系数
    uicontrol(ctrlPanel, 'Style', 'text', ...
        'Position', [10 319 95 18], 'String', '分割阈值系数:', ...
        'FontSize', 9, 'HorizontalAlignment', 'left');
    splitValLabel = uicontrol(ctrlPanel, 'Style', 'text', ...
        'Position', [105 319 60 18], 'String', '0.50', ...
        'FontSize', 9, 'HorizontalAlignment', 'right');
    splitSlider = uicontrol(ctrlPanel, 'Style', 'slider', ...
        'Position', [10 301 160 18], ...
        'Min', 0.2, 'Max', 0.8, 'Value', 0.5, ...
        'Callback', @onSliderChange);

    % 二值化偏移
    uicontrol(ctrlPanel, 'Style', 'text', ...
        'Position', [10 276 95 18], 'String', '二值化偏移:', ...
        'FontSize', 9, 'HorizontalAlignment', 'left');
    binaryValLabel = uicontrol(ctrlPanel, 'Style', 'text', ...
        'Position', [105 276 60 18], 'String', '0', ...
        'FontSize', 9, 'HorizontalAlignment', 'right');
    binarySlider = uicontrol(ctrlPanel, 'Style', 'slider', ...
        'Position', [10 258 160 18], ...
        'Min', -50, 'Max', 50, 'Value', 0, ...
        'Callback', @onSliderChange);

    % 参数保存按钮
    uicontrol(ctrlPanel, 'Style', 'pushbutton', ...
        'Position', [10 215 75 28], 'String', '保存参数', ...
        'FontSize', 9, 'Callback', @onSaveParams);
    uicontrol(ctrlPanel, 'Style', 'pushbutton', ...
        'Position', [90 215 75 28], 'String', '加载参数', ...
        'FontSize', 9, 'Callback', @onLoadParams);
    uicontrol(ctrlPanel, 'Style', 'pushbutton', ...
        'Position', [10 182 155 28], 'String', '恢复默认参数', ...
        'FontSize', 9, 'Callback', @onResetParams);

    % 状态显示
    uicontrol(ctrlPanel, 'Style', 'text', ...
        'Position', [10 135 160 20], 'String', '系统状态:', ...
        'FontSize', 10, 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
    statusLabel = uicontrol(ctrlPanel, 'Style', 'text', ...
        'Position', [10 110 160 25], 'String', '就绪', ...
        'FontSize', 10, 'ForegroundColor', [0 0.5 0], ...
        'HorizontalAlignment', 'left');

    %% 中间：处理过程（2行3列）
    midPanel = uipanel(fig, 'Position', [0.19 0.02 0.49 0.91], ...
        'BackgroundColor', [0.97 0.97 0.97], ...
        'Title', '处理过程', 'FontSize', 11, 'FontWeight', 'bold');

    titles = {'原始图像', '灰度图像', '边缘图像', ...
              '车牌定位', '二值化', '字符分割'};
    ax = gobjects(1, 6);
    positions = [0.04 0.52 0.28 0.40;  0.36 0.52 0.28 0.40;  0.68 0.52 0.28 0.40;
                 0.04 0.06 0.28 0.40;  0.36 0.06 0.28 0.40;  0.68 0.06 0.28 0.40];
    for k = 1:6
        ax(k) = axes('Parent', midPanel, 'Position', positions(k, :));
        title(ax(k), titles{k}, 'FontSize', 10, 'FontWeight', 'bold');
        axis(ax(k), 'off');
    end

    %% 右侧：识别结果 + 8字符分块 + 日志
    rightPanel = uipanel(fig, 'Position', [0.69 0.02 0.30 0.91], ...
        'BackgroundColor', [0.97 0.97 0.97], ...
        'Title', '识别结果', 'FontSize', 11, 'FontWeight', 'bold');

    % 识别结果
    uicontrol(rightPanel, 'Style', 'text', ...
        'Position', [10 680 100 25], 'String', '车牌号:', ...
        'FontSize', 11, 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
    resultLabel = uicontrol(rightPanel, 'Style', 'text', ...
        'Position', [10 650 340 30], 'String', '----------', ...
        'FontSize', 18, 'FontWeight', 'bold', ...
        'ForegroundColor', [0.8 0 0], 'HorizontalAlignment', 'left');

    % 8字符分块显示
    uicontrol(rightPanel, 'Style', 'text', ...
        'Position', [10 610 200 20], 'String', '分割字符分块显示:', ...
        'FontSize', 10, 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
    charAx = gobjects(1, 8);
    charW = 38; charH = 60; charGap = 3;
    for k = 1:8
        x_pos = 10 + (k-1) * (charW + charGap);
        charAx(k) = axes('Parent', rightPanel, ...
            'Position', [x_pos/360 0.66 charW/360 charH/720]);
        axis(charAx(k), 'off');
    end

    % 日志区域
    uicontrol(rightPanel, 'Style', 'text', ...
        'Position', [10 430 100 20], 'String', '运行日志:', ...
        'FontSize', 10, 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
    logArea = uicontrol(rightPanel, 'Style', 'listbox', ...
        'Position', [10 30 340 390], ...
        'String', {'系统就绪'}, ...
        'FontSize', 9, 'BackgroundColor', 'w', ...
        'HorizontalAlignment', 'left');

    %% 应用数据
    appData = struct('I', [], 'ax', ax, 'charAx', charAx, ...
        'resultLabel', resultLabel, 'statusLabel', statusLabel, ...
        'logArea', logArea, 'titles', {titles}, ...
        'edgeSlider', edgeSlider, 'morphSlider', morphSlider, ...
        'splitSlider', splitSlider, 'binarySlider', binarySlider, ...
        'edgeValLabel', edgeValLabel, 'morphValLabel', morphValLabel, ...
        'splitValLabel', splitValLabel, 'binaryValLabel', binaryValLabel, ...
        'isRecognizing', false, 'debounceTimer', debounceTimer);
    guidata(fig, appData);

    %% 回调函数
    function onLoad(~, ~)
        [filename, pathname] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp', '图像文件'}, '选择车辆图像');
        if isequal(filename, 0), return; end
        I = imread(fullfile(pathname, filename));
        appData.I = I;
        guidata(fig, appData);
        imshow(I, 'Parent', ax(1));
        title(ax(1), '原始图像', 'FontSize', 10, 'FontWeight', 'bold');
        appendLog('加载图像: %s', filename);
        set(statusLabel, 'String', '图像已加载');
        % 加载后不自动识别，需手动点击开始识别
    end

    function onSliderChange(~, ~)
        % 只更新数值标签，不立即识别（防抖）
        set(edgeValLabel, 'String', sprintf('%.2f', get(edgeSlider, 'Value')));
        set(morphValLabel, 'String', sprintf('%d', round(get(morphSlider, 'Value'))));
        set(splitValLabel, 'String', sprintf('%.2f', get(splitSlider, 'Value')));
        set(binaryValLabel, 'String', sprintf('%d', round(get(binarySlider, 'Value'))));
        % 重置防抖定时器：停止→启动，200ms无操作后才识别
        if strcmp(get(debounceTimer, 'Running'), 'on')
            stop(debounceTimer);
        end
        if ~isempty(appData.I)
            start(debounceTimer);
        end
    end

    function onRecognize(~, ~)
        if isempty(appData.I)
            appendLog('请先加载图像');
            return;
        end
        if appData.isRecognizing, return; end
        appData.isRecognizing = true;
        guidata(fig, appData);
        try
            set(statusLabel, 'String', '识别中...');
            drawnow;

            I = appData.I;
            % 从滑块读取参数
            params = get_params();
            params.edge_threshold = get(edgeSlider, 'Value');
            params.morph_size = round(get(morphSlider, 'Value'));
            params.blue.split_thresh_factor = get(splitSlider, 'Value');
            params.green.split_thresh_factor = get(splitSlider, 'Value');
            params.blue.binary_offset = round(get(binarySlider, 'Value'));
            params.green.binary_offset = round(get(binarySlider, 'Value'));

            [result, plate_img, chars, I_gray, I_edge, plate_color, I_bin] = recognize_plate(I, params);

            % 显示各步结果
            imshow(I_gray, 'Parent', ax(2));
            title(ax(2), '灰度图像', 'FontSize', 10, 'FontWeight', 'bold');
            imshow(I_edge, 'Parent', ax(3));
            title(ax(3), '边缘图像', 'FontSize', 10, 'FontWeight', 'bold');
            imshow(plate_img, 'Parent', ax(4));
            title(ax(4), sprintf('车牌定位(%s牌)', plate_color), 'FontSize', 10, 'FontWeight', 'bold');

            if ~isempty(I_bin)
                imshow(I_bin, 'Parent', ax(5));
            end
            title(ax(5), '二值化', 'FontSize', 10, 'FontWeight', 'bold');

            % 字符分割拼接显示
            segShow = [];
            for k = 1:length(chars)
                if ~isempty(chars{k}) && ~all(chars{k}(:)==0)
                    segShow = [segShow, ones(40, 3), chars{k}]; %#ok<AGROW>
                end
            end
            if ~isempty(segShow)
                imshow(segShow, 'Parent', ax(6));
            end
            title(ax(6), '字符分割', 'FontSize', 10, 'FontWeight', 'bold');

            % 分块显示8个字符
            for k = 1:8
                cla(charAx(k));
                axis(charAx(k), 'off');
            end
            for k = 1:length(chars)
                if ~isempty(chars{k}) && ~all(chars{k}(:)==0)
                    imshow(chars{k}, 'Parent', charAx(k));
                end
            end

            set(resultLabel, 'String', [result ' [' plate_color '牌]']);
            appendLog('识别结果: %s [%s牌, %d字符]', result, plate_color, length(chars));
            set(statusLabel, 'String', '识别完成');
        catch ME
            appendLog('识别失败: %s', ME.message);
            set(statusLabel, 'String', '识别失败');
        end
        appData.isRecognizing = false;
        guidata(fig, appData);
    end

    function onReset(~, ~)
        if strcmp(get(debounceTimer, 'Running'), 'on')
            stop(debounceTimer);
        end
        appData.I = [];
        appData.isRecognizing = false;
        guidata(fig, appData);
        for k = 1:6
            cla(ax(k));
            title(ax(k), titles{k}, 'FontSize', 10, 'FontWeight', 'bold');
        end
        for k = 1:8, cla(charAx(k)); axis(charAx(k), 'off'); end
        set(resultLabel, 'String', '----------');
        set(logArea, 'String', {'系统就绪'});
        set(statusLabel, 'String', '就绪');
    end
    function onClose(~, ~)
        % 关闭窗口前删除定时器
        if isvalid(debounceTimer)
            stop(debounceTimer);
            delete(debounceTimer);
        end
        delete(fig);
    end

    function onSaveParams(~, ~)
        params = get_params();
        params.edge_threshold = get(edgeSlider, 'Value');
        params.morph_size = round(get(morphSlider, 'Value'));
        params.blue.split_thresh_factor = get(splitSlider, 'Value');
        params.green.split_thresh_factor = get(splitSlider, 'Value');
        params.blue.binary_offset = round(get(binarySlider, 'Value'));
        params.green.binary_offset = round(get(binarySlider, 'Value'));
        save_params(params, 'params_config.mat');
        appendLog('参数已保存到 params_config.mat');
        set(statusLabel, 'String', '参数已保存');
    end

    function onLoadParams(~, ~)
        params = load_params('params_config.mat');
        set(edgeSlider, 'Value', params.edge_threshold);
        set(morphSlider, 'Value', params.morph_size);
        if isfield(params, 'blue') && isfield(params.blue, 'split_thresh_factor')
            set(splitSlider, 'Value', params.blue.split_thresh_factor);
        else
            set(splitSlider, 'Value', 0.5);
        end
        if isfield(params, 'blue') && isfield(params.blue, 'binary_offset')
            set(binarySlider, 'Value', params.blue.binary_offset);
        else
            set(binarySlider, 'Value', 0);
        end
        set(edgeValLabel, 'String', sprintf('%.2f', get(edgeSlider, 'Value')));
        set(morphValLabel, 'String', sprintf('%d', round(get(morphSlider, 'Value'))));
        set(splitValLabel, 'String', sprintf('%.2f', get(splitSlider, 'Value')));
        set(binaryValLabel, 'String', sprintf('%d', round(get(binarySlider, 'Value'))));
        appendLog('参数已从 params_config.mat 加载');
        set(statusLabel, 'String', '参数已加载');
    end

    function onResetParams(~, ~)
        params = get_params();
        set(edgeSlider, 'Value', params.edge_threshold);
        set(morphSlider, 'Value', params.morph_size);
        set(splitSlider, 'Value', params.blue.split_thresh_factor);
        set(binarySlider, 'Value', params.blue.binary_offset);
        set(edgeValLabel, 'String', sprintf('%.2f', params.edge_threshold));
        set(morphValLabel, 'String', sprintf('%d', params.morph_size));
        set(splitValLabel, 'String', sprintf('%.2f', params.blue.split_thresh_factor));
        set(binaryValLabel, 'String', sprintf('%d', params.blue.binary_offset));
        appendLog('参数已恢复默认值');
        set(statusLabel, 'String', '默认参数');
    end

    function appendLog(msg, varargin)
        timestamp = datestr(now, 'HH:MM:SS');
        current = get(logArea, 'String');
        if ischar(current), current = {current}; end
        set(logArea, 'String', [current; {sprintf('[%s] %s', timestamp, sprintf(msg, varargin{:}))}]);
    end
end
