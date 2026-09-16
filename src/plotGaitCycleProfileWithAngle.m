function plotGaitCycleProfileWithAngle(subject, dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir, lpfCutoffHz, affectedSide, jointType, showStdBand)
% PLOTGAITCYCLEPROFILEWITHANGLE  plotGaitCycleProfile과 동일한 근육 activation
%   mean profile을 위쪽 subplot에, 그 근육의 side(L/R)에 맞는 관절각(jointType=
%   'Knee'|'Ankle') mean profile을 아래쪽 subplot에 같은 gait cycle(%) x축을
%   공유해 함께 그린다. 관절각은 원래도 매끄러운 신호라 activation과 달리
%   별도 LPF는 적용하지 않고 step별로 공통 grid에 보간해 평균만 낸다.
%   trials(k).tables는 processed/emg_afo_steps/{trial}/step{N}.csv에서 읽은(=angle 컬럼
%   포함) 테이블이어야 한다(loadTrialStepsMerged 참고).
%   근육 하나당 png 1장 -> outDir/Profile_with{jointType}/Profile_{muscleCol}.png

if nargin < 11
    showStdBand = false;
end

GRID = 0:100;
FILTER_ORDER = 4;

Fs = 1 / mean(diff(trials(1).tables{1}.EMGTime));
[filtB, filtA] = butter(FILTER_ORDER, lpfCutoffHz / (Fs / 2), 'low');

colors = lines(numel(trials));  % RMS bar plot(plotRMSBarByMuscle.m)과 동일한 trial-색상 순서

sideWordMap.L = 'left';
sideWordMap.R = 'right';
jointLower = lower(jointType);

switch jointLower
    case 'knee'
        angleYLim = [-10 80];
    case 'ankle'
        angleYLim = [-30 30];
    otherwise
        error('plotGaitCycleProfileWithAngle:unknownJointType', ...
            'jointType는 ''Knee'' 또는 ''Ankle''이어야 합니다: %s', jointType);
end

profileOutDir = fullfile(outDir, ['Profile_with' jointType]);
if ~exist(profileOutDir, 'dir')
    mkdir(profileOutDir);
end

for m = 1:numel(muscleNames)
    col = muscleNames{m};
    parts = strsplit(col, '_');
    side = sideNames.(parts{1});
    muscle = muscleFullNames.(parts{2});
    angleCol = sprintf('%s_%s_angle', sideWordMap.(parts{1}), jointLower);

    f = figure('Color', 'w', 'Position', [0 0 1200 900]);

    subplot(2, 1, 1);
    hold on;
    for t = 1:numel(trials)
        steps = trials(t).tables;
        profiles = nan(numel(steps), numel(GRID));
        for s = 1:numel(steps)
            xFilt = filtfilt(filtB, filtA, steps{s}.(col));
            profiles(s, :) = interp1(steps{s}.GaitCycle, xFilt, GRID, 'linear', 'extrap');
        end
        meanProfile = mean(profiles, 1);
        if showStdBand
            stdProfile = std(profiles, 0, 1);
            fill([GRID, fliplr(GRID)], [meanProfile + stdProfile, fliplr(meanProfile - stdProfile)], ...
                colors(t, :), 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end
        plot(GRID, meanProfile, 'Color', colors(t, :), 'LineWidth', 2);
    end
    hold off;
    set(gca, 'FontSize', 20);
    ylabel('Normalized Muscle Activation');
    xlim([0 100]);
    ylim([-0.2 2]);
    legend({trials.name}, 'FontSize', 18, 'Location', 'best');

    subplot(2, 1, 2);
    hold on;
    for t = 1:numel(trials)
        steps = trials(t).tables;
        angleProfiles = nan(numel(steps), numel(GRID));
        for s = 1:numel(steps)
            angleProfiles(s, :) = interp1(steps{s}.GaitCycle, steps{s}.(angleCol), GRID, 'linear', 'extrap');
        end
        meanAngle = mean(angleProfiles, 1);
        if showStdBand
            stdAngle = std(angleProfiles, 0, 1);
            fill([GRID, fliplr(GRID)], [meanAngle + stdAngle, fliplr(meanAngle - stdAngle)], ...
                colors(t, :), 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end
        plot(GRID, meanAngle, 'Color', colors(t, :), 'LineWidth', 2);
    end
    hold off;
    set(gca, 'FontSize', 20);
    xlabel(sprintf('Affected Side (%s) Gait Cycle (%%)', sideNames.(affectedSide)));
    ylabel(sprintf('%s %s Angle (deg)', side, jointType));
    xlim([0 100]);
    ylim(angleYLim);

    sgtitle(sprintf('%s(%s) - %s %s', subject, dateStr, side, muscle), 'FontSize', 26);

    saveas(f, fullfile(profileOutDir, sprintf('Profile_%s.png', col)));
    close(f);
end
end
