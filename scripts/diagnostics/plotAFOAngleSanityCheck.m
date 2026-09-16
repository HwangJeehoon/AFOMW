function plotAFOAngleSanityCheck(subject, dateStr, stepNum, rootDir)
% PLOTAFOANGLESANITYCHECK  한 step의 AFO 관절각을 trial별로 겹쳐 육안 확인한다.
% 예: plotAFOAngleSanityCheck('SAH01', '260706', 10)

if nargin < 4 || isempty(rootDir)
    scriptDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(fileparts(scriptDir));
end
addpath(fullfile(rootDir, 'src'));
addpath(fullfile(fileparts(scriptDir), 'config'));
cfg = pipeline_config();

if nargin < 1 || isempty(subject)
    subject = cfg.targets(1).subject;
end
if nargin < 2 || isempty(dateStr)
    dateStr = cfg.targets(1).dateStr;
end
if nargin < 3 || isempty(stepNum)
    stepNum = 10;
end

targetIdx = find(strcmp({cfg.targets.subject}, subject) & ...
    strcmp({cfg.targets.dateStr}, dateStr), 1);
if isempty(targetIdx)
    error('plotAFOAngleSanityCheck:unknownTarget', ...
        '%s/%s가 scripts/config/pipeline_config.m의 targets에 없습니다.', subject, dateStr);
end
target = cfg.targets(targetIdx);
paths = getSubjectDatePaths(rootDir, subject, dateStr);

syncPath = fullfile(paths.syncDir, sprintf('syncEMG_%s_%s.csv', subject, dateStr));
syncTable = readtable(syncPath, 'TextType', 'string');
syncMap = containers.Map(cellstr(lower(strtrim(syncTable.Trial))), num2cell(syncTable.Time));

jointNames = {'left_hip_angle', 'left_knee_angle', 'left_ankle_angle', ...
    'right_hip_angle', 'right_knee_angle', 'right_ankle_angle'};
jointTitles = {'Left Hip', 'Left Knee', 'Left Ankle', ...
    'Right Hip', 'Right Knee', 'Right Ankle'};
colors = {[0.45 0.45 0.45], [0 0.45 0.74], [0.85 0.33 0.10], [0.47 0.67 0.19]};

fig = figure('Name', sprintf('%s %s - step %d sanity check', subject, dateStr, stepNum), ...
    'Position', [100 100 1400 800]);
tl = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = gobjects(1, numel(jointNames));
for j = 1:numel(jointNames)
    ax(j) = nexttile(tl);
    hold(ax(j), 'on'); grid(ax(j), 'on');
    title(ax(j), jointTitles{j}, 'Interpreter', 'none');
    xlabel(ax(j), 'Gait cycle (%)'); ylabel(ax(j), 'Angle (deg)');
    yline(ax(j), 0, ':', 'Color', [0.6 0.6 0.6], 'HandleVisibility', 'off');
end

legendHandles = gobjects(1, numel(cfg.trials));
legendOk = false(1, numel(cfg.trials));
for i = 1:numel(cfg.trials)
    trial = cfg.trials(i);
    try
        bagPath = fullfile(paths.afoRawDir, trial.bagFile);
        emgPath = fullfile(paths.emgRawDir, trial.emgFile);
        gaitPath = fullfile(paths.syncDir, sprintf('gaitCycle_%s_%s_%s.csv', ...
            subject, dateStr, trial.gaitSuffix));
        header = parseEMGHeader(emgPath);
        windows = extractCycleWindows(gaitPath, syncMap(trial.key), target.gaitPct, header.collectionLength);
        if isempty(windows)
            warning('plotAFOAngleSanityCheck:noWindow', '%s: 유효한 gait cycle이 없습니다.', trial.label);
            continue
        end

        angleTable = computeAFOJointAngles(bagPath, ...
            [windows(1).startRel, windows(end).endRel] + syncMap(trial.key));
        cycles = cutAngleCycles(angleTable, gaitPath, syncMap(trial.key), target.gaitPct, header.collectionLength);
        useStep = min(stepNum, numel(cycles));
        if useStep < stepNum
            warning('plotAFOAngleSanityCheck:stepOutOfRange', ...
                '%s: step %d 대신 마지막 step %d를 사용합니다.', trial.label, stepNum, useStep);
        end
        stepTable = cycles{useStep};

        trialHasLine = false;
        for j = 1:numel(jointNames)
            if ~ismember(jointNames{j}, stepTable.Properties.VariableNames)
                continue
            end
            h = plot(ax(j), stepTable.GaitCycle, stepTable.(jointNames{j}), ...
                'Color', colors{i}, 'LineWidth', 1.6, 'DisplayName', trial.label);
            trialHasLine = true;
        end
        if trialHasLine
            legendHandles(i) = h;
            legendOk(i) = true;
        else
            warning('plotAFOAngleSanityCheck:noJointColumns', ...
                '%s: 예상한 관절각 컬럼이 없습니다.', trial.label);
        end
    catch exception
        warning('plotAFOAngleSanityCheck:trialFailed', '%s 처리 중 오류: %s', ...
            trial.label, exception.message);
    end
end

if any(legendOk)
    legend(ax(1), legendHandles(legendOk), 'Location', 'best');
end
title(tl, sprintf('%s / %s - step %d', subject, dateStr, stepNum), 'Interpreter', 'none');
end
