function pctVec = gaitPercentInterp(timeVec, cycle)
% GAITPERCENTINTERP  시간(초) -> gait cycle %로 변환하는 2단 선형보간.
%   [startRel, midRel] 구간은 [startPct, midPct]로,
%   (midRel, endRel] 구간은 [midPct, endPct]로 각각 시간 비례 보간한다.

pctVec = nan(size(timeVec));
inLow = timeVec <= cycle.midRel;
inHigh = ~inLow;

pctVec(inLow) = cycle.startPct + (timeVec(inLow) - cycle.startRel) ...
    / (cycle.midRel - cycle.startRel) * (cycle.midPct - cycle.startPct);
pctVec(inHigh) = cycle.midPct + (timeVec(inHigh) - cycle.midRel) ...
    / (cycle.endRel - cycle.midRel) * (cycle.endPct - cycle.midPct);
end
