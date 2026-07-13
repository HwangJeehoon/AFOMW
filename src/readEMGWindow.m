function win = readEMGWindow(csvPath, hdr, startRel, endRel)
% READEMGWINDOW  EMG csv에서 [startRel, endRel] 구간(초, EMG 0초 기준)만 읽는다.
%   수백MB짜리 파일 전체를 읽지 않도록, 목표 시간의 행 번호를 dt로부터
%   역산해 그 근처로 바로 skip한 뒤 필요한 만큼만 읽는다. 부동소수점 오차로
%   행 번호가 살짝 어긋날 수 있어 앞뒤로 여유(BUFFER) 행을 더 읽고,
%   최종적으로는 실제 타임스탬프로 다시 걸러 정확한 구간만 남긴다.
%   win.time    : [n x 1] 공유 시간축(s)
%   win.values  : [n x nSensors] hdr.sensorNames 순서의 원본(raw) 값

BUFFER = 5;
rowStart = floor((startRel - hdr.t0) / hdr.dt) - BUFFER;
rowEnd = ceil((endRel - hdr.t0) / hdr.dt) + BUFFER;
rowStart = max(rowStart, 0);
nRows = rowEnd - rowStart + 1;

fid = fopen(csvPath, 'r');
if fid == -1
    error('readEMGWindow:fileNotFound', 'Cannot open %s', csvPath);
end
for i = 1:hdr.nHeaderLines
    fgetl(fid);
end
if rowStart > 0
    textscan(fid, '%*[^\n]', rowStart);
end
fmt = [repmat('%f', 1, 2 * hdr.nSensors), '%*[^\n]'];
C = textscan(fid, fmt, nRows, 'Delimiter', ',');
fclose(fid);

data = cell2mat(C);
timeCol = data(:, 1);
valueCols = data(:, 2:2:end);

keepMask = timeCol >= startRel & timeCol <= endRel;
win.time = timeCol(keepMask);
win.values = valueCols(keepMask, :);
win.sensorNames = hdr.sensorNames;
end
