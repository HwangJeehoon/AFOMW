function inspect_kinematics_zero()
% INSPECT_KINEMATICS_ZERO  모든 활성 target의 AFO bag에서 /afo_gui/kinematics_zero
% 메시지마다 시점과 그때의 관절각을 구하고, MW 시작 직전 정지 구간으로 다시 잡은
% stand zeroing(revised_stand)과 함께 CSV 두 개로 저장한다.
%   <root>/kinematics_zero_survey.csv : 메시지 하나당 한 행 + trial마다 revised_stand 한 행
%   <root>/revised_stand_zeroing.csv  : trial당 한 행, stand와 revised_stand 관절각 비교
%
%   Role       : global(첫 번째, holder) / stand(마지막, cfg.angleZeroing='stand'일 때
%                관절각 영점) / extra(그 사이) / revised_stand(아래)
%   revised_stand : MW 기록 시작(syncMWToGaitCycle로 AFO 시계로 옮긴 MW 첫 행) 이전 마지막
%                정지 구간(findStillWindow)의 평균. cfg.angleZeroing='revised_stand'일 때
%                관절각 영점이다. 로봇은 MW 기록 시작 1~4 s 전부터 움직이므로 MW 시작
%                직전 몇 초가 아니라 그 앞의 정지 구간을 찾는다. Time_epoch는 구간 중앙이다.
%   MultiStand : kinematics_zero가 3개 이상(= global 뒤에 2번 이상) 들어온 trial
%   TFromTrigger_s : syncEMG trial 시작 시각 기준, TBeforeWalk_s : 보행 구간
%                (AFO_calibration.csv의 FunctionalStartTime) 시작까지 남은 시간,
%                TBeforeMW0_s : MW 기록 시작까지 남은 시간
%   MaxEulerChange_deg : 7개 IMU의 roll/pitch/yaw가 global zeroing 이후 바뀐 최대 각도.
%                HOLDER_TOL_DEG보다 작으면(InHolder) 센서가 아직 holder에 있을 때 찍힌 것이다.
%   MaxEulerDev1s_deg : 그 시점 전후 0.5 s 동안 roll/pitch/yaw가 그 시점 값에서 벗어난
%                최대 각도. 작을수록 가만히 서 있던 상태에서 찍힌 것이다.
%   StillWinRange_deg : revised_stand 구간 안에서 6개 관절각 변화 폭의 최대값
%   관절각(L/R_hip/knee/ankle)은 global zeroing(holder) 기준, stand zeroing 보정 전 값이다.
%   computeAFOJointAngles 출력(stand 기준)에서 global zeroing 시점 값을 빼 되돌렸으므로
%   부호 규칙(hip/knee flexion +, ankle plantarflexion +)은 같고, ±180°로 wrap했다.
%   RevisedMinusStand_* 만큼 각 trial의 관절각 곡선이 아래로 평행이동하면 revised_stand 기준이 된다.
%   revised_stand_zeroing.csv의 접미사 없는 Revised* 컬럼은 findStillWindow 기본 기준(0.5 s,
%   2.5도, 파이프라인이 쓰는 값)이고, EXTRA_STILL_CRITERIA의 기준마다 같은 컬럼이 접미사를 붙여
%   추가된다(예: Revised_L_hip_2s3deg).

HOLDER_TOL_DEG = 2;
EXTRA_STILL_CRITERIA = {2, 3, '_2s3deg'; 1, 2, '_1s2deg'};  % {구간 길이(s), 허용 변화(deg), 컬럼 접미사}

clc;
scriptDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(scriptDir));
addpath(fullfile(rootDir, 'src'));
addpath(fullfile(fileparts(scriptDir), 'config'));

cfg = pipeline_config();
targets = cfg.targets([cfg.targets.enabled]);
jointNames = {'left_hip_angle', 'left_knee_angle', 'left_ankle_angle', ...
    'right_hip_angle', 'right_knee_angle', 'right_ankle_angle'};
shortNames = {'L_hip', 'L_knee', 'L_ankle', 'R_hip', 'R_knee', 'R_ankle'};
wrap180 = @(x) mod(x + 180, 360) - 180;

rows = {};
revisedRows = {};
for i = 1:numel(targets)
    target = targets(i);
    paths = getSubjectDatePaths(cfg.rootDir, target.subject, target.dateStr);
    syncTable = readtable(fullfile(paths.syncDir, ...
        sprintf('syncEMG_%s_%s.csv', target.subject, target.dateStr)), 'TextType', 'string');
    syncMap = containers.Map(cellstr(lower(strtrim(syncTable.Trial))), num2cell(syncTable.Time));
    cal = readtable(fullfile(paths.emgAfoStepsDir, 'AFO_calibration.csv'), 'TextType', 'string');

    for j = 1:numel(cfg.trials)
        trial = cfg.trials(j);
        bagPath = fullfile(paths.afoRawDir, trial.bagFile);
        if ~isfile(bagPath)
            fprintf('%s/%s/%s: (bag 없음)\n', ...
                target.subject, target.dateStr, trial.label);
            continue
        end

        zeroRaw = readAFOBagTopic(bagPath, '/afo_gui/kinematics_zero');
        zeroTimes = zeroRaw.Time;
        nZero = numel(zeroTimes);
        angleTable = computeAFOJointAngles(bagPath);
        imuRaw = readAFOBagTopic(bagPath, '/afo_sensor/imu');
        euler = imuRaw.Data(:, 2:end);
        euler = euler(:, sort([1:9:end, 2:9:end, 3:9:end]));  % IMU별 [roll pitch yaw]만
        walkStart = cal.FunctionalStartTime(find(cal.Trial == trial.label, 1));
        trigger = syncMap(trial.key);

        mw = readMWCsv(fullfile(paths.mwRawDir, trial.mwFile));
        gaitPath = fullfile(paths.syncDir, sprintf('gaitCycle_%s_%s_%s.csv', ...
            target.subject, target.dateStr, trial.gaitSuffix));
        mwAFOTime = syncMWToGaitCycle(mw, gaitPath, target.gaitPct, target.affectedSide, trigger);
        mwStart = mwAFOTime(1);

        t = angleTable.AFOTime;
        [~, idxGlobal] = min(abs(t - zeroTimes(1)));
        holderAngles = wrap180(angleTable{:, jointNames} - angleTable{idxGlobal, jointNames});
        [~, idxGlobalImu] = min(abs(imuRaw.Time - zeroTimes(1)));
        [stillStart, stillEnd, stillMean, stillMaxRange] = findStillWindow(t, holderAngles, mwStart);
        stillCenter = (stillStart + stillEnd) / 2;
        fprintf('%s/%s/%s: kinematics_zero count=%d, t-trigger(s)=%s, revised_stand %.1f s before MW start\n', ...
            target.subject, target.dateStr, trial.label, nZero, mat2str((zeroTimes - trigger)', 4), ...
            mwStart - stillCenter);

        rowTimes = zeroTimes;
        if isnan(stillCenter)
            fprintf('  -> MW 시작 전 정지 구간이 없어 revised_stand를 건너뜁니다.\n');
        else
            rowTimes(end + 1) = stillCenter; %#ok<AGROW>
        end
        for k = 1:numel(rowTimes)
            tk = rowTimes(k);
            if k > nZero
                role = 'revised_stand';
                msgIdx = NaN;
                angles = stillMean;
                winRange = stillMaxRange;
            else
                if k == 1
                    role = 'global';
                elseif k == nZero
                    role = 'stand';
                else
                    role = 'extra';
                end
                msgIdx = k;
                [~, idx] = min(abs(t - tk));
                angles = holderAngles(idx, :);
                winRange = NaN;
            end
            [~, idxImu] = min(abs(imuRaw.Time - tk));
            maxEuler = max(abs(wrap180(euler(idxImu, :) - euler(idxGlobalImu, :))));
            win = abs(imuRaw.Time - tk) <= 0.5;
            eulerDev = max(abs(wrap180(euler(win, :) - euler(idxImu, :))), [], 'all');

            rows(end + 1, :) = [{target.subject, target.dateStr, target.affectedSide, trial.label, ...
                nZero, nZero > 2, msgIdx, role, tk, round(tk - trigger, 2), ...
                round(walkStart - tk, 2), round(mwStart - tk, 2), round(maxEuler, 2), ...
                maxEuler < HOLDER_TOL_DEG, round(eulerDev, 2), round(winRange, 2)}, ...
                num2cell(round(angles, 2))]; %#ok<AGROW>
        end

        if ~isnan(stillCenter)
            [~, idxStand] = min(abs(t - zeroTimes(end)));
            standAngles = holderAngles(idxStand, :);
            extra = {};
            for v = 1:size(EXTRA_STILL_CRITERIA, 1)
                [s0, s1, m, r] = findStillWindow(t, holderAngles, mwStart, EXTRA_STILL_CRITERIA{v, 1:2});
                extra = [extra, {round(mwStart - (s0 + s1) / 2, 2), round(r, 2)}, ...
                    num2cell(round(m, 2)), num2cell(round(m - standAngles, 2))]; %#ok<AGROW>
            end
            revisedRows(end + 1, :) = [{target.subject, target.dateStr, target.affectedSide, ...
                trial.label, round(mwStart - zeroTimes(end), 2), round(mwStart - stillCenter, 2), ...
                round(stillMaxRange, 2)}, num2cell(round(standAngles, 2)), ...
                num2cell(round(stillMean, 2)), num2cell(round(stillMean - standAngles, 2)), extra]; %#ok<AGROW>
        end
    end
end

survey = cell2table(rows, 'VariableNames', [{'Subject', 'Date', 'AffectedSide', 'Trial', ...
    'NumZeroMsgs', 'MultiStand', 'MsgIdx', 'Role', 'Time_epoch', 'TFromTrigger_s', ...
    'TBeforeWalk_s', 'TBeforeMW0_s', 'MaxEulerChange_deg', 'InHolder', 'MaxEulerDev1s_deg', ...
    'StillWinRange_deg'}, shortNames]);
outPath = fullfile(cfg.rootDir, 'kinematics_zero_survey.csv');
writetable(survey, outPath);
fprintf('saved: %s\n', outPath);

revisedNames = [{'Subject', 'Date', 'AffectedSide', 'Trial', ...
    'StandTBeforeMW0_s', 'RevisedTBeforeMW0_s', 'StillWinRange_deg'}, strcat('Stand_', shortNames), ...
    strcat('Revised_', shortNames), strcat('RevisedMinusStand_', shortNames)];
for v = 1:size(EXTRA_STILL_CRITERIA, 1)
    sfx = EXTRA_STILL_CRITERIA{v, 3};
    revisedNames = [revisedNames, {['RevisedTBeforeMW0_s' sfx], ['StillWinRange_deg' sfx]}, ...
        strcat('Revised_', shortNames, sfx), strcat('RevisedMinusStand_', shortNames, sfx)]; %#ok<AGROW>
end
revised = cell2table(revisedRows, 'VariableNames', revisedNames);
outPath = fullfile(cfg.rootDir, 'revised_stand_zeroing.csv');
writetable(revised, outPath);
fprintf('saved: %s\n', outPath);
end
