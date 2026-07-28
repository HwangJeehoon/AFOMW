function plotRawEMGStep(subject, dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir, affectedSide, lpfCutoffHz)
% PLOTRAWEMGSTEP  근육별로, trial의 step 하나하나에 대해 raw activation(연하게)과
%   그 위에 겹친 lpfCutoffHz(Hz) low-pass filter 결과(진하게)를 그린다.
%   step 간 평균은 하지 않고 step 하나의 시계열을 그대로 보여준다(가시성 위해 filter만 적용).
%   filter padding은 가능하면 같은 trial의 이웃 step(실제 이어진 EMG)을 사용해
%   0%/100% 경계에서 왜곡을 줄인다(filtfiltStitched 참고).
%   x축은 (그리는 muscle의 side와 무관하게) 항상 affectedSide의 gait cycle(%)이고
%   0~100%, y축은 0~2로 고정해 step/근육 간에 동일한 스케일로 비교할 수 있게 한다.
%   (EMG_processed 단계(processTrialCycles의 realignToTrueCycles)에서 이미 각
%   step이 진짜 0~100% 한 사이클을 연속적으로 담도록 잘라놓았으므로 여기서 별도
%   wrap 처리는 하지 않는다.)
%   trials(k).name/.steps/.tables : trial 이름, 실제 step 번호(cfg.stepRange), loadTrialSteps로 읽은 step 테이블
%   affectedSide : 'L' 또는 'R'
%
%   근육 하나 x step 하나당 png 1장 -> outDir/RawEMG/{trial}/{muscleCol}/step{N}.png

FILTER_ORDER = 4;
RAW_COLOR = [0.6 0.6 0.6];
RAW_ALPHA = 0.35;  % raw를 filtered보다 흐리게 보이도록 하는 투명도
FILT_COLOR = [0 0.298 0.588];

Fs = 1 / mean(diff(trials(1).tables{1}.Time));
[filtB, filtA] = butter(FILTER_ORDER, lpfCutoffHz / (Fs / 2), 'low');

% filtfilt 기본 padding(계수 개수 x 3, 몇 샘플 안 됨)은 lpfCutoffHz처럼 매우 낮은
% cutoff에서는 필터가 정착하기에 턱없이 부족해 step 양 끝에서 값이 왜곡된다.
% 필터의 시간상수(~Fs/cutoff)에 비례해 padding을 직접 늘려서 이를 방지한다.
padLenTarget = ceil(3 * Fs / lpfCutoffHz);

xAxisLabel = sprintf('Affected Side (%s) Gait Cycle (%%)', sideNames.(affectedSide));

for m = 1:numel(muscleNames)
    col = muscleNames{m};
    parts = strsplit(col, '_');
    side = sideNames.(parts{1});
    muscle = muscleFullNames.(parts{2});

    for t = 1:numel(trials)
        steps = trials(t).tables;
        stepNums = trials(t).steps;
        muscleOutDir = fullfile(outDir, 'RawEMG', trials(t).name, col);
        if ~exist(muscleOutDir, 'dir')
            mkdir(muscleOutDir);
        end

        for s = 1:numel(steps)
            Ttab = steps{s};
            x = Ttab.GaitCycle;
            yRaw = Ttab.(col);

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
            yFilt = filtfiltStitched(filtB, filtA, yPrev, yRaw, yNext, padLenTarget);

            f = figure('Color', 'w', 'Position', [0 0 1200 800], 'Visible', 'off');
            hold on;
            hRaw = plot(x, yRaw, 'Color', RAW_COLOR, 'LineWidth', 1);
            hRaw.Color(4) = RAW_ALPHA;  % 미문서화이지만 R2014b+에서 안정적으로 동작하는 line 투명도 지정 방법
            plot(x, yFilt, 'Color', FILT_COLOR, 'LineWidth', 2.2);
            hold off;

            set(gca, 'FontSize', 20);
            xlabel(xAxisLabel);
            ylabel('Normalized Muscle Activation');
            ylim([0 2])
            xlim([0 100]);
            title(sprintf('%s(%s) - %s step%d - %s %s', subject, dateStr, trials(t).name, stepNums(s), side, muscle), 'FontSize', 24);
            legend({'Raw', sprintf('%g Hz LPF', lpfCutoffHz)}, 'FontSize', 16, 'Location', 'best');

            saveas(f, fullfile(muscleOutDir, sprintf('step%d.png', stepNums(s))));
            close(f);
        end
    end
end
end

function yFilt = filtfiltStitched(filtB, filtA, yPrev, yCur, yNext, padLenTarget)
% FILTFILTSTITCHED  filtfilt 전에 step 경계 양쪽에 (가능하면) 이웃 step의 실제
%   EMG 데이터를 이어붙여 패딩한 뒤 필터링하고, 다시 이 step 길이만큼만 잘라
%   반환한다. realignToTrueCycles(processTrialCycles.m)로 같은 trial 안에서는
%   인접 step끼리 시간이 끊김 없이 이어지므로, 합성 반사(odd-reflection) 패딩
%   대신 진짜 이웃 데이터를 쓰면 gait cycle 경계(0%/100%)에서 필터가 왜곡 없이
%   정착한다. 이웃 step이 없는 trial 맨 처음/마지막 step만 odd-reflection으로
%   대체한다.

n = numel(yCur);

if ~isempty(yPrev)
    padLenL = min(padLenTarget, numel(yPrev));
    leftPad = yPrev(end - padLenL + 1:end);
else
    padLenL = min(padLenTarget, n - 1);
    leftPad = 2 * yCur(1) - yCur(padLenL + 1:-1:2);
end

if ~isempty(yNext)
    padLenR = min(padLenTarget, numel(yNext));
    rightPad = yNext(1:padLenR);
else
    padLenR = min(padLenTarget, n - 1);
    rightPad = 2 * yCur(end) - yCur(end - 1:-1:end - padLenR);
end

yPadded = [leftPad; yCur; rightPad];
yFiltPadded = filtfilt(filtB, filtA, yPadded);
yFilt = yFiltPadded(padLenL + 1:padLenL + n);
end
