function [validCounts, totalSteps, validPeakDeltaByMuscle] = plotRawEMGAll(subject, dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir, affectedSide, lpfCutoffHz, minValidPeakDelta)
% PLOTRAWEMGALL  근육 x trial 하나당, 그 trial의 모든 step에 lpfCutoffHz(Hz)
%   4th-order zero-phase low-pass filter를 적용한 곡선을 한 plot에 step 시작
%   ~끝(gait cycle 0~100%)까지 전부 겹쳐 그린다(step이 70개면 선 70개).
%   filter padding은 plotRawEMGStep과 동일하게 같은 trial의 이웃 step 실측
%   데이터를 사용한다(filtfiltStitched 참고).
%   '유효 봉우리' 판정 기준은 그 step의 LPF 곡선에 moving-window RMS(window
%   길이 = MOVRMS_WINDOW_PCT% of gait cycle)를 적용해 얻은 RMS envelope의
%   최댓값-최솟값(max-min)이 minValidPeakDelta(고정값, 근육/trial 공통) 이상인지로
%   정한다(LPF 곡선 그대로의 max-min은 noisy한 step에서 단일 튀는 값에 취약하고,
%   step 전체 RMS 하나를 baseline으로 쓰면 그 RMS 자체가 봉우리 값을 포함해
%   같이 오염되는 문제가 있어, 그 사이 절충으로 짧은 구간 RMS envelope의
%   max-min을 쓴다).
%   trials(k).name/.steps/.tables : trial 이름, 실제 step 번호(cfg.stepRange), loadTrialSteps로 읽은 step 테이블
%   affectedSide : 'L' 또는 'R'
%
%   근육 x trial 하나당 png 1장 -> outDir/RawEMGAll/{trial}/RawEMGAll_{muscleCol}.png
%
%   validCounts(m,t)/totalSteps(t) : muscleNames{m}, trials(t)의 유효 봉우리 step
%   수/전체 step 수, validPeakDeltaByMuscle(m) : muscleNames{m}에 적용된 최종
%   임계값(plotValidPeakTable.m에서 근육x trial 표로 모아 그릴 때 재사용)

FILTER_ORDER = 4;
MOVRMS_WINDOW_PCT = 5;  % moving RMS window 길이 (gait cycle %) — burst 폭(~10~20% GC)보단
                        % 충분히 좁게, 샘플 노이즈는 눌러줄 만큼은 되도록
LINE_COLOR = [0 0.298 0.588];
LINE_ALPHA = 0.15;  % step이 많이 겹쳐도 밀도가 보이도록 옅게

Fs = 1 / mean(diff(trials(1).tables{1}.EMGTime));
[filtB, filtA] = butter(FILTER_ORDER, lpfCutoffHz / (Fs / 2), 'low');
padLenTarget = ceil(3 * Fs / lpfCutoffHz);

xAxisLabel = sprintf('Affected Side (%s) Gait Cycle (%%)', sideNames.(affectedSide));

nTrial = numel(trials);
nMuscle = numel(muscleNames);
totalCombos = nTrial * nMuscle;
comboIdx = 0;

validCounts = zeros(nMuscle, nTrial);
totalSteps = zeros(1, nTrial);
validPeakDeltaByMuscle = zeros(1, nMuscle);

for t = 1:nTrial
    totalSteps(t) = numel(trials(t).tables);
end

for m = 1:nMuscle
    col = muscleNames{m};
    parts = strsplit(col, '_');
    side = sideNames.(parts{1});
    muscle = muscleFullNames.(parts{2});

    % 1차: 이 근육의 모든 trial에 걸친 step별 RMS envelope (max-min)을 미리
    % 계산해 둔다 (filtfiltStitched를 두 번 돌리지 않도록 캐시).
    yFiltByTrial = cell(1, nTrial);
    rangeByTrial = cell(1, nTrial);
    for t = 1:nTrial
        steps = trials(t).tables;
        nStep = numel(steps);
        yFiltByTrial{t} = cell(nStep, 1);
        rangeByTrial{t} = zeros(nStep, 1);
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
            yFiltByTrial{t}{s} = yFilt;

            winSamples = max(1, round(MOVRMS_WINDOW_PCT / 100 * numel(yFilt)));
            rmsEnv = sqrt(movmean(yFilt .^ 2, winSamples));
            rangeByTrial{t}(s) = max(rmsEnv) - min(rmsEnv);
        end
    end

    validPeakDelta = minValidPeakDelta;
    validPeakDeltaByMuscle(m) = validPeakDelta;

    % 2차: 캐시해 둔 yFilt로 실제 plot + '유효 봉우리' step 수 집계
    for t = 1:nTrial
        trialOutDir = fullfile(outDir, 'RawEMGAll', trials(t).name);
        if ~exist(trialOutDir, 'dir')
            mkdir(trialOutDir);
        end

        steps = trials(t).tables;
        nStep = numel(steps);

        comboIdx = comboIdx + 1;
        fprintf('  [%s/%s] RawEMGAll (%d/%d) %s - %s: %d steps (valid peak threshold=%.2f) ...\n', ...
            subject, dateStr, comboIdx, totalCombos, trials(t).name, col, nStep, validPeakDelta);

        f = figure('Color', 'w', 'Position', [0 0 1200 800], 'Visible', 'off');
        hold on;
        validCount = 0;
        for s = 1:nStep
            x = steps{s}.GaitCycle;
            yFilt = yFiltByTrial{t}{s};

            if rangeByTrial{t}(s) >= validPeakDelta
                validCount = validCount + 1;
            end

            h = plot(x, yFilt, 'Color', LINE_COLOR, 'LineWidth', 1);
            h.Color(4) = LINE_ALPHA;  % 미문서화이지만 R2014b+에서 안정적으로 동작하는 line 투명도 지정 방법
        end
        hold off;

        validCounts(m, t) = validCount;

        set(gca, 'FontSize', 20);
        xlabel(xAxisLabel);
        ylabel('Normalized Muscle Activation');
        ylim([0 2]);
        xlim([0 100]);
        title(sprintf('%s(%s) - %s - %s %s (all steps, %g Hz LPF)', ...
            subject, dateStr, trials(t).name, side, muscle, lpfCutoffHz), 'FontSize', 24);
        text(2, 1.92, sprintf('Valid peak (RMS envelope max-min ≥ %.2f): %d/%d steps', ...
            validPeakDelta, validCount, nStep), ...
            'FontSize', 16, 'FontWeight', 'bold', 'VerticalAlignment', 'top', 'Color', [0.2 0.2 0.2]);

        saveas(f, fullfile(trialOutDir, sprintf('RawEMGAll_%s.png', col)));
        close(f);
    end
end
end
