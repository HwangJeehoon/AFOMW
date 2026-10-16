function plotGaitCycleProfileBilateral(subject, dateStr, trials, sideNames, muscleFullNames, outDir, affectedSide, showStdBand)
% PLOTGAITCYCLEPROFILEBILATERAL  근육 activation, 관절각(hip/knee/ankle), vGRF, CoP의
%   gait cycle mean profile을 trial(bare/P1/P2/P3)별로 비교한다. 한 plot에 환측(실선)과
%   건측(점선)을 함께 그리며, x축은 둘 다 환측 gait cycle(GaitCycle_afo)이다.
%   (건측은 같은 시간축에 그대로 놓이므로 환측 대비 약 50% 밀려 보인다.)
%   emg_afo_mw_steps의 EMG는 이미 LPF된 값이라 별도 필터 없이 step별로 공통 grid에
%   보간해 평균만 낸다.
%   trials(k).tables는 loadTrialStepsMW로 읽은 테이블이어야 한다.
%   신호 하나당 png 1장 -> outDir/Profile_bilateral/Profile_{signal}.png

if nargin < 8
    showStdBand = false;
end

GRID = 0:100;

colors = lines(numel(trials));  % RMS bar plot(plotRMSBarByMuscle.m)과 동일한 trial-색상 순서

if strcmp(affectedSide, 'L')
    sides = {'L', 'R'};
else
    sides = {'R', 'L'};
end
lineStyles = {'-', '--'};
roleNames = {'Affected', 'Unaffected'};

% {컬럼 이름(L_/R_ 뒤), 제목, y축 이름, y축 범위}
muscles = fieldnames(muscleFullNames);
signals = [
    muscles, struct2cell(muscleFullNames), ...
        repmat({'Normalized Muscle Activation', [-0.2 2]}, numel(muscles), 1)
    {'hip_angle',   'Hip Angle',   'Hip Angle (deg)',           [-20 60]
     'knee_angle',  'Knee Angle',  'Knee Angle (deg)',          [-30 80]
     'ankle_angle', 'Ankle Angle', 'Ankle Angle (deg)',         [-30 30]
     'vGRF',        'vGRF',        'vGRF',                      [-20 100]
     'CoP',         'CoP',         'CoP (0 = rear, 1 = front)', [0 1]}];

profileOutDir = fullfile(outDir, 'Profile_bilateral');
if ~exist(profileOutDir, 'dir')
    mkdir(profileOutDir);
end

for g = 1:size(signals, 1)
    [base, titleName, yLabelStr, yLimits] = signals{g, :};

    f = figure('Color', 'w', 'Position', [0 0 1200 800]);
    hold on;
    legendNames = {};
    for k = 1:2
        col = sprintf('%s_%s', sides{k}, base);
        for t = 1:numel(trials)
            steps = trials(t).tables;
            profiles = nan(numel(steps), numel(GRID));
            for s = 1:numel(steps)
                profiles(s, :) = interp1(steps{s}.GaitCycle_afo, steps{s}.(col), GRID, 'linear', 'extrap');
            end
            meanProfile = mean(profiles, 1);
            if showStdBand
                stdProfile = std(profiles, 0, 1);
                fill([GRID, fliplr(GRID)], [meanProfile + stdProfile, fliplr(meanProfile - stdProfile)], ...
                    colors(t, :), 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
            end
            plot(GRID, meanProfile, lineStyles{k}, 'Color', colors(t, :), 'LineWidth', 2);
            legendNames{end + 1} = sprintf('%s %s (%s)', trials(t).name, roleNames{k}, ...
                sideNames.(sides{k})); %#ok<AGROW>
        end
    end
    hold off;

    set(gca, 'FontSize', 25);
    xlabel(sprintf('Affected Side (%s) Gait Cycle (%%)', sideNames.(affectedSide)));
    ylabel(yLabelStr);
    xlim([0 100]);
    ylim(yLimits);
    title(sprintf('%s(%s) - %s', subject, dateStr, titleName), 'FontSize', 30);
    legend(legendNames, 'FontSize', 16, 'NumColumns', 2, 'Location', 'best');

    saveas(f, fullfile(profileOutDir, sprintf('Profile_%s.png', base)));
    close(f);
end
end
