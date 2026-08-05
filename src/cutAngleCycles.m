function cycleTables = cutAngleCycles(angleTable, gaitPath, trigger, pct, collectionLength)
% CUTANGLECYCLES  computeAFOJointAngles가 만든 트라이얼 전체 각도 테이블을,
% EMG와 같은 gait cycle 경계(extractCycleWindows)로 step 단위로 자른다.
% gaitPath/trigger/pct/collectionLength를 EMG 쪽과 동일하게 넣으면 같은 step
% 경계가 나오므로, EMG_processed와 step 번호가 그대로 대응된다.
%   angleTable 컬럼: AFOTime, <관절각 컬럼들...> (computeAFOJointAngles 참고)
%   cycleTables{c} 컬럼: EMGTime, AFOTime, GaitCycle, <관절각 컬럼들...>

cycles = extractCycleWindows(gaitPath, trigger, pct, collectionLength);
jointNames = angleTable.Properties.VariableNames(2:end);

relTime = angleTable.AFOTime - trigger;  % EMGTime과 같은(trigger 기준) 시간축

cycleTables = cell(numel(cycles), 1);
for c = 1:numel(cycles)
    mask = relTime >= cycles(c).startRel & relTime <= cycles(c).endRel;
    winTime = relTime(mask);
    pctVec = gaitPercentInterp(winTime, cycles(c));
    afoTimeVec = angleTable.AFOTime(mask);
    vals = angleTable{mask, jointNames};
    cycleTables{c} = array2table([winTime, afoTimeVec, pctVec, vals], ...
        'VariableNames', [{'EMGTime', 'AFOTime', 'GaitCycle'}, jointNames]);
end

cycleTables = realignToTrueCycles(cycleTables);
end
