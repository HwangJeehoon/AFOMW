function cycles = extractCycleWindows(ticks, trigger, pct, collectionLength)
% EXTRACTCYCLEWINDOWS  정리된 gait cycle tick들로부터 유효한 step(gait cycle) 경계를 만든다.
%   한 step = low 시작 tick -> 다음 low 시작 tick.
%   EMG 녹화 범위(0~collectionLength) 밖으로 걸치는 step은 제외한다.
%   결과는 시간 순으로 정렬되어 있어, 배열 인덱스가 곧 step 번호가 된다.

t = ticks(:, 1);
state = ticks(:, 2);
lowIdx = find(state == 1);

cycles = struct('startRel', {}, 'midRel', {}, 'endRel', {}, ...
                 'startPct', {}, 'midPct', {}, 'endPct', {});

for k = 1:numel(lowIdx) - 1
    iStart = lowIdx(k);
    iNext = lowIdx(k + 1);
    if iNext ~= iStart + 2 || state(iStart + 1) ~= 2
        warning('extractCycleWindows:unexpectedPattern', ...
            'Non-alternating gait cycle tick pattern near t=%.3f; skipping.', t(iStart));
        continue
    end

    startRel = t(iStart) - trigger;
    midRel = t(iStart + 1) - trigger;
    endRel = t(iNext) - trigger;
    if startRel < 0 || endRel > collectionLength
        continue
    end

    cycles(end + 1) = struct( ...
        'startRel', startRel, 'midRel', midRel, 'endRel', endRel, ...
        'startPct', pct(1), 'midPct', pct(2), 'endPct', pct(3)); %#ok<AGROW>
end
end
