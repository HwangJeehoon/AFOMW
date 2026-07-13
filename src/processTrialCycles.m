function cycleTables = processTrialCycles(emgPath, gaitPath, trigger, pctBreakpoints)
% PROCESSTRIALCYCLES  trial 1개(bare/P1/P2/P3)에 대해 gait cycle별로 EMG를
% 잘라 rectify까지 적용한 테이블 목록을 반환한다.
%   cycleTables{c} 컬럼: Time, GaitCycle, L_TA, L_GM, L_RF, L_VL, R_TA, R_GM, R_RF, R_VL

hdr = parseEMGHeader(emgPath);
ticks = readGaitCycleTicks(gaitPath);
cycles = extractCycleWindows(ticks, trigger, pctBreakpoints, hdr.collectionLength);

[sensorNames, muscleNames] = muscleSensorMap();
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
    vals = abs(win.values(:, muscleColIdx));
    cycleTables{c} = array2table([win.time, pctVec, vals], ...
        'VariableNames', [{'Time', 'GaitCycle'}, muscleNames]);
end
end
