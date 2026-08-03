function cycleTables = processTrialCycles(emgPath, gaitPath, trigger, pct, sensorNames, muscleNames)
% PROCESSTRIALCYCLES  trial 1개(bare/P1/P2/P3)에 대해 gait cycle별로 EMG를 자른
% (rectify 이전의 원본 raw 값) 테이블 목록을 반환한다. offset 보정과 rectify는
% 같은 날짜 전체를 모아야 하므로 processSubjectDate에서 이어서 처리한다.
%   sensorNames{m} <-> muscleNames{m} 매핑을 이용해 파일마다 다른 센서 컬럼
%   순서를 muscleNames 순서로 재배열한다.
%   cycleTables{c} 컬럼: EMGTime, AFOTime, GaitCycle, muscleNames{:} (raw, mV)
%   EMGTime : EMG csv 자체 시계(초). AFOTime : trigger를 더해 복원한 AFO(ROS) epoch 시계(초)
%   - gaitCycle_*.csv Time 컬럼 및 AFO/*.bag 토픽과 같은 시간축이라 직접 대조 가능.

hdr = parseEMGHeader(emgPath);
cycles = extractCycleWindows(gaitPath, trigger, pct, hdr.collectionLength);

muscleColIdx = nan(1, numel(muscleNames));
for m = 1:numel(muscleNames)
    idx = find(strcmp(hdr.sensorNames, sensorNames{m}), 1);
    if isempty(idx)
        error('processTrialCycles:sensorNotFound', ...
            'Sensor "%s" not found in header of %s', sensorNames{m}, emgPath);
    end
    muscleColIdx(m) = idx;
end

cycleTables = cell(numel(cycles), 1);
for c = 1:numel(cycles)
    win = readEMGWindow(emgPath, hdr, cycles(c).startRel, cycles(c).endRel);
    pctVec = gaitPercentInterp(win.time, cycles(c));
    afoTimeVec = win.time + trigger;
    vals = win.values(:, muscleColIdx);
    cycleTables{c} = array2table([win.time, afoTimeVec, pctVec, vals], ...
        'VariableNames', [{'EMGTime', 'AFOTime', 'GaitCycle'}, muscleNames]);
end

cycleTables = realignToTrueCycles(cycleTables);
end

function outTables = realignToTrueCycles(inTables)
% REALIGNTOTRUECYCLES  각 cycle의 앞머리(90~100%로 wrap된, 실제로는 이전 cycle의
%   꼬리)를 이전 cycle 뒤로 옮겨 붙여, 매 step이 진짜 0~100% 한 사이클을 온전히·
%   연속적으로 담게 한다. cycle 경계가 low tick 시각 기준이라 pct(1)<0인
%   subject(예: SAH03)는 low tick이 진짜 phase 0%보다 앞서 있어서, cycle마다
%   앞부분에 이전 cycle의 90~100% 데이터가 wrap되어 섞여 들어와 있었다.
%   맨 처음 cycle의 앞머리(붙일 이전 step이 없음)와 마지막 cycle의 몸통(붙여줄
%   다음 wrap 조각이 없어 90~100%를 못 채움)은 불완전하므로 버려서, trial당
%   step 개수가 N개에서 N-1개로 줄어든다.

n = numel(inTables);
wrapIdx = cell(n, 1);
for c = 1:n
    wrapIdx{c} = find(diff(inTables{c}.GaitCycle) < -50, 1);
end

if all(cellfun(@isempty, wrapIdx))
    outTables = inTables;  % pct(1)>=0인 subject(예: SAH01)는 wrap이 없어 그대로
    return
end

outTables = cell(n - 1, 1);
for c = 1:n - 1
    back = inTables{c};
    if ~isempty(wrapIdx{c})
        back = back(wrapIdx{c} + 1:end, :);
    end
    front = inTables{c + 1};
    if ~isempty(wrapIdx{c + 1})
        front = front(1:wrapIdx{c + 1}, :);
    else
        front = front([], :);
    end
    outTables{c} = [back; front];
end
end
