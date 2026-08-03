function plotPeakTimingByMuscle(subject, dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir, lpfCutoffHz, affectedSide)
% PLOTPEAKTIMINGBYMUSCLE  근육별로 trial(bare/P1/P2/P3)에 따른 activation
%   peak timing(affected side gait cycle %)의 mean/std를 비교한다.
%   step마다 lpfCutoffHz(Hz) 4th-order zero-phase low-pass filter(이웃 step
%   데이터로 padding, filtfiltStitched 참고)를 적용한 뒤, findpeaks로 그 step의
%   유의미한 봉우리(들)을 전부 찾는다(근육에 따라 한 gait cycle 안에 봉우리가
%   여러 개일 수 있어 global max 하나만 쓰지 않는다).
%   trial 안의 모든 step에서 찾은 봉우리 위치(%)를 모아 kernel density
%   estimate(gaussian, bandwidth=KDE_BANDWIDTH_PCT)를 구하고, 그 밀도 곡선의
%   극댓값(mode)들을 "진짜 봉우리 위치" 후보로 삼는다(개별 step의 노이즈성
%   부가 peak이 흩어져 있어도 density에는 잘 누적되지 않아 걸러짐; 단순히
%   정렬 후 간격으로 자르는 방식은 중간에 낀 소수의 노이즈 peak이 서로 다른
%   봉우리를 이어붙여버리는 문제가 있어 대신 이 방식을 쓴다).
%   각 mode 주변 CAPTURE_RADIUS_PCT 안의 step-peak들을 그 mode에 배정하고,
%   충분히 많은 step에서 지지되는(>= MIN_SUPPORT_FRAC) mode만 "진짜 봉우리"로
%   남겨 그 mean/std를 계산한다.
%   trial을 y축 카테고리로, gait cycle(%)을 x축(0~100 고정, 다른 plot과 동일)으로
%   두고, 각 step에서 검출된 개별 peak을 옅은 점으로(다봉성이 그대로 보이도록),
%   살아남은 mode마다 진한 마커+가로 error bar+텍스트로 mean±std를 그린다.
%   trials(k).name/.tables : trial 이름과 loadTrialSteps로 읽은 step 테이블 cell array
%   affectedSide : 'L' 또는 'R' — GaitCycle(x축)의 기준이 되는 affected side

FILTER_ORDER = 4;
PROMINENCE_FRAC = 0.2;    % step 신호 (max-min) 대비 이 비율 이상인 봉우리만 후보로 인정
KDE_BANDWIDTH_PCT = 4;    % 봉우리 위치 density 추정에 쓰는 gaussian kernel 표준편차(%)
MODE_MIN_DIST_PCT = 10;   % density mode끼리 최소 이 정도(%)는 떨어져 있어야 별개 봉우리
MODE_MIN_PROM_FRAC = 0.15;  % density 최댓값 대비 이 비율 이상인 mode만 후보로 인정
CAPTURE_RADIUS_PCT = 10;  % mode 주변 이 반경(%) 안의 step-peak을 그 mode에 배정
MIN_SUPPORT_FRAC = 0.4;   % mode로 인정할 최소 step 지지 비율
JITTER_AMP = 0.15;        % 배경 산점도의 row 안 세로 jitter 폭
GRID = 0:100;
nTrial = numel(trials);

Fs = 1 / mean(diff(trials(1).tables{1}.EMGTime));
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

    f = figure('Color', 'w', 'Position', [0 0 1200 800]);
    hold on;
    for t = 1:nTrial
        steps = trials(t).tables;
        nStep = numel(steps);

        allPct = [];
        allVal = [];
        allStepIdx = [];
        for s = 1:nStep
            yCur = steps{s}.(col);
            if s > 1
                yPrev = steps{s - 1}.(col);
            else
                yPrev = [];
            end
            if s < nStep
                yNext = steps{s + 1}.(col);
            else
                yNext = [];
            end
            yFilt = filtfiltStitched(filtB, filtA, yPrev, yCur, yNext, padLenTarget);

            rangeY = max(yFilt) - min(yFilt);
            [pkVal, pkIdx] = findpeaks(yFilt, 'MinPeakProminence', PROMINENCE_FRAC * rangeY);
            if isempty(pkVal)
                [pkVal, pkIdx] = max(yFilt);
            end
            pkPct = steps{s}.GaitCycle(pkIdx);

            allPct = [allPct; pkPct(:)]; %#ok<AGROW>
            allVal = [allVal; pkVal(:)]; %#ok<AGROW>
            allStepIdx = [allStepIdx; repmat(s, numel(pkPct), 1)]; %#ok<AGROW>
        end

        % 배경: step마다 검출된 개별 peak을 옅은 점으로 (다봉성이 그대로 드러나도록)
        jitter = (rand(size(allPct)) - 0.5) * 2 * JITTER_AMP;
        scatter(allPct, t + jitter, 20, colors(t, :), 'filled', ...
            'MarkerFaceAlpha', 0.3, 'MarkerEdgeColor', 'none', 'HandleVisibility', 'off');

        % 봉우리 위치들의 kernel density를 구해 극댓값(mode) = "진짜 봉우리" 후보를 찾는다.
        density = sum(exp(-0.5 * ((GRID - allPct) / KDE_BANDWIDTH_PCT) .^ 2), 1);
        [~, modePct] = findpeaks(density, GRID, ...
            'MinPeakDistance', MODE_MIN_DIST_PCT, 'MinPeakProminence', MODE_MIN_PROM_FRAC * max(density));
        if isempty(modePct)
            [~, maxIdx] = max(density);
            modePct = GRID(maxIdx);
        end

        for c = 1:numel(modePct)
            assigned = abs(allPct - modePct(c)) <= CAPTURE_RADIUS_PCT;
            assignedSteps = allStepIdx(assigned);
            assignedPct = allPct(assigned);
            assignedVal = allVal(assigned);

            uniqueSteps = unique(assignedSteps);
            if numel(uniqueSteps) / nStep < MIN_SUPPORT_FRAC
                continue  % 너무 적은 step에서만 지지되는 mode는 노이즈로 간주해 제외
            end

            % 같은 step이 이 mode에 peak을 여러 개 배정받은 경우, 가장 큰 값의
            % peak 하나만 대표로 남긴다(step 중복 반영 방지).
            repPct = zeros(numel(uniqueSteps), 1);
            for g = 1:numel(uniqueSteps)
                members = find(assignedSteps == uniqueSteps(g));
                [~, best] = max(assignedVal(members));
                repPct(g) = assignedPct(members(best));
            end

            meanPeak = mean(repPct);
            stdPeak = std(repPct);

            errorbar(meanPeak, t, stdPeak, 'horizontal', 'o', ...
                'Color', colors(t, :), 'MarkerFaceColor', colors(t, :), ...
                'MarkerSize', 10, 'LineWidth', 2, 'CapSize', 12);
            text(meanPeak, t - 0.25, sprintf('%.1f ± %.1f%%', meanPeak, stdPeak), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                'FontSize', 16, 'FontWeight', 'bold', 'Color', colors(t, :));
        end
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
