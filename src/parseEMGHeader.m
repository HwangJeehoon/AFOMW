function hdr = parseEMGHeader(csvPath)
% PARSEEMGHEADER  Delsys Trigno EMG csv의 8줄 헤더를 파싱한다.
%   hdr.sensorNames      : 파일 내 컬럼쌍 순서대로 정렬된 센서 이름 (파일마다 순서가 다를 수 있음)
%   hdr.fs, hdr.dt        : 샘플링 주파수(Hz), 샘플 간격(s)
%   hdr.t0                : 첫 데이터 행의 시간값(s) - 모든 센서가 공유하는 시간축의 시작점
%   hdr.nHeaderLines      : 데이터 시작 전 헤더 줄 수 (8)
%   hdr.collectionLength  : 녹화 길이(s)

fid = fopen(csvPath, 'r');
if fid == -1
    error('parseEMGHeader:fileNotFound', 'Cannot open %s', csvPath);
end
lines = cell(8, 1);
for i = 1:8
    lines{i} = fgetl(fid);
end
firstDataLine = fgetl(fid);
fclose(fid);

collParts = strsplit(lines{3}, ',');
collectionLength = str2double(collParts{2});

nameParts = strsplit(lines{4}, ',');
sensorNames = strtrim(nameParts(1:2:end));
sensorNames = regexprep(sensorNames, '\s*\(\d+\)\s*$', '');
nSensors = numel(sensorNames);

rateParts = strsplit(lines{7}, ',');
fs = str2double(strrep(strtrim(rateParts{2}), ' Hz', ''));

dataParts = strsplit(firstDataLine, ',');
t0 = str2double(dataParts{1});

hdr = struct( ...
    'sensorNames', {sensorNames}, ...
    'nSensors', nSensors, ...
    'fs', fs, ...
    'dt', 1 / fs, ...
    't0', t0, ...
    'nHeaderLines', 8, ...
    'collectionLength', collectionLength);
end
