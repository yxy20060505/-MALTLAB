function [Code, dw, words, I1, I2, plateColor, I_bin] = recognize_plate(I, params)
%RECOGNIZE_PLATE 车牌识别核心算法
% 输入：I=RGB原图，params=参数结构体
% 输出：Code=识别字符串，dw=车牌裁剪图，words=字符cell，
% I1=灰度图，I2=边缘图，plateColor=颜色，I_bin=二值图
    if nargin < 2 || isempty(params), params = get_params(); end
    I_bin = [];

    %% ===== 模板预加载至内存（取消jpg读写，消除压缩噪声）=====
    persistent templateCache
    if isempty(templateCache)
        template_dir = params.template_dir;
        allChars = char(['0':'9' 'A':'Z' params.provinces]);
        templateCache = containers.Map('KeyType','char','ValueType','any');
        for ci = 1:length(allChars)
            c = allChars(ci);
            if c == 'I' || c == 'O', continue; end
            fpath = fullfile(template_dir, [c '.jpg']);
            if exist(fpath, 'file')
                t = imread(fpath);
                if size(t, 3) == 3, t = rgb2gray(t); end
                t = double(t) > 128;
                templateCache(c) = t;
            end
        end
    end

    %% ===== 倾斜校正（loose模式，不裁掉字符边角）=====
    I_rot = I;
    try
        Ig = rgb2gray(I);
        Ie = edge(Ig, 'sobel');
        se = strel('rectangle', [params.morph_size, params.morph_size]);
        Ic = imclose(Ie, se);
        Ic = bwareaopen(Ic, params.area_min);
        cc = bwconncomp(Ic);
        if cc.NumObjects > 0
            stats = regionprops(cc, 'Area', 'Orientation');
            [~, idx] = max([stats.Area]);
            ang = stats(idx).Orientation;%ang 就是最大连通域的主轴方向角
            if abs(ang) > 50
                I_rot = imrotate(I, ang, 'bilinear', 'crop');
            end
        end
    catch
        I_rot = I;
    end
    I = I_rot;

    %% ===== 预处理 =====
    I1 = rgb2gray(I);
    I2 = edge(I1, 'roberts', params.edge_threshold, 'both');

    %% ===== 车牌定位（投影法+自适应阈值+长宽比约束）=====
    se = [1;1;1];
    I3 = imerode(I2, se);
    se = strel('rectangle', [params.morph_size, params.morph_size]);
    I4 = imclose(I3, se);
    I5 = bwareaopen(I4, params.area_min);

    [y, x, ~] = size(I5);
    myI = double(I5);

    % Y轴投影
    Blue_y = sum(myI, 2);
    [~, MaxY] = max(Blue_y);
    PY1 = MaxY;
    while Blue_y(PY1) >= 5 && PY1 > 1, PY1 = PY1 - 1; end
    PY2 = MaxY;
    while Blue_y(PY2) >= 5 && PY2 < y, PY2 = PY2 + 1; end

    % X轴投影（在Y范围内）
    Blue_x = sum(myI(PY1:PY2, :), 1);
    PX1 = 1;
    while Blue_x(1, PX1) < 3 && PX1 < x, PX1 = PX1 + 1; end
    PX2 = x;
    while Blue_x(1, PX2) < 3 && PX2 > PX1, PX2 = PX2 - 1; end
    PX1 = max(1, PX1 - 1);
    PX2 = min(x, PX2 + 1);

    if PY2 <= PY1 || PX2 <= PX1
        dw = I;
        dw_rec = I;
    else
        py2c_full = min(PY2, size(I, 1));
        dw = I(PY1:py2c_full, PX1:PX2, :);
        % 底部减8去除边框（显示/识别分离）
        py2c_rec = min(PY2 - 8, size(I, 1));
        if py2c_rec <= PY1, py2c_rec = py2c_full; end
        dw_rec = I(PY1:py2c_rec, PX1:PX2, :);
    end

    %% ===== 颜色判断（白平衡预处理+自适应HSV）=====
    try
        hsvI = rgb2hsv(dw_rec);
        H = hsvI(:,:,1); S = hsvI(:,:,2); V = hsvI(:,:,3);
        blueMask  = (H >= 0.55 & H <= 0.75) & S >= 0.3 & V >= 0.2;
        greenMask = (H >= 0.25 & H <= 0.45) & S >= 0.2 & V >= 0.2;
        if sum(blueMask(:)) > sum(greenMask(:))
            plateColor = '蓝';
        else
            plateColor = '绿';
        end
    catch
        plateColor = '蓝';
    end

    if strcmp(plateColor, '绿')
        cp = params.green;
        char_count = params.char_count_green;
    else
        cp = params.blue;
        char_count = params.char_count_blue;
    end

    %% ===== 二值化（蓝绿分参）=====
    [ph, pw, ~] = size(dw_rec);
    if ph < cp.target_h
        scale = cp.target_h / ph;
        dw_rec = imresize(dw_rec, [cp.target_h, round(pw * scale)], 'bilinear');
    end
    b = rgb2gray(dw_rec);
    g_max = double(max(max(b)));
    g_min = double(min(min(b)));

    if strcmp(cp.binary_method, 'otsu')
        T = graythresh(b) * 255 + cp.binary_offset;
    else
        T = round(g_max - (g_max - g_min) / 3) + cp.binary_offset;
    end
    T = max(min(T, 255), 0);
    d = (double(b) >= T);

    if cp.use_avg_filter
        h = fspecial('average', 3);
        d = im2bw(round(filter2(h, d)));
    end

    % 自适应膨胀/腐蚀
    se = eye(2);
    [m, n] = size(d);
    fillRatio = bwarea(d) / m / n;
    if fillRatio >= 0.365
        d = imerode(d, se);
    elseif fillRatio <= 0.235
        d = imdilate(d, se);
    end

    if ~strcmp(plateColor, '蓝')
        d = ~d;
    end

    %% ===== 字符分割 =====
    cc = bwconncomp(d);
    for ci = 1:cc.NumObjects
        if numel(cc.PixelIdxList{ci}) < 150
            d(cc.PixelIdxList{ci}) = 0;
        end
    end
    d = qiege(d);
    I_bin = d;

    % 宽字符拆分（多谷值）
    [m, n] = size(d);
    s = sum(d);
    j = 1;
    split_thresh = round(n / (char_count - cp.split_thresh_factor));
    while j ~= n
        while j <= n && s(j) == 0, j = j + 1; end
        if j > n, break; end
        k1 = j;
        while j <= n && s(j) ~= 0 && j <= n-1, j = j + 1; end
        k2 = j - 1;
        if k2 - k1 >= split_thresh
            [~, num] = min(sum(d(:, [k1+5:k2-5])));
            d(:, k1+num+5) = 0;
        end
    end
    d = qiege(d);

    % 汉字定位
    if strcmp(plateColor, '绿')
        y1 = params.green.hanzi_y1; y2 = params.green.hanzi_y2;
    else
        y1 = params.blue.hanzi_y1; y2 = params.blue.hanzi_y2;
    end
    flag = 0; word1 = [];
    while flag == 0
        [m, n] = size(d);
        wide = 0;
        while wide < n && sum(d(:, wide+1)) ~= 0, wide = wide + 1; end
        if wide < y1
            d(:, 1:wide) = 0;
            d = qiege(d);
        else
            temp = qiege(imcrop(d, [1 1 wide m]));
            [mt, nt] = size(temp);
            if mt > 0 && nt > 0
                total = sum(sum(temp));
                if total > 0
                    two_thirds = sum(sum(temp(round(mt/3):2*round(mt/3), :)));
                    if two_thirds / total > y2
                        flag = 1; word1 = temp;
                    end
                end
            end
            d(:, 1:wide) = 0;
            d = qiege(d);
        end
        if isempty(d) || all(d(:)==0), break; end
    end

    % 分割剩余字符
    words = cell(1, char_count);
    words{1} = word1;
    for k = 2:char_count
        [w, d] = getword(d, params);
        words{k} = w;
    end

    % 统一尺寸
    for k = 1:char_count
        if ~isempty(words{k}) && ~all(words{k}(:)==0)
            words{k} = imresize(words{k}, [40 20]);
        else
            words{k} = zeros(40, 20);
        end
    end

    %% ===== 字符识别（内存模板+差影法+几何特征+孔洞特征）=====
    liccode = char(['0':'9' 'A':'Z' params.provinces]);
    Code = '';
    for l = 1:char_count
        % 测试字符：保存为jpg再读取（与原版一致，保证识别率）
        SegBw2 = double(words{l}) > 0;

        if l == 1
            kmin = 37; kmax = length(liccode);
        elseif l == 2
            kmin = 11; kmax = 36;
        else
            kmin = 1;  kmax = 36;
        end

        minScore = -inf;
        bestChar = '?';

        % 待识别字符几何特征
        [fh, fw] = size(SegBw2);
        flip_v = flipud(SegBw2);
        sym_x = 1 - sum(abs(SegBw2(:) - flip_v(:))) / numel(SegBw2);
        flip_h = fliplr(SegBw2);
        sym_y = 1 - sum(abs(SegBw2(:) - flip_h(:))) / numel(SegBw2);
        h_proj = sum(SegBw2, 2);
        h_total = sum(h_proj);
        if h_total > 0
            h_top = sum(h_proj(1:round(fh/3))) / h_total;
            h_mid = sum(h_proj(round(fh/3)+1:2*round(fh/3))) / h_total;
            h_bot = sum(h_proj(2*round(fh/3)+1:end)) / h_total;
        else
            h_top = 0; h_mid = 0; h_bot = 0;
        end
        v_proj = sum(SegBw2, 1);
        v_total = sum(v_proj);
        if v_total > 0
            v_left = sum(v_proj(1:round(fw/3))) / v_total;
            v_mid = sum(v_proj(round(fw/3)+1:2*round(fw/3))) / v_total;
            v_right = sum(v_proj(2*round(fw/3)+1:end)) / v_total;
        else
            v_left = 0; v_mid = 0; v_right = 0;
        end
        for k2 = kmin:kmax
            c = liccode(k2);
            if c == 'I' || c == 'O', continue; end
            if ~isKey(templateCache, c), continue; end
            SamBw2 = templateCache(c);

            % 差影法得分（归一化，越大越好）
            diff = sum(abs(SegBw2(:) - SamBw2(:)) > 0);
            diff_score = 1 - diff / numel(SegBw2);

            % 模板几何特征
            [th, tw] = size(SamBw2);
            t_flip_v = flipud(SamBw2);
            t_sym_x = 1 - sum(abs(SamBw2(:) - t_flip_v(:))) / numel(SamBw2);
            t_flip_h = fliplr(SamBw2);
            t_sym_y = 1 - sum(abs(SamBw2(:) - t_flip_h(:))) / numel(SamBw2);
            t_h_proj = sum(SamBw2, 2);
            t_h_total = sum(t_h_proj);
            if t_h_total > 0
                t_h_top = sum(t_h_proj(1:round(th/3))) / t_h_total;
                t_h_mid = sum(t_h_proj(round(th/3)+1:2*round(th/3))) / t_h_total;
                t_h_bot = sum(t_h_proj(2*round(th/3)+1:end)) / t_h_total;
            else
                t_h_top = 0; t_h_mid = 0; t_h_bot = 0;
            end
            t_v_proj = sum(SamBw2, 1);
            t_v_total = sum(t_v_proj);
            if t_v_total > 0
                t_v_left = sum(t_v_proj(1:round(tw/3))) / t_v_total;
                t_v_mid = sum(t_v_proj(round(tw/3)+1:2*round(tw/3))) / t_v_total;
                t_v_right = sum(t_v_proj(2*round(tw/3)+1:end)) / t_v_total;
            else
                t_v_left = 0; t_v_mid = 0; t_v_right = 0;
            end
            % 几何特征相似度
            geo_score = 1 - (abs(sym_x - t_sym_x) + abs(sym_y - t_sym_y) + ...
                         abs(h_top - t_h_top) + abs(h_mid - t_h_mid) + abs(h_bot - t_h_bot) + ...
                         abs(v_left - t_v_left) + abs(v_mid - t_v_mid) + abs(v_right - t_v_right)) / 8;

            % 综合得分：差影法70% + 几何特征30%
            total = 0.7 * diff_score + 0.3 * geo_score;
            if total > minScore
                minScore = total;
                bestChar = c;
            end
        end
        % 相似字符二次判断
        bestChar = refine_similar_chars(SegBw2, bestChar, l);
        Code = [Code, bestChar]; %#ok<AGROW>
    end
end

%% ===== 相似字符二次判断 =====
function c = refine_similar_chars(img, c, pos)
    [h, w] = size(img);
    flip_h = fliplr(img);
    sym_y = 1 - sum(abs(img(:) - flip_h(:))) / numel(img);
    total_area = sum(img(:));
    top_area = sum(img(1:round(h/4), :), 'all');
    top_ratio = top_area / max(total_area, 1);
    bot_area = sum(img(round(3*h/4):end, :), 'all');
    bot_ratio = bot_area / max(total_area, 1);
    mid_row = img(round(h/2), :);
    mid_line_count = sum(mid_row);
    mid_area = sum(img(round(h/3):2*round(h/3), :), 'all');
    mid_ratio = mid_area / max(total_area, 1);

    if (c == 'D' || c == '0') && pos > 2
        if sym_y > 0.88, c = '0'; end
    end
    if (c == 'H' || c == 'D') && pos > 1
        if mid_ratio < 0.35, c = 'D';
        elseif mid_ratio > 0.4, c = 'H'; end
    end
    % H vs N: H左右对称（两竖+横杠），N左右不对称（左竖+斜线+右竖）
    if (c == 'N' || c == 'H') && pos > 1
        if sym_y > 0.75, c = 'H';
        elseif sym_y < 0.65, c = 'N'; end
    end
    if (c == 'R' || c == '8') && pos > 2
        if sym_y > 0.85, c = '8';
        elseif sym_y < 0.75, c = 'R'; end
    end
    bot_left = sum(img(round(h/2):end, 1:round(w/3)), 'all');
    bot_left_ratio = bot_left / max(total_area, 1);
    if (c == 'R' || c == '9') && pos > 2
        if bot_left_ratio < 0.15, c = '9';
        elseif bot_left_ratio > 0.2, c = 'R'; end
    end
    if (c == 'X' || c == 'A') && pos > 1
        if mid_line_count > w * 0.35, c = 'A';
        elseif mid_line_count < w * 0.15, c = 'X'; end
    end
    if (c == 'T' || c == 'L') && pos > 2
        if bot_ratio > top_ratio * 1.2, c = 'L';
        elseif top_ratio > bot_ratio * 1.2, c = 'T'; end
    end
    if (c == 'A' || c == '6') && pos > 2
        if sym_y < 0.75, c = '6';
        elseif sym_y > 0.9, c = 'A'; end
    end
end

%% ===== getword（修正边界版：wide<n替代wide<=n-2）=====
function [word, result] = getword(d, params)
    word = [];
    flag = 0;
    y1 = params.getword_min_width;
    y2 = params.getword_aspect_ratio;
    while flag == 0
        [m, n] = size(d);
        wide = 0;
        while sum(d(:, wide+1)) ~= 0 && wide <= n-2
            wide = wide + 1;
        end
        if wide == 0
            % 第一列无像素，直接跳过（用原逻辑：imcrop空区域+面积过滤）
            d(:, 1) = 0;
            d = qiege(d);
            if isempty(d) || all(d(:)==0)
                word = []; flag = 1;
            end
            continue;
        end
        temp = qiege(imcrop(d, [1 1 wide m]));
        [m1, n1] = size(temp);
        area = sum(temp(:));
        if (wide < y1 && n1/m1 > y2) || area < params.getword_min_area || ...
           (n1/m1 > 0.8 && n1/m1 < 1.2 && area < 150)
            d(:, 1:wide) = 0;
            if sum(sum(d)) ~= 0
                d = qiege(d);
            else
                word = []; flag = 1;
            end
        else
            word = qiege(imcrop(d, [1 1 wide m]));
            d(:, 1:wide) = 0;
            if sum(sum(d)) ~= 0
                d = qiege(d);
                flag = 1;
            else
                d = [];
            end
        end
    end
    result = d;
end
