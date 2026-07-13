function ticks = readGaitCycleTicks(csvPath)
% READGAITCYCLETICKS  gaitCycle_*.csv(Time,data)를 읽고, 연속으로 같은 값이
% 들어온 tick은 먼저 들어온 값(앞쪽 timestamp)만 남긴다.
%   ticks : [time, state] (state는 1=low, 2=high로 엄격히 교대)

T = readtable(csvPath);
state = T.data;
keep = [true; diff(state) ~= 0];
ticks = [T.Time(keep), state(keep)];
end
