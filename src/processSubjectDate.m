function processSubjectDate(subject, dateStr, pct, sensorNames, muscleNames, rootDir)
% PROCESSSUBJECTDATE  한 subject/날짜에 대해 bare/P1/P2/P3 4개 trial을 모두
% gait cycle 단위로 자른다. 같은 날짜의 걷는 구간(step) raw 샘플을 모두 모아
% 센서별 trimmed mean(상/하위 10% 제외 평균, offset)을 구해 rectify 전에 빼서 보정하고, 그 뒤
% rectify한 샘플을 다시 모아 센서별 RMS로 정규화한 뒤 EMG_processed/에 csv로
% 저장한다.
%   pct               : [start mid end] gait cycle % 경계 (subject별로 다름)
%   sensorNames/muscleNames : 센서 슬롯 <-> 근육 이름 매핑 (병렬 cell array)

if nargin < 6
    rootDir = pwd;
end

syncPath = fullfile(rootDir, subject, ['sync_' subject], ...
    sprintf('syncEMG_%s_%s.csv', subject, dateStr));
syncTable = readtable(syncPath, 'TextType', 'string');
syncMap = containers.Map(cellstr(lower(strtrim(syncTable.Trial))), num2cell(syncTable.Time));

emgDir = fullfile(rootDir, subject, dateStr, 'EMG');
gaitDir = fullfile(rootDir, subject, ['sync_' subject]);
outDir = fullfile(rootDir, subject, dateStr, 'EMG_processed');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

trials = struct( ...
    'key',        {'bare', 'p1', 'p2', 'p3'}, ...
    'emgFile',    {'bare.csv', 'P1.csv', 'P2.csv', 'P3.csv'}, ...
    'gaitSuffix', {'BARE', 'p1', 'p2', 'p3'}, ...
    'outPrefix',  {'bare', 'P1', 'P2', 'P3'});

allTrialCycles = cell(1, numel(trials));
for i = 1:numel(trials)
    tr = trials(i);
    emgPath = fullfile(emgDir, tr.emgFile);
    gaitPath = fullfile(gaitDir, sprintf('gaitCycle_%s_%s_%s.csv', subject, dateStr, tr.gaitSuffix));
    trigger = syncMap(tr.key);
    fprintf('  [%s/%s] processing trial %s ...\n', subject, dateStr, tr.outPrefix);
    allTrialCycles{i} = processTrialCycles(emgPath, gaitPath, trigger, pct, sensorNames, muscleNames);
    fprintf('    -> %d gait cycles extracted\n', numel(allTrialCycles{i}));
end

% 같은 날짜의 모든 trial에서 잘라낸(걷는 구간) raw 샘플을 모아 센서별 offset(trimmed mean) 산출
pooledRaw = cell(1, numel(muscleNames));
for i = 1:numel(trials)
    for c = 1:numel(allTrialCycles{i})
        Ttab = allTrialCycles{i}{c};
        for m = 1:numel(muscleNames)
            pooledRaw{m} = [pooledRaw{m}; Ttab.(muscleNames{m})];
        end
    end
end
TRIM_FRAC = 0.1;  % 상/하위 10%씩 제외한 trimmed mean으로 offset 산출 (이상치·노이즈에 덜 민감)
offsetVals = zeros(1, numel(muscleNames));
for m = 1:numel(muscleNames)
    v = sort(pooledRaw{m});
    k = floor(numel(v) * TRIM_FRAC);
    offsetVals(m) = mean(v(k + 1:end - k));
end

% offset 보정(빼기) 후 rectify(절댓값), 그 결과를 모아 센서별 RMS 산출
pooledRectified = cell(1, numel(muscleNames));
for i = 1:numel(trials)
    for c = 1:numel(allTrialCycles{i})
        Ttab = allTrialCycles{i}{c};
        for m = 1:numel(muscleNames)
            Ttab.(muscleNames{m}) = abs(Ttab.(muscleNames{m}) - offsetVals(m));
        end
        allTrialCycles{i}{c} = Ttab;
        for m = 1:numel(muscleNames)
            pooledRectified{m} = [pooledRectified{m}; Ttab.(muscleNames{m})];
        end
    end
end
rmsVals = zeros(1, numel(muscleNames));
for m = 1:numel(muscleNames)
    rmsVals(m) = sqrt(mean(pooledRectified{m} .^ 2));
end

% RMS로 정규화 후 저장
for i = 1:numel(trials)
    tr = trials(i);
    for c = 1:numel(allTrialCycles{i})
        Ttab = allTrialCycles{i}{c};
        for m = 1:numel(muscleNames)
            Ttab.(muscleNames{m}) = Ttab.(muscleNames{m}) / rmsVals(m);
        end
        outPath = fullfile(outDir, sprintf('%s_step%d.csv', tr.outPrefix, c));
        writetable(Ttab, outPath);
    end
end

fprintf('  [%s/%s] done. offset(mV) per muscle [%s]: %s\n', subject, dateStr, ...
    strjoin(muscleNames, ','), mat2str(offsetVals, 4));
fprintf('  [%s/%s] done. RMS(mV) per muscle [%s]: %s\n', subject, dateStr, ...
    strjoin(muscleNames, ','), mat2str(rmsVals, 4));
end
