function bw = qiege(bw)
%QIEGE 裁剪二值图像四周的全零边界
    if isempty(bw) || all(bw(:)==0)
        return;
    end
    [r, c] = find(bw);
    if isempty(r)
        return;
    end
    bw = bw(min(r):max(r), min(c):max(c));
end
