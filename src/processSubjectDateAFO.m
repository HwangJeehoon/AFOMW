function processSubjectDateAFO(subject, dateStr, pct, rootDir)
% PROCESSSUBJECTDATEAFO  한 subject/날짜에 대해 bare/P1/P2/P3 4개 trial의 AFO
% .bag에서 좌우 무릎/발목 상대각을 계산해 EMG와 같은 gait cycle 경계로 잘라
% Subject/날짜/AFO_processed/에 csv로 저장한다. 이어서 이미 만들어져 있는
% Subject/날짜/EMG_processed/의 step csv들을 읽어, 각 행의 AFOTime에 맞춰
% 4개 관절각 컬럼을 보간·추가한 뒤 Subject/날짜/EMG_AFO_merged/에 저장한다.
%   pct : [start mid end] gait cycle % 경계 (subject별로 다름, run_EMG_processing.m과 동일)

if nargin < 4
    rootDir = pwd;
end

syncPath = fullfile(rootDir, subject, ['sync_' subject], ...
    sprintf('syncEMG_%s_%s.csv', subject, dateStr));
syncTable = readtable(syncPath, 'TextType', 'string');
syncMap = containers.Map(cellstr(lower(strtrim(syncTable.Trial))), num2cell(syncTable.Time));

bagDir = fullfile(rootDir, subject, dateStr, 'AFO');
emgDir = fullfile(rootDir, subject, dateStr, 'EMG');
emgProcessedDir = fullfile(rootDir, subject, dateStr, 'EMG_processed');
gaitDir = fullfile(rootDir, subject, ['sync_' subject]);
afoOutDir = fullfile(rootDir, subject, dateStr, 'AFO_processed');
mergedOutDir = fullfile(rootDir, subject, dateStr, 'EMG_AFO_merged');
if ~exist(afoOutDir, 'dir')
    mkdir(afoOutDir);
end
if ~exist(mergedOutDir, 'dir')
    mkdir(mergedOutDir);
end

trials = struct( ...
    'key',        {'bare', 'p1', 'p2', 'p3'}, ...
    'bagFile',    {'bare.bag', 'p1.bag', 'p2.bag', 'p3.bag'}, ...
    'emgFile',    {'bare.csv', 'P1.csv', 'P2.csv', 'P3.csv'}, ...
    'gaitSuffix', {'BARE', 'p1', 'p2', 'p3'}, ...
    'outPrefix',  {'bare', 'P1', 'P2', 'P3'});

for i = 1:numel(trials)
    tr = trials(i);
    bagPath = fullfile(bagDir, tr.bagFile);
    emgPath = fullfile(emgDir, tr.emgFile);
    gaitPath = fullfile(gaitDir, sprintf('gaitCycle_%s_%s_%s.csv', subject, dateStr, tr.gaitSuffix));
    trigger = syncMap(tr.key);

    fprintf('  [%s/%s] computing AFO angles for trial %s ...\n', subject, dateStr, tr.outPrefix);
    angleTable = computeAFOJointAngles(bagPath);

    % EMG와 동일한 gait cycle 경계를 쓰기 위해 EMG 녹화 길이(collectionLength)를 그대로 가져다 쓴다.
    hdr = parseEMGHeader(emgPath);
    cycleTables = cutAngleCycles(angleTable, gaitPath, trigger, pct, hdr.collectionLength);
    fprintf('    -> %d gait cycles extracted\n', numel(cycleTables));

    for c = 1:numel(cycleTables)
        writetable(cycleTables{c}, fullfile(afoOutDir, sprintf('%s_step%d.csv', tr.outPrefix, c)));
    end

    % EMG_processed의 step csv를 읽어 AFOTime 기준으로 관절각 컬럼을 보간·추가
    jointNames = angleTable.Properties.VariableNames(2:end);
    for c = 1:numel(cycleTables)
        emgStepPath = fullfile(emgProcessedDir, sprintf('%s_step%d.csv', tr.outPrefix, c));
        emgStep = readtable(emgStepPath);
        for j = 1:numel(jointNames)
            emgStep.(jointNames{j}) = interp1(angleTable.AFOTime, angleTable.(jointNames{j}), ...
                emgStep.AFOTime, 'linear');
        end
        writetable(emgStep, fullfile(mergedOutDir, sprintf('%s_step%d.csv', tr.outPrefix, c)));
    end
end

fprintf('  [%s/%s] AFO processing done.\n', subject, dateStr);
end
