% run_EMG_plots.m
% EMG_processed 결과에서 trial(bare/P1/P2/P3)별로 지정한 step 범위를 골라
% 근육별 RMS bar plot(요청 1)과 gait cycle mean profile plot(요청 2)을 그리고
% Subject/날짜/EMG_plots/에 png로 저장한다. (같은 subject/날짜 내에서만 비교)

clear; clc; close all;
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));

rootDir = fullfile(fileparts(mfilename('fullpath')), '..');

%% ── Plot 1 설정 ──────────────────────────────────────────────────────────
subject = 'SAH01';
dateStr = '260706';

muscleNames = {'L_TA', 'L_GM', 'L_RF', 'L_VL', 'R_TA', 'R_GM', 'R_RF', 'R_VL'};

sideNames.L = 'Left';
sideNames.R = 'Right';
muscleFullNames.TA = 'TibAnt';
muscleFullNames.GM = 'Gastroc';
muscleFullNames.RF = 'RectFem';
muscleFullNames.VL = 'VastLat';

% trial별로 사용할 step 번호 범위 (EMG_processed/{trial}_stepN.csv의 N)를 직접 지정
stepRange.bare = 3:73; %76
stepRange.P1   = 18:88; %91
stepRange.P2   = 7:77; %80
stepRange.P3   = 5:75; %78

%% ── 데이터 로드 ────────────────────────────────────────────────────
trialKeys = {'bare', 'P1', 'P2', 'P3'};
trials = struct('name', {}, 'tables', {});
for i = 1:numel(trialKeys)
    key = trialKeys{i};
    trials(i).name = key;
    trials(i).tables = loadTrialSteps(subject, dateStr, key, stepRange.(key), rootDir);
end

outDir = fullfile(rootDir, subject, dateStr, 'EMG_plots');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% ── plot ──────────────────────────────────────────────────────────
plotRMSBarByMuscle(subject, dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir);
plotGaitCycleProfile(subject, dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir);

fprintf('\n=== plotting complete: %s ===\n', outDir);



clear; clc; close all;
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));

rootDir = fullfile(fileparts(mfilename('fullpath')), '..');




%% ── Plot 2 설정 ──────────────────────────────────────────────────────────
subject = 'SAH01';
dateStr = '260713';

muscleNames = {'L_TA', 'L_GM', 'L_RF', 'L_VL', 'R_TA', 'R_GM', 'R_RF', 'R_VL'};

sideNames.L = 'Left';
sideNames.R = 'Right';
muscleFullNames.TA = 'TibAnt';
muscleFullNames.GM = 'Gastroc';
muscleFullNames.RF = 'RectFem';
muscleFullNames.VL = 'VastLat';

% trial별로 사용할 step 번호 범위 (EMG_processed/{trial}_stepN.csv의 N)를 직접 지정
stepRange.bare = 3:73; %76
stepRange.P1   = 4:74; %77
stepRange.P2   = 8:78; %81
stepRange.P3   = 3:73; %76

%% ── 데이터 로드 ────────────────────────────────────────────────────
trialKeys = {'bare', 'P1', 'P2', 'P3'};
trials = struct('name', {}, 'tables', {});
for i = 1:numel(trialKeys)
    key = trialKeys{i};
    trials(i).name = key;
    trials(i).tables = loadTrialSteps(subject, dateStr, key, stepRange.(key), rootDir);
end

outDir = fullfile(rootDir, subject, dateStr, 'EMG_plots');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% ── plot ──────────────────────────────────────────────────────────
plotRMSBarByMuscle(subject, dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir);
plotGaitCycleProfile(subject, dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir);

fprintf('\n=== plotting complete: %s ===\n', outDir);



%% ── Plot 3 설정 ──────────────────────────────────────────────────────────
subject = 'SAH03';
dateStr = '260623';

muscleNames = {'L_TA', 'L_GM', 'L_RF', 'L_VL', 'R_TA', 'R_GM', 'R_RF', 'R_VL'};

sideNames.L = 'Left';
sideNames.R = 'Right';
muscleFullNames.TA = 'TibAnt';
muscleFullNames.GM = 'Gastroc';
muscleFullNames.RF = 'RectFem';
muscleFullNames.VL = 'VastLat';

% trial별로 사용할 step 번호 범위 (EMG_processed/{trial}_stepN.csv의 N)를 직접 지정
stepRange.bare = 4:74; %77
stepRange.P1   = 51:121; %124
stepRange.P2   = 3:73; %76
stepRange.P3   = 23:93; %96

%% ── 데이터 로드 ────────────────────────────────────────────────────
trialKeys = {'bare', 'P1', 'P2', 'P3'};
trials = struct('name', {}, 'tables', {});
for i = 1:numel(trialKeys)
    key = trialKeys{i};
    trials(i).name = key;
    trials(i).tables = loadTrialSteps(subject, dateStr, key, stepRange.(key), rootDir);
end

outDir = fullfile(rootDir, subject, dateStr, 'EMG_plots');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% ── plot ──────────────────────────────────────────────────────────
plotRMSBarByMuscle(subject, dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir);
plotGaitCycleProfile(subject, dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir);

fprintf('\n=== plotting complete: %s ===\n', outDir);


%% ── Plot 54 설정 ──────────────────────────────────────────────────────────
subject = 'SAH03';
dateStr = '260630';

muscleNames = {'L_TA', 'L_GM', 'L_RF', 'L_VL', 'R_TA', 'R_GM', 'R_RF', 'R_VL'};

sideNames.L = 'Left';
sideNames.R = 'Right';
muscleFullNames.TA = 'TibAnt';
muscleFullNames.GM = 'Gastroc';
muscleFullNames.RF = 'RectFem';
muscleFullNames.VL = 'VastLat';

% trial별로 사용할 step 번호 범위 (EMG_processed/{trial}_stepN.csv의 N)를 직접 지정
stepRange.bare = 4:74; %77
stepRange.P1   = 14:84; %87
stepRange.P2   = 15:85; %88
stepRange.P3   = 15:85; %88

%% ── 데이터 로드 ────────────────────────────────────────────────────
trialKeys = {'bare', 'P1', 'P2', 'P3'};
trials = struct('name', {}, 'tables', {});
for i = 1:numel(trialKeys)
    key = trialKeys{i};
    trials(i).name = key;
    trials(i).tables = loadTrialSteps(subject, dateStr, key, stepRange.(key), rootDir);
end

outDir = fullfile(rootDir, subject, dateStr, 'EMG_plots');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% ── plot ──────────────────────────────────────────────────────────
plotRMSBarByMuscle(subject, dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir);
plotGaitCycleProfile(subject, dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir);

fprintf('\n=== plotting complete: %s ===\n', outDir);
