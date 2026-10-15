function [mwAFOTime, info] = syncMWToGaitCycle(mw, gaitPath, pct, affectedSide, trigger)
% SYNCMWTOGAITCYCLE  MW 샘플마다 AFO(ROS) epoch 시각을 부여한다.
%   gaitCycle_*.csv의 tick은 MW 환측 GaitCycleRate가 pct(2)를 지날 때 high(2),
%   pct(3)을 지날 때 low(1)로 들어온다. tick과 MW 쪽 같은 경계 통과 시점을 1:1로
%   짝지은 뒤, 그 사이의 MW 샘플은 sample index에 비례해 선형보간한다
%   (MW CSV 시각의 0.1 s 양자화에 영향받지 않는다).
%
%   몇 번째 cycle끼리 짝인지(cycle 주기 단위 모호성)는 다음 순서로 정한다.
%     1) tick이 TRAIN_GAP_S 넘게 끊기는 곳에서 나눠 가장 긴 연속 구간(train)만 쓴다
%        (앞쪽 외톨이 tick, 중단된 시도의 tick 제외).
%     2) train 첫 tick을 같은 종류의 MW 첫 이벤트와 짝짓는다.
%     3) train 앞 tick을 한 cycle(high/low 2개)씩 버려 가며, 마지막 tick과 MW 기록
%        끝의 차이(EndGap)가 가장 작은 짝짓기를 고른다 (MW 기록 끝 = sync train 끝).
%
%   mw           : MW CSV 테이블 (p_trainingSaveTime, p_left/rightCurrentGaitCycleRate)
%   pct          : [start mid end] gait cycle % 경계 (pipeline_config의 gaitPct)
%   affectedSide : 'L' 또는 'R' (gait cycle tick을 만든 환측)
%   trigger      : syncEMG의 trial 시작 Unix time (MW 시계의 시(hour) 복원에만 사용)
%   mwAFOTime    : [N x 1] MW 샘플별 AFO epoch 시각(초)
%   info         : 짝짓기 진단값. ClockLag는 AFO 시계 - MW 시계(초), EndGap은
%                  마지막 tick - MW 기록 끝(초, AFO 시계 기준)

TRAIN_GAP_S = 6;    % gait cycle(4 s)보다 길게 끊기면 다른 tick 구간으로 본다
MAX_SHIFT = 2;      % train 앞에서 버려 볼 최대 cycle 수
MATCH_TOL_S = 0.5;  % 같은 종류 이벤트는 한 cycle 간격이라 이 정도면 혼동이 없다

% MW 시계: mm:ss.s -> 초. 시(hour)는 trigger와 가장 가까운 값으로 복원한다.
parts = split(string(mw.p_trainingSaveTime), ':');
mwSec = str2double(parts(:, 1)) * 60 + str2double(parts(:, 2));
mwSec = mwSec + 3600 * cumsum([0; diff(mwSec) < -1800]);
hourCand = floor(trigger / 3600) * 3600 + (-1:1) * 3600;
[~, h] = min(abs(hourCand + mwSec(1) - trigger));
mwT = hourCand(h) + mwSec;

% MW 이벤트: 환측 rate의 100 -> 0 wrap을 풀어 연속 위상으로 만든 뒤 경계 통과 지점을 찾는다.
if strcmp(affectedSide, 'L')
    rate = mw.p_leftCurrentGaitCycleRate;
else
    rate = mw.p_rightCurrentGaitCycleRate;
end
phase = rate + 100 * cumsum([0; diff(rate) < -50]);
idxHigh = crossingIndex(phase, pct(2));
idxLow = crossingIndex(phase, pct(3));
[evIdx, order] = sort([idxHigh; idxLow]);
evKind = [2 * ones(size(idxHigh)); ones(size(idxLow))];
evKind = evKind(order);
evT = interp1((1:numel(mwT))', mwT, evIdx);

% gaitCycle tick: extractCycleWindows와 같이 연속 중복값을 버리고, 가장 긴 연속 구간만 쓴다.
G = readtable(gaitPath);
keep = [true; diff(G.data) ~= 0];
tickT = G.Time(keep);
tickKind = G.data(keep);
trainId = cumsum([1; diff(tickT) > TRAIN_GAP_S]);
inTrain = trainId == mode(trainId);
tickT = tickT(inTrain);
tickKind = tickKind(inTrain);

% 앞을 기준으로 짝짓고, 끝이 가장 잘 맞을 때까지 train 앞 tick을 한 cycle씩 버린다.
k0 = find(evKind == tickKind(1), 1);
best = struct('shift', NaN, 'lag', NaN, 'endGap', Inf);
for s = 0:MAX_SHIFT
    iTick = (1 + 2 * s):numel(tickT);
    iEv = k0:numel(evT);
    n = min(numel(iTick), numel(iEv));
    lag = median(tickT(iTick(1:n)) - evT(iEv(1:n)));
    endGap = tickT(end) - (mwT(end) + lag);
    if abs(endGap) < abs(best.endGap)
        best = struct('shift', s, 'lag', lag, 'endGap', endGap);
    end
end

% 정한 lag로 tick마다 같은 종류의 가장 가까운 MW 이벤트를 매칭한다.
matchIdx = nan(size(tickT));
for j = 1:numel(tickT)
    cand = find(evKind == tickKind(j));
    [d, m] = min(abs(evT(cand) + best.lag - tickT(j)));
    if d < MATCH_TOL_S
        matchIdx(j) = cand(m);
    end
end
ok = ~isnan(matchIdx);
anchorIdx = evIdx(matchIdx(ok));
anchorT = tickT(ok);
mwAFOTime = interp1(anchorIdx, anchorT, (1:height(mw))', 'linear', 'extrap');

info = struct( ...
    'TrainTicks', numel(tickT), 'MWEvents', numel(evT), 'Matched', nnz(ok), ...
    'ShiftCycles', best.shift, 'EndGap', best.endGap, 'ClockLag', best.lag, ...
    'ResidualSD', std(anchorT - (evT(matchIdx(ok)) + best.lag)));
end

function idx = crossingIndex(phase, thr)
% 연속 위상 phase가 thr + 100k를 지나는 지점의 소수점 sample index
k = floor((phase - thr) / 100);
i = find(diff(k) > 0) + 1;
level = thr + 100 * k(i);
idx = (i - 1) + (level - phase(i - 1)) ./ (phase(i) - phase(i - 1));
end
