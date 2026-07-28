function plotGaitCycleProfile(subject, dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir, lpfCutoffHz)
% PLOTGAITCYCLEPROFILE  근육별로 trial(bare/P1/P2/P3)의 gait cycle mean profile을 그린다.
%   각 step의 activation에 lpfCutoffHz(Hz) 4th-order zero-phase low-pass filter를
%   적용한 뒤, (GaitCycle, activation)을 공통 grid(0:100%)에 보간해 step들을 평균한다.
%   trials(k).name/.tables : trial 이름과 loadTrialSteps로 읽은 step 테이블 cell array

GRID = 0:100;
FILTER_ORDER = 4;

Fs = 1 / mean(diff(trials(1).tables{1}.Time));
[filtB, filtA] = butter(FILTER_ORDER, lpfCutoffHz / (Fs / 2), 'low');

colors = lines(numel(trials));  % RMS bar plot(plotRMSBarByMuscle.m)과 동일한 trial-색상 순서

for m = 1:numel(muscleNames)
    col = muscleNames{m};
    parts = strsplit(col, '_');
    side = sideNames.(parts{1});
    muscle = muscleFullNames.(parts{2});

    f = figure('Color', 'w', 'Position', [0 0 1200 800]);
    hold on;
    for t = 1:numel(trials)
        steps = trials(t).tables;
        profiles = nan(numel(steps), numel(GRID));
        for s = 1:numel(steps)
            xFilt = filtfilt(filtB, filtA, steps{s}.(col));
            profiles(s, :) = interp1(steps{s}.GaitCycle, xFilt, GRID, 'linear', 'extrap');
        end
        plot(GRID, mean(profiles, 1), 'Color', colors(t, :), 'LineWidth', 2);
    end
    hold off;

    set(gca, 'FontSize', 25);
    xlabel(sprintf('Left Gait Cycle (%%)'));
    ylabel('Normalized Muscle Activation');
    xlim([0 100]);
    title(sprintf('%s(%s) - %s %s', subject, dateStr, side, muscle), 'FontSize', 30);
    legend({trials.name}, 'FontSize', 30, 'Location', 'best');

    saveas(f, fullfile(outDir, sprintf('Profile_%s.png', col)));
end
end
