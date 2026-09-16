function processSubjectDate(subject, dateStr, pct, sensorNames, muscleNames, rootDir, trials)
% PROCESSSUBJECTDATE  한 subject/날짜에 대해 bare/P1/P2/P3 4개 trial을 모두
% gait cycle 단위로 자른다. 같은 날짜의 걷는 구간(step) raw 샘플을 모두 모아
% 센서별 trimmed mean(상/하위 10% 제외 평균, offset)을 구해 rectify 전에 빼서 보정하고, 그 뒤
% rectify한 샘플을 다시 모아 센서별 95th percentile 값으로 정규화한다. 여기에 추가로
% LPF_CUTOFF_HZ(Hz) 4th-order zero-phase low-pass filter(plot 스크립트들과 동일한
% filtfiltStitched, 이웃 step 데이터로 padding)를 적용한 <muscle>_lpf 컬럼을 만들어
% processed/emg_steps/{bare,p1,p2,p3}/step{N}.csv에 raw(정규화된, 필터 미적용) 컬럼과
% 함께 저장한다. 각 csv는 'emg_lpf_hz = <값>' 메타데이터 줄과 'endheader'
% 줄로 시작하는 헤더 뒤에 컬럼 이름/데이터가 이어진다(readProcessedEMGCsv로 읽는다).
%   pct               : [start mid end] gait cycle % 경계 (subject별로 다름)
%   sensorNames/muscleNames : 센서 슬롯 <-> 근육 이름 매핑 (병렬 cell array)

if nargin < 6
    rootDir = pwd;
end
if nargin < 7 || isempty(trials)
    trials = struct( ...
        'key',        {'bare', 'p1', 'p2', 'p3'}, ...
        'emgFile',    {'bare.csv', 'P1.csv', 'P2.csv', 'P3.csv'}, ...
        'gaitSuffix', {'BARE', 'p1', 'p2', 'p3'}, ...
        'label',      {'bare', 'P1', 'P2', 'P3'});
end

LPF_CUTOFF_HZ = 8;   % run_EMG_plots.m의 profile/raw EMG plot들과 동일한 cutoff
FILTER_ORDER = 4;

paths = getSubjectDatePaths(rootDir, subject, dateStr);
syncPath = fullfile(paths.syncDir, ...
    sprintf('syncEMG_%s_%s.csv', subject, dateStr));
syncTable = readtable(syncPath, 'TextType', 'string');
syncMap = containers.Map(cellstr(lower(strtrim(syncTable.Trial))), num2cell(syncTable.Time));

emgDir = paths.emgRawDir;
gaitDir = paths.syncDir;
outDir = paths.emgStepsDir;
% if exist(outDir, 'dir')
%     rmdir(outDir, 's');  % 예전 flat 파일(예: P1_step1.csv) 잔재 삭제 시도 - 파일이
%     % 열려있거나 OneDrive 동기화 중이면 조용히 실패할 수 있어 주석 처리(잔재는 무해함)
% end
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

allTrialCycles = cell(1, numel(trials));
for i = 1:numel(trials)
    tr = trials(i);
    emgPath = fullfile(emgDir, tr.emgFile);
    gaitPath = fullfile(gaitDir, sprintf('gaitCycle_%s_%s_%s.csv', subject, dateStr, tr.gaitSuffix));
    trigger = syncMap(tr.key);
    fprintf('  [%s/%s] processing trial %s ...\n', subject, dateStr, tr.label);
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

% offset 보정(빼기) 후 rectify(절댓값), 그 결과를 모아 센서별 정규화 기준값(95th percentile) 산출
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
NORM_PCTL = 95;  % 정규화 기준: rectify된 신호의 상위 (100-NORM_PCTL)%를 넘어서는 값
normVals = zeros(1, numel(muscleNames));
for m = 1:numel(muscleNames)
    sortedVals = sort(pooledRectified{m});
    idx = ceil(NORM_PCTL / 100 * numel(sortedVals));
    normVals(m) = sortedVals(idx);
end

% 95th percentile 값으로 정규화
for i = 1:numel(trials)
    for c = 1:numel(allTrialCycles{i})
        Ttab = allTrialCycles{i}{c};
        for m = 1:numel(muscleNames)
            Ttab.(muscleNames{m}) = Ttab.(muscleNames{m}) / normVals(m);
        end
        allTrialCycles{i}{c} = Ttab;
    end
end

% 정규화된 신호에 LPF를 적용해 <muscle>_lpf 컬럼으로 추가(plot 스크립트와 동일하게
% 같은 trial의 이웃 step으로 padding, raw 컬럼은 그대로 둔다) 후 trial별 하위
% 폴더(bare/p1/p2/p3)에 step csv로 저장
firstNonEmpty = find(~cellfun(@isempty, allTrialCycles), 1);
Fs = 1 / mean(diff(allTrialCycles{firstNonEmpty}{1}.EMGTime));
[filtB, filtA] = butter(FILTER_ORDER, LPF_CUTOFF_HZ / (Fs / 2), 'low');
padLenTarget = ceil(3 * Fs / LPF_CUTOFF_HZ);

for i = 1:numel(trials)
    tr = trials(i);
    trialDir = fullfile(outDir, tr.key);
    if ~exist(trialDir, 'dir')
        mkdir(trialDir);
    end

    nSteps = numel(allTrialCycles{i});
    for c = 1:nSteps
        Ttab = allTrialCycles{i}{c};
        for m = 1:numel(muscleNames)
            col = muscleNames{m};
            yCur = Ttab.(col);
            if c > 1
                yPrev = allTrialCycles{i}{c - 1}.(col);
            else
                yPrev = [];
            end
            if c < nSteps
                yNext = allTrialCycles{i}{c + 1}.(col);
            else
                yNext = [];
            end
            Ttab.([col '_lpf']) = filtfiltStitched(filtB, filtA, yPrev, yCur, yNext, padLenTarget);
        end

        outPath = fullfile(trialDir, sprintf('step%d.csv', c));
        colNames = Ttab.Properties.VariableNames;
        data = table2array(Ttab);
        rowFmt = [strjoin(repmat({'%.15g'}, 1, numel(colNames)), ','), '\n'];

        fid = fopen(outPath, 'w');
        fprintf(fid, 'emg_lpf_hz = %g\n', LPF_CUTOFF_HZ);
        fprintf(fid, 'endheader\n');
        fprintf(fid, '%s\n', strjoin(colNames, ','));
        fprintf(fid, rowFmt, data');
        fclose(fid);
    end
end

fprintf('  [%s/%s] done. offset(mV) per muscle [%s]: %s\n', subject, dateStr, ...
    strjoin(muscleNames, ','), mat2str(offsetVals, 4));
fprintf('  [%s/%s] done. %dth percentile(mV) per muscle [%s]: %s\n', subject, dateStr, ...
    NORM_PCTL, strjoin(muscleNames, ','), mat2str(normVals, 4));
end
