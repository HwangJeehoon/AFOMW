function plotPeakTimingByMuscle(subject, dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir, lpfCutoffHz, affectedSide)
% PLOTPEAKTIMINGBYMUSCLE  근육별로 trial(bare/P1/P2/P3)에 따른 max activation
%   peak timing(affected side gait cycle %)의 mean/std를 비교한다.
%   step마다 lpfCutoffHz(Hz) 4th-order zero-phase low-pass filter(이웃 step
%   데이터로 padding, filtfiltStitched 참고)를 적용한 뒤, 단일 최댓값 샘플 하나는
%   noise에 취약하므로 값이 큰 상위 NUM_TOP_PEAKS개 샘플을 뽑아 그 값들을 가중치로
%   timing(GaitCycle)을 가중평균해 그 step의 peak timing으로 삼는다. trial별로
%   여러 step의 peak timing을 모아 mean/std를 낸다.
%   trial을 y축 카테고리로, gait cycle(%)을 x축(0~100 고정, 다른 plot과 동일)으로
%   두고 trial마다 mean에 점, std를 가로 error bar로 그린다.
%   trials(k).name/.tables : trial 이름과 loadTrialSteps로 읽은 step 테이블 cell array
%   affectedSide : 'L' 또는 'R' — GaitCycle(x축)의 기준이 되는 affected side

FILTER_ORDER = 4;
NUM_TOP_PEAKS = 10;  % 값이 큰 상위 몇 개 샘플을 가중평균에 쓸지
nTrial = numel(trials);

Fs = 1 / mean(diff(trials(1).tables{1}.Time));
[filtB, filtA] = butter(FILTER_ORDER, lpfCutoffHz / (Fs / 2), 'low');
padLenTarget = ceil(3 * Fs / lpfCutoffHz);

colors = lines(nTrial);  % Profile/RMS bar plot과 동일한 trial-색상 순서

peakOutDir = fullfile(outDir, 'PeakTiming');
if ~exist(peakOutDir, 'dir')
    mkdir(peakOutDir);
end

for m = 1:numel(muscleNames)
    col = muscleNames{m};
    parts = strsplit(col, '_');
    side = sideNames.(parts{1});
    muscle = muscleFullNames.(parts{2});

    meanPeak = zeros(1, nTrial);
    stdPeak = zeros(1, nTrial);
    for t = 1:nTrial
        steps = trials(t).tables;
        peakPct = zeros(numel(steps), 1);
        for s = 1:numel(steps)
            yCur = steps{s}.(col);
            if s > 1
                yPrev = steps{s - 1}.(col);
            else
                yPrev = [];
            end
            if s < numel(steps)
                yNext = steps{s + 1}.(col);
            else
                yNext = [];
            end
            yFilt = filtfiltStitched(filtB, filtA, yPrev, yCur, yNext, padLenTarget);

            [sortedVals, sortedIdx] = sort(yFilt, 'descend');
            topN = min(NUM_TOP_PEAKS, numel(sortedVals));
            topVals = sortedVals(1:topN);
            topPct = steps{s}.GaitCycle(sortedIdx(1:topN));
            peakPct(s) = sum(topVals .* topPct) / sum(topVals);
        end
        meanPeak(t) = mean(peakPct);
        stdPeak(t) = std(peakPct);
    end

    f = figure('Color', 'w', 'Position', [0 0 1200 800]);
    hold on;
    for t = 1:nTrial
        errorbar(meanPeak(t), t, stdPeak(t), 'horizontal', 'o', ...
            'Color', colors(t, :), 'MarkerFaceColor', colors(t, :), ...
            'MarkerSize', 10, 'LineWidth', 2, 'CapSize', 12);
        text(meanPeak(t), t - 0.25, sprintf('%.1f ± %.1f%%', meanPeak(t), stdPeak(t)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'FontSize', 16, 'FontWeight', 'bold', 'Color', colors(t, :));
    end
    hold off;

    set(gca, 'YTick', 1:nTrial, 'YTickLabel', {trials.name}, 'YDir', 'reverse', 'FontSize', 25);
    ylim([0.5, nTrial + 0.5]);
    xlim([0 100]);
    xlabel(sprintf('Affected Side (%s) Gait Cycle (%%)', sideNames.(affectedSide)));
    title(sprintf('%s(%s) - %s %s Peak Timing', subject, dateStr, side, muscle), 'FontSize', 30);

    saveas(f, fullfile(peakOutDir, sprintf('PeakTiming_%s.png', col)));
end
end
