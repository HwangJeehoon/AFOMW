function plotRMSBarByMuscle(subject, dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir)
% PLOTRMSBARBYMUSCLE  근육별로 trial(bare/P1/P2/P3)에 따른 RMS를 bar plot으로 그린다.
%   bar 높이 = 선택한 step들의 step별 RMS 평균, error bar = 1 표준편차.
%   bare 대비 변화율(%)을 P1/P2/P3 막대 위에 텍스트로 표시한다.
%   trials(k).name/.tables : trial 이름과 loadTrialSteps로 읽은 step 테이블 cell array

nTrial = numel(trials);
bareIdx = find(strcmp({trials.name}, 'bare'), 1);

for m = 1:numel(muscleNames)
    col = muscleNames{m};
    parts = strsplit(col, '_');
    side = sideNames.(parts{1});
    muscle = muscleFullNames.(parts{2});

    meanRMS = zeros(1, nTrial);
    stdRMS = zeros(1, nTrial);
    for t = 1:nTrial
        steps = trials(t).tables;
        rmsVals = zeros(numel(steps), 1);
        for s = 1:numel(steps)
            x = steps{s}.(col);
            rmsVals(s) = sqrt(mean(x .^ 2));
        end
        meanRMS(t) = mean(rmsVals);
        stdRMS(t) = std(rmsVals);
    end

    f = figure('Color', 'w', 'Position', [0 0 1200 800]);
    bar(meanRMS);
    hold on;
    errorbar(1:nTrial, meanRMS, stdRMS, 'k', 'LineStyle', 'none', 'LineWidth', 1.5);

    for t = 1:nTrial
        if t == bareIdx
            continue
        end
        pctChange = (meanRMS(t) - meanRMS(bareIdx)) / meanRMS(bareIdx) * 100;
        text(t, meanRMS(t) + stdRMS(t), sprintf('%+.1f%%', pctChange), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 20);
    end
    hold off;

    set(gca, 'XTick', 1:nTrial, 'XTickLabel', {trials.name}, 'FontSize', 25);
    ylabel('RMS (a.u.)');
    title(sprintf('%s(%s) - %s %s RMS', subject, dateStr, side, muscle), 'FontSize', 30);

    saveas(f, fullfile(outDir, sprintf('RMS_%s.png', col)));
end
end
