function step03_generate_figures()
% STEP03_GENERATE_FIGURES  processed step 데이터를 읽어 figures/<subject>/<date>에 저장한다.
% 어떤 그림을 만들지는 scripts/config/pipeline_config.m의 figureOptions에서 선택한다.

clc; close all;
scriptDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(scriptDir);
addpath(fullfile(rootDir, 'src'));
addpath(fullfile(scriptDir, 'config'));

cfg = pipeline_config();
trialKeys = {cfg.trials.label};
opts = cfg.figureOptions;
needsEmg = opts.rmsBar || opts.gaitProfile || opts.rawEMGStep || opts.peakTiming || ...
    opts.rawEMGAll || opts.validPeakTable || opts.fatigueTrend;
needsMerged = opts.rawEMGWithAngle || opts.profileWithAngle;

for i = 1:numel(cfg.figureTargets)
    target = cfg.figureTargets(i);
    paths = getSubjectDatePaths(cfg.rootDir, target.subject, target.dateStr);
    outDir = fullfile(cfg.rootDir, 'figures', target.subject, target.dateStr);
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    if needsEmg
        trials = loadTrials(target, trialKeys, false, cfg.rootDir);

        if opts.rmsBar
            plotRMSBarByMuscle(target.subject, target.dateStr, trials, cfg.muscleNames, ...
                cfg.sideNames, cfg.muscleFullNames, outDir);
        end
        if opts.gaitProfile
            plotGaitCycleProfile(target.subject, target.dateStr, trials, cfg.muscleNames, ...
                cfg.sideNames, cfg.muscleFullNames, outDir, opts.lpfCutoffHz, ...
                target.affectedSide, opts.profileStd);
        end
        if opts.rawEMGStep
            plotRawEMGStep(target.subject, target.dateStr, trials, cfg.muscleNames, ...
                cfg.sideNames, cfg.muscleFullNames, outDir, target.affectedSide, opts.lpfCutoffHz);
        end
        if opts.peakTiming
            plotPeakTimingByMuscle(target.subject, target.dateStr, trials, cfg.muscleNames, ...
                cfg.sideNames, cfg.muscleFullNames, outDir, opts.lpfCutoffHz, target.affectedSide);
        end
        if opts.rawEMGAll || opts.validPeakTable
            [validCounts, totalSteps] = plotRawEMGAll(target.subject, target.dateStr, trials, ...
                cfg.muscleNames, cfg.sideNames, cfg.muscleFullNames, outDir, ...
                target.affectedSide, opts.lpfCutoffHz, opts.validPeakDelta);
            if opts.validPeakTable
                plotValidPeakTable(target.subject, target.dateStr, validCounts, totalSteps, ...
                    trialKeys, cfg.muscleNames, cfg.sideNames, cfg.muscleFullNames, ...
                    outDir, target.affectedSide);
            end
        end
        if opts.fatigueTrend
            plotFatigueTrend(target.subject, target.dateStr, trials, cfg.muscleNames, ...
                cfg.sideNames, cfg.muscleFullNames, outDir);
        end
    end

    if needsMerged
        if ~isfolder(paths.emgAfoStepsDir)
            error('generate_figures:missingMergedSteps', ...
                '%s/%s의 emg_afo_steps가 없습니다. 02_process_afo_merge를 먼저 실행하세요.', ...
                target.subject, target.dateStr);
        end
        mergedTrials = loadTrials(target, trialKeys, true, cfg.rootDir);
        if opts.rawEMGWithAngle
            plotRawEMGWithAngle(target.subject, target.dateStr, mergedTrials, cfg.muscleNames, ...
                cfg.sideNames, cfg.muscleFullNames, outDir, target.affectedSide, opts.lpfCutoffHz);
        end
        if opts.profileWithAngle
            plotGaitCycleProfileWithAngle(target.subject, target.dateStr, mergedTrials, ...
                cfg.muscleNames, cfg.sideNames, cfg.muscleFullNames, outDir, ...
                opts.lpfCutoffHz, target.affectedSide, 'Knee', opts.profileStd);
            plotGaitCycleProfileWithAngle(target.subject, target.dateStr, mergedTrials, ...
                cfg.muscleNames, cfg.sideNames, cfg.muscleFullNames, outDir, ...
                opts.lpfCutoffHz, target.affectedSide, 'Ankle', opts.profileStd);
        end
    end

    fprintf('=== figure generation complete: %s ===\n', outDir);
end
end

function trials = loadTrials(target, trialKeys, useMerged, rootDir)
trials = struct('name', {}, 'steps', {}, 'tables', {});
for k = 1:numel(trialKeys)
    key = trialKeys{k};
    trials(k).name = key;
    trials(k).steps = target.stepRange.(key);
    if useMerged
        trials(k).tables = loadTrialStepsMerged(target.subject, target.dateStr, key, ...
            trials(k).steps, rootDir);
    else
        trials(k).tables = loadTrialSteps(target.subject, target.dateStr, key, ...
            trials(k).steps, rootDir);
    end
end
end
