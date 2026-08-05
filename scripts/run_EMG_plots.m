% run_EMG_plots.m
% EMG_processed 결과에서 trial(bare/P1/P2/P3)별로 지정한 step 범위를 골라
% 근육별 RMS bar plot(요청 1), gait cycle mean profile plot(요청 2), step별
% raw EMG time series plot(요청 3)을 그리고 fig/EMG/{Subject}_{날짜}/에 png로
% 저장한다. (같은 subject/날짜 내에서만 비교)

clear; clc; close all;
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));

rootDir = fullfile(fileparts(mfilename('fullpath')), '..');

%% ── 공통 설정 ──────────────────────────────────────────────────────
muscleNames = {'L_TA', 'L_GM', 'L_RF', 'L_VL', 'R_TA', 'R_GM', 'R_RF', 'R_VL'};

sideNames.L = 'Left';
sideNames.R = 'Right';
muscleFullNames.TA = 'TibAnt';
muscleFullNames.GM = 'Gastroc';
muscleFullNames.RF = 'RectFem';
muscleFullNames.VL = 'VastLat';

%% ── subject/날짜별 설정 (trial별 step 번호 범위, affected side를 직접 지정) ──
configs = struct('subject', {}, 'dateStr', {}, 'stepRange', {}, 'affectedSide', {});

configs(1).subject = 'SAH01';
configs(1).dateStr = '260706';
configs(1).affectedSide = 'L';
configs(1).stepRange.bare = 3:73; %76
configs(1).stepRange.P1   = 18:88; %91
configs(1).stepRange.P2   = 7:77; %80
configs(1).stepRange.P3   = 5:75; %78

configs(2).subject = 'SAH01';
configs(2).dateStr = '260713';
configs(2).affectedSide = 'L';
configs(2).stepRange.bare = 3:73; %76
configs(2).stepRange.P1   = 4:74; %77
configs(2).stepRange.P2   = 8:78; %81
configs(2).stepRange.P3   = 3:73; %76

configs(3).subject = 'SAH03';
configs(3).dateStr = '260623';
configs(3).affectedSide = 'L';
configs(3).stepRange.bare = 4:74; %76
configs(3).stepRange.P1   = 51:121; %123
configs(3).stepRange.P2   = 3:73; %75
configs(3).stepRange.P3   = 23:93; %95

configs(4).subject = 'SAH03';
configs(4).dateStr = '260630';
configs(4).affectedSide = 'L';
configs(4).stepRange.bare = 4:74; %76
configs(4).stepRange.P1   = 14:84; %86
configs(4).stepRange.P2   = 15:85; %87
configs(4).stepRange.P3   = 15:85; %87

% configs(1).subject = 'SAH03';
% configs(1).dateStr = '260630';
% configs(1).affectedSide = 'L';
% configs(1).stepRange.bare = 4:74; %76
% configs(1).stepRange.P1   = 14:84; %86
% configs(1).stepRange.P2   = 15:85; %87
% configs(1).stepRange.P3   = 15:85; %87

%% ── 데이터 로드 + plot ────────────────────────────────────────────
trialKeys = {'bare', 'P1', 'P2', 'P3'};

for i = 1:numel(configs)
    cfg = configs(i);

    trials = struct('name', {}, 'steps', {}, 'tables', {});
    for k = 1:numel(trialKeys)
        key = trialKeys{k};
        trials(k).name = key;
        trials(k).steps = cfg.stepRange.(key);
        trials(k).tables = loadTrialSteps(cfg.subject, cfg.dateStr, key, trials(k).steps, rootDir);
    end

    outDir = fullfile(rootDir, 'fig', 'EMG', sprintf('%s_%s', cfg.subject, cfg.dateStr));
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    %% 1. RMS bar
    % plotRMSBarByMuscle(cfg.subject, cfg.dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir);

    %% 2. Profile
    % std = false;
    % std = true;
    % lpfCutoffHz = 8;  % Profile plot(여러 step 평균)에 적용할 low-pass filter cutoff (Hz)
    % plotGaitCycleProfile(cfg.subject, cfg.dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir, lpfCutoffHz, cfg.affectedSide, std);

    %% 3. raw EMG
    % rawLpfCutoffHz = 8;  % Raw EMG step plot 위에 겹쳐 그릴, 가시성용으로 더 세게 거는 low-pass filter cutoff (Hz)
    % plotRawEMGStep(cfg.subject, cfg.dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir, cfg.affectedSide, rawLpfCutoffHz);

    %% 4. Peak timing
    % lpfCutoffHz = 8;
    % plotPeakTimingByMuscle(cfg.subject, cfg.dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir, lpfCutoffHz, cfg.affectedSide);

    %% 5. Raw EMG all steps overlay
    % rawLpfCutoffHz = 8;
    % VALID_PEAK_DELTA = 0.5;  % '유효 봉우리' RMS envelope max-min 고정 임계값
    % [validCounts, totalSteps] = plotRawEMGAll(cfg.subject, cfg.dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir, cfg.affectedSide, rawLpfCutoffHz, VALID_PEAK_DELTA);

    %% 6. Valid peak table (근육 x trial)
    % plotValidPeakTable(cfg.subject, cfg.dateStr, validCounts, totalSteps, trialKeys, muscleNames, sideNames, muscleFullNames, outDir, cfg.affectedSide);

    %% 7. Fatigue trend (trial 안 초반/중반/후반 RMS 변화)
    plotFatigueTrend(cfg.subject, cfg.dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir);

    %%
    fprintf('\n=== plotting complete: %s ===\n', outDir);
end
