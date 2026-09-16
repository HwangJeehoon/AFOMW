function plotRawEMGWithAngle(subject, dateStr, trials, muscleNames, sideNames, muscleFullNames, outDir, affectedSide, lpfCutoffHz)
% PLOTRAWEMGWITHANGLE  plotRawEMGStep과 동일한 raw+LPF EMG를 위쪽 subplot에,
%   그 근육의 side(L/R)에 맞는 무릎/발목 관절각(L_*면 left_knee_angle과
%   left_ankle_angle, R_*면 right_knee_angle과 right_ankle_angle)을 아래쪽
%   subplot에 hold on으로 함께 그린다. x축은 같은 gait cycle(%)을 공유한다.
%   관절각은 원래도 매끄러운 신호라 별도 LPF 없이 그대로 그린다.
%   trials(k).tables는 processed/emg_afo_steps/{trial}/step{N}.csv에서 읽은(=angle 컬럼
%   포함) 테이블이어야 한다(loadTrialStepsMerged 참고).
%   근육 하나 x step 하나당 png 1장 -> outDir/RawEMG_Angle/{trial}/{muscleCol}/step{N}.png

FILTER_ORDER = 4;
RAW_COLOR = [0.6 0.6 0.6];
RAW_ALPHA = 0.35;  % raw를 filtered보다 흐리게 보이도록 하는 투명도
FILT_COLOR = [0 0.298 0.588];
KNEE_COLOR = [0.85 0.325 0.098];
ANKLE_COLOR = [0.466 0.674 0.188];
ANGLE_YLIM = [-30 80];

sideWordMap.L = 'left';
sideWordMap.R = 'right';

Fs = 1 / mean(diff(trials(1).tables{1}.EMGTime));
[filtB, filtA] = butter(FILTER_ORDER, lpfCutoffHz / (Fs / 2), 'low');

% filtfilt 기본 padding(계수 개수 x 3, 몇 샘플 안 됨)은 lpfCutoffHz처럼 매우 낮은
% cutoff에서는 필터가 정착하기에 턱없이 부족해 step 양 끝에서 값이 왜곡된다.
% 필터의 시간상수(~Fs/cutoff)에 비례해 padding을 직접 늘려서 이를 방지한다.
padLenTarget = ceil(3 * Fs / lpfCutoffHz);

xAxisLabel = sprintf('Affected Side (%s) Gait Cycle (%%)', sideNames.(affectedSide));

totalCombos = numel(muscleNames) * numel(trials);
comboIdx = 0;

for m = 1:numel(muscleNames)
    col = muscleNames{m};
    parts = strsplit(col, '_');
    side = sideNames.(parts{1});
    muscle = muscleFullNames.(parts{2});
    kneeCol = sprintf('%s_knee_angle', sideWordMap.(parts{1}));
    ankleCol = sprintf('%s_ankle_angle', sideWordMap.(parts{1}));

    for t = 1:numel(trials)
        steps = trials(t).tables;
        stepNums = trials(t).steps;
        muscleOutDir = fullfile(outDir, 'RawEMG_Angle', trials(t).name, col);
        if ~exist(muscleOutDir, 'dir')
            mkdir(muscleOutDir);
        end

        comboIdx = comboIdx + 1;
        fprintf('  [%s/%s] RawEMG_Angle (%d/%d) %s - %s: %d steps ...\n', ...
            subject, dateStr, comboIdx, totalCombos, trials(t).name, col, numel(steps));

        for s = 1:numel(steps)
            Ttab = steps{s};
            x = Ttab.GaitCycle;
            yRaw = Ttab.(col);
            yKnee = Ttab.(kneeCol);
            yAnkle = Ttab.(ankleCol);

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

            f = figure('Color', 'w', 'Position', [0 0 1200 900], 'Visible', 'off');

            subplot(2, 1, 1);
            hold on;
            hRaw = plot(x, yRaw, 'Color', RAW_COLOR, 'LineWidth', 1);
            hRaw.Color(4) = RAW_ALPHA;  % 미문서화이지만 R2014b+에서 안정적으로 동작하는 line 투명도 지정 방법
            plot(x, yFilt, 'Color', FILT_COLOR, 'LineWidth', 2.2);
            hold off;
            set(gca, 'FontSize', 18);
            ylabel('Normalized Muscle Activation');
            ylim([0 2]);
            xlim([0 100]);
            legend({'Raw', sprintf('%g Hz LPF', lpfCutoffHz)}, 'FontSize', 14, 'Location', 'best');

            subplot(2, 1, 2);
            hold on;
            plot(x, yKnee, 'Color', KNEE_COLOR, 'LineWidth', 2.2);
            plot(x, yAnkle, 'Color', ANKLE_COLOR, 'LineWidth', 2.2);
            hold off;
            set(gca, 'FontSize', 18);
            xlabel(xAxisLabel);
            ylabel('Angles (deg)');
            ylim(ANGLE_YLIM);
            xlim([0 100]);
            legend({'Knee', 'Ankle'}, 'FontSize', 14, 'Location', 'best');

            sgtitle(sprintf('%s(%s) - %s step%d - %s %s', subject, dateStr, trials(t).name, stepNums(s), side, muscle), 'FontSize', 22);

            saveas(f, fullfile(muscleOutDir, sprintf('step%d.png', stepNums(s))));
            close(f);
        end
    end
end
end
