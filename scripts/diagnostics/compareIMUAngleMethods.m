function compareIMUAngleMethods(subject, dateStr, trialKey, stepNum)
% COMPAREIMUANGLEMETHODS  computeAFOJointAngles(quaternion functional-hinge
% twist)와 computeAFOJointAnglesSagittal(limb 방향벡터 sagittal 투영, pitch축
% =limb 방향 가정)을 같은 bag/step에 대해 계산해 겹쳐 그리고, 상관계수·부호
% 정렬 후 RMS 차이를 출력하는 간단 비교 스크립트.
%   예: compareIMUAngleMethods('SAH01', '260706', 'bare', 10)

if nargin < 4 || isempty(stepNum)
    stepNum = 10;
end

scriptDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(scriptDir));
addpath(fullfile(rootDir, 'src'));
addpath(fullfile(rootDir, 'scripts', 'config'));
cfg = pipeline_config();

targetIdx = find(strcmp({cfg.targets.subject}, subject) & strcmp({cfg.targets.dateStr}, dateStr), 1);
if isempty(targetIdx)
    error('compareIMUAngleMethods:unknownTarget', '%s/%s가 pipeline_config targets에 없습니다.', subject, dateStr);
end
target = cfg.targets(targetIdx);
paths = getSubjectDatePaths(rootDir, subject, dateStr);

trial = cfg.trials(strcmp({cfg.trials.key}, trialKey));
if isempty(trial)
    error('compareIMUAngleMethods:unknownTrial', '알 수 없는 trial key: %s', trialKey);
end

syncPath = fullfile(paths.syncDir, sprintf('syncEMG_%s_%s.csv', subject, dateStr));
syncTable = readtable(syncPath, 'TextType', 'string');
syncMap = containers.Map(cellstr(lower(strtrim(syncTable.Trial))), num2cell(syncTable.Time));
trigger = syncMap(trial.key);

bagPath = fullfile(paths.afoRawDir, trial.bagFile);
emgPath = fullfile(paths.emgRawDir, trial.emgFile);
gaitPath = fullfile(paths.syncDir, sprintf('gaitCycle_%s_%s_%s.csv', subject, dateStr, trial.gaitSuffix));

header = parseEMGHeader(emgPath);
windows = extractCycleWindows(gaitPath, trigger, target.gaitPct, header.collectionLength);
functionalTimeRange = [windows(1).startRel, windows(end).endRel] + trigger;

fprintf('=== %s/%s/%s (functional window %.1f~%.1fs, %d gait cycles) ===\n', ...
    subject, dateStr, trial.label, functionalTimeRange(1) - trigger, functionalTimeRange(2) - trigger, numel(windows));

angleTableHinge = computeAFOJointAngles(bagPath, functionalTimeRange);
angleTableSag = computeAFOJointAnglesSagittal(bagPath, functionalTimeRange);

cyclesHinge = cutAngleCycles(angleTableHinge, gaitPath, trigger, target.gaitPct, header.collectionLength);
cyclesSag = cutAngleCycles(angleTableSag, gaitPath, trigger, target.gaitPct, header.collectionLength);
useStep = min(stepNum, min(numel(cyclesHinge), numel(cyclesSag)));
stepHinge = cyclesHinge{useStep};
stepSag = cyclesSag{useStep};

jointNames = angleTableHinge.Properties.VariableNames(2:end);
jointTitles = {'Left Hip', 'Left Knee', 'Left Ankle', 'Right Hip', 'Right Knee', 'Right Ankle'};

fig = figure('Name', sprintf('%s/%s/%s step%d: hinge-twist vs sagittal-projection', subject, dateStr, trial.label, useStep), ...
    'Position', [100 100 1400 800]);
tl = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

fprintf('%-16s  %8s  %10s  %10s  %10s\n', 'joint', 'corr', 'signAlign', 'RMSdiff(deg)', 'note');
for j = 1:numel(jointNames)
    ax = nexttile(tl);
    hold(ax, 'on'); grid(ax, 'on');
    title(ax, jointTitles{j}, 'Interpreter', 'none');
    xlabel(ax, 'Gait cycle (%)'); ylabel(ax, 'Angle (deg)');
    yline(ax, 0, ':', 'Color', [0.6 0.6 0.6], 'HandleVisibility', 'off');

    hingeVal = stepHinge.(jointNames{j});
    sagVal = stepSag.(jointNames{j});

    c = corr(hingeVal, sagVal);
    signAlign = sign(c);
    sagValAligned = signAlign * sagVal;
    rmsDiff = sqrt(mean((hingeVal - sagValAligned).^2));

    plot(ax, stepHinge.GaitCycle, hingeVal, 'Color', [0 0.45 0.74], 'LineWidth', 1.6, 'DisplayName', 'hinge-twist(기존)');
    plot(ax, stepSag.GaitCycle, sagValAligned, 'Color', [0.85 0.33 0.10], 'LineWidth', 1.6, 'LineStyle', '--', ...
        'DisplayName', sprintf('sagittal-proj(신규, %s)', tern(signAlign < 0, '부호반전', '부호동일')));
    if j == 1
        legend(ax, 'Location', 'best');
    end

    fprintf('%-16s  %+8.3f  %10d  %10.2f\n', jointNames{j}, c, signAlign, rmsDiff);
end
title(tl, sprintf('%s/%s/%s step%d', subject, dateStr, trial.label, useStep), 'Interpreter', 'none');
end

function s = tern(cond, a, b)
if cond; s = a; else; s = b; end
end
