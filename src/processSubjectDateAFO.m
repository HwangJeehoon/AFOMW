function processSubjectDateAFO(subject, dateStr, pct, rootDir, trials)
% PROCESSSUBJECTDATEAFO  한 subject/날짜에 대해 bare/P1/P2/P3 4개 trial의 AFO
% .bag에서 좌우 무릎/발목 상대각을 계산해 EMG와 같은 gait cycle 경계로 자른다.
% 이어서 이미 만들어져 있는 Subject/날짜/processed/emg_steps/{bare,p1,p2,p3}/의 step csv들을
% 읽어, 각 행의 AFOTime에 맞춰 4개 관절각 컬럼을 보간·추가한 뒤
% Subject/날짜/processed/emg_afo_steps/{bare,p1,p2,p3}/에 저장한다.
%   pct : [start mid end] gait cycle % 경계 (subject별로 다름, run_EMG_processing.m과 동일)

if nargin < 4
    rootDir = pwd;
end
if nargin < 5 || isempty(trials)
    trials = struct( ...
        'key',        {'bare', 'p1', 'p2', 'p3'}, ...
        'bagFile',    {'bare.bag', 'p1.bag', 'p2.bag', 'p3.bag'}, ...
        'emgFile',    {'bare.csv', 'P1.csv', 'P2.csv', 'P3.csv'}, ...
        'gaitSuffix', {'BARE', 'p1', 'p2', 'p3'}, ...
        'label',      {'bare', 'P1', 'P2', 'P3'});
end

paths = getSubjectDatePaths(rootDir, subject, dateStr);
syncPath = fullfile(paths.syncDir, ...
    sprintf('syncEMG_%s_%s.csv', subject, dateStr));
syncTable = readtable(syncPath, 'TextType', 'string');
syncMap = containers.Map(cellstr(lower(strtrim(syncTable.Trial))), num2cell(syncTable.Time));

bagDir = paths.afoRawDir;
emgDir = paths.emgRawDir;
emgProcessedDir = paths.emgStepsDir;
gaitDir = paths.syncDir;
mergedOutDir = paths.emgAfoStepsDir;
% if exist(mergedOutDir, 'dir')
%     rmdir(mergedOutDir, 's');  % 예전 flat 파일(예: P1_step1.csv) 잔재 삭제 시도 - 파일이
%     % 열려있거나 OneDrive 동기화 중이면 조용히 실패할 수 있어 주석 처리(잔재는 무해함)
% end
if ~exist(mergedOutDir, 'dir')
    mkdir(mergedOutDir);
end
calibrationRows = struct('Trial', {}, 'Joint', {}, 'GroundTime', {}, 'StandTime', {}, ...
    'FunctionalStartTime', {}, 'FunctionalEndTime', {}, 'AxisX', {}, 'AxisY', {}, 'AxisZ', {}, ...
    'SampleCount', {}, 'SelectedSampleCount', {}, 'ExplainedVariance', {}, 'RefAlignment', {}, ...
    'P05Deg', {}, 'P95Deg', {});

for i = 1:numel(trials)
    tr = trials(i);
    bagPath = fullfile(bagDir, tr.bagFile);
    emgPath = fullfile(emgDir, tr.emgFile);
    gaitPath = fullfile(gaitDir, sprintf('gaitCycle_%s_%s_%s.csv', subject, dateStr, tr.gaitSuffix));
    trigger = syncMap(tr.key);

    % EMG와 동일한 gait cycle 경계를 쓰기 위해 EMG 녹화 길이(collectionLength)를 그대로 가져다 쓴다.
    hdr = parseEMGHeader(emgPath);
    windows = extractCycleWindows(gaitPath, trigger, pct, hdr.collectionLength);
    if isempty(windows)
        error('processSubjectDateAFO:noFunctionalWindow', ...
            'No valid gait cycles found for %s/%s/%s.', subject, dateStr, tr.label);
    end
    functionalTimeRange = [windows(1).startRel, windows(end).endRel] + trigger;

    fprintf('  [%s/%s] computing AFO angles for trial %s ...\n', subject, dateStr, tr.label);
    [angleTable, calibration] = computeAFOJointAngles(bagPath, functionalTimeRange);
    cycleTables = cutAngleCycles(angleTable, gaitPath, trigger, pct, hdr.collectionLength);
    fprintf('    -> %d gait cycles extracted\n', numel(cycleTables));

    % processed/emg_steps/{bare,p1,p2,p3}/의 step csv를 읽어 AFOTime 기준으로 관절각
    % 컬럼을 보간·추가한 뒤 processed/emg_afo_steps/{bare,p1,p2,p3}/에 저장
    jointNames = angleTable.Properties.VariableNames(2:end);
    trialDir = fullfile(mergedOutDir, tr.key);
    if ~exist(trialDir, 'dir')
        mkdir(trialDir);
    end
    for c = 1:numel(cycleTables)
        emgStepPath = fullfile(emgProcessedDir, tr.key, sprintf('step%d.csv', c));
        emgStep = readProcessedEMGCsv(emgStepPath);
        for j = 1:numel(jointNames)
            emgStep.(jointNames{j}) = interp1(angleTable.AFOTime, angleTable.(jointNames{j}), ...
                emgStep.AFOTime, 'linear');
        end
        writetable(emgStep, fullfile(trialDir, sprintf('step%d.csv', c)));
    end

    for j = 1:numel(calibration.joints)
        joint = calibration.joints(j);
        calibrationRows(end + 1) = struct( ...
            'Trial', tr.label, 'Joint', joint.name, ...
            'GroundTime', calibration.groundTime, 'StandTime', calibration.standTime, ...
            'FunctionalStartTime', calibration.functionalStartTime, ...
            'FunctionalEndTime', calibration.functionalEndTime, ...
            'AxisX', joint.axis(1), 'AxisY', joint.axis(2), 'AxisZ', joint.axis(3), ...
            'SampleCount', joint.sampleCount, 'SelectedSampleCount', joint.selectedSampleCount, ...
            'ExplainedVariance', joint.explainedVariance, 'RefAlignment', joint.refAlignment, ...
            'P05Deg', joint.p05Deg, 'P95Deg', joint.p95Deg); %#ok<AGROW>
    end
end

writetable(struct2table(calibrationRows), fullfile(mergedOutDir, 'AFO_calibration.csv'));

fprintf('  [%s/%s] AFO processing done.\n', subject, dateStr);
end
