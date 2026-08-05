function plotFatigueTrend(subject, dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir)
% PLOTFATIGUETREND  근육별로, 각 trial 안에서 step을 시간 순서대로 초반/중반/
%   후반 3등분한 뒤 구간별 RMS(step별 sqrt(mean(x.^2))의 mean/std, RMS bar
%   plot과 동일한 정의)가 어떻게 변하는지 line plot으로 그린다.
%   x축 = phase(Early/Mid/Late), y축 = RMS, trial(bare/P1/P2/P3)별로 선 하나씩
%   (다른 plot과 동일한 trial 색상) + error bar. 각 선 끝에 Early 대비 Late
%   변화율(%)을 텍스트로 표시해 피로 경향을 한눈에 비교한다.
%   trials(k).name/.tables : trial 이름과 loadTrialSteps로 읽은 step 테이블 cell array
%
%   근육 하나당 png 1장 -> outDir/Fatigue/Fatigue_{muscleCol}.png

PHASE_LABELS = {'Early', 'Mid', 'Late'};
nPhase = numel(PHASE_LABELS);
nTrial = numel(trials);
colors = lines(nTrial);  % 다른 plot들과 동일한 trial-색상 순서

fatigueOutDir = fullfile(outDir, 'Fatigue');
if ~exist(fatigueOutDir, 'dir')
    mkdir(fatigueOutDir);
end

for m = 1:numel(muscleNames)
    col = muscleNames{m};
    parts = strsplit(col, '_');
    side = sideNames.(parts{1});
    muscle = muscleFullNames.(parts{2});

    f = figure('Color', 'w', 'Position', [0 0 1200 800]);
    hold on;
    for t = 1:nTrial
        steps = trials(t).tables;
        nStep = numel(steps);
        edges = round(linspace(0, nStep, nPhase + 1));  % step 개수가 3의 배수가 아니어도 균등 분배

        phaseMeanRMS = zeros(1, nPhase);
        phaseStdRMS = zeros(1, nPhase);
        for p = 1:nPhase
            phaseSteps = edges(p) + 1:edges(p + 1);
            rmsVals = zeros(numel(phaseSteps), 1);
            for i = 1:numel(phaseSteps)
                x = steps{phaseSteps(i)}.(col);
                rmsVals(i) = sqrt(mean(x .^ 2));
            end
            phaseMeanRMS(p) = mean(rmsVals);
            phaseStdRMS(p) = std(rmsVals);
        end

        errorbar(1:nPhase, phaseMeanRMS, phaseStdRMS, '-o', ...
            'Color', colors(t, :), 'MarkerFaceColor', colors(t, :), ...
            'LineWidth', 2, 'MarkerSize', 8, 'CapSize', 10, 'DisplayName', trials(t).name);

        pctChange = (phaseMeanRMS(end) - phaseMeanRMS(1)) / phaseMeanRMS(1) * 100;
        text(nPhase + 0.08, phaseMeanRMS(end), sprintf('%+.1f%%', pctChange), ...
            'FontSize', 14, 'FontWeight', 'bold', 'Color', colors(t, :), ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
    end
    hold off;

    set(gca, 'XTick', 1:nPhase, 'XTickLabel', PHASE_LABELS, 'FontSize', 25);
    xlim([0.7, nPhase + 0.9]);  % 변화율(%) 텍스트가 들어갈 여백
    ylabel('Normalized Muscle Activation (RMS)');
    legend('Location', 'best');
    title(sprintf('%s(%s) - %s %s Fatigue Trend', subject, dateStr, side, muscle), 'FontSize', 30);

    saveas(f, fullfile(fatigueOutDir, sprintf('Fatigue_%s.png', col)));
end
end
