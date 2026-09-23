function params = get_params()
%GET_PARAMS 车牌识别系统参数配置（改进版：全部参数全局化）

    %% 通用定位参数
    params.edge_threshold = 0.18;
    % Roberts边缘检测阈值：越小边越多，越大边越少
    params.morph_size = 25;
    % 形态学闭运算核边长（正方形核25×25）
    params.area_min = 2000;
    % bwareaopen最小连通域面积：小于此值的区域被删

    %% 蓝牌参数（7字符，蓝底白字）
    params.blue.target_h = 100;
    % 蓝牌缩放目标高度（像素）
    params.blue.binary_method = 'fixed';
    % 二值化方法：'fixed'=固定经验阈值；'otsu'=大津法
    params.blue.binary_offset = 0;
    % 二值化阈值偏移（滑块可调）
    params.blue.use_avg_filter = true;
    % 是否做3×3均值滤波（蓝牌用，去噪）
    params.blue.split_thresh_factor = 0.5;
    % 宽字符拆分阈值系数，参与计算split_thresh
    params.blue.hanzi_y1 = 10;
    % 汉字定位时最小宽度（小于此宽度判为噪点丢弃）
    params.blue.hanzi_y2 = 0.25;
    % 汉字中段像素占比阈值（大于此值判为汉字）

    %% 绿牌参数（8字符，绿底黑字渐变）
    params.green.target_h = 120;
    % 绿牌字多，放大更高有利分割
    params.green.binary_method = 'otsu';
    % 绿牌用Otsu自适应
    params.green.binary_offset = 0;
    params.green.use_avg_filter = false;
    % 绿牌细节多，不做均值滤波以免糊
    params.green.split_thresh_factor = 0.3;
    params.green.hanzi_y1 = 15;
    params.green.hanzi_y2 = 0.35;

    %% 分割参数（全局化）
    params.getword_min_width = 8;
    % getword最小宽度：小于此宽度视为噪点
    params.getword_aspect_ratio = 0.5;
    % 宽高比阈值：用于筛选窄噪点
    params.getword_min_area = 100;
    % 最小面积：小于此值当作噪点丢弃

    %% 识别参数
    params.char_count_blue = 7;
    params.char_count_green = 8;
    params.provinces = '京津冀晋蒙辽吉黑沪苏浙皖闽赣鲁豫鄂湘粤桂琼川贵云藏陕甘青宁新渝';
    % 省份简称字库（31个）

    %% 模板库路径
    params.template_dir = fullfile(fileparts(mfilename('fullpath')), 'templates');
    % 与主入口同样的路径拼接方式
end