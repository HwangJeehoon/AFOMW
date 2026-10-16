function [startTime, endTime, meanAngles, maxRange] = findStillWindow(t, angles, tEnd, winS, tolDeg)
% FINDSTILLWINDOW  tEnd 이전에서 0.1 s씩 거슬러 올라가며, 길이 winS 구간 안 모든
% 관절각(angles의 각 열)의 변화 폭(max - min)이 tolDeg 미만인 가장 늦은 구간을 찾는다.
% revised stand zeroing(로봇이 움직이기 전 가만히 서 있던 자세)에 쓴다.
% SEARCH_S 안에 그런 구간이 없으면 모두 NaN을 반환한다.
%   t          : [N x 1] 시각(초)
%   angles     : [N x M] 관절각(deg). 변화 폭만 보므로 영점이 어디든 상관없다.
%   tEnd       : 탐색을 시작할(구간이 끝날 수 있는 가장 늦은) 시각. 보통 MW 기록 시작
%   winS, tolDeg : 구간 길이(s)와 허용 변화 폭(deg). 생략하면 파이프라인 기본값 0.5 s, 2.5도.
%                보행 직전 로봇이 다리를 초당 2~4도로 천천히 옮기는 구간이 있어, 2 s/3도처럼
%                구간이 길면 그 구간이 탈락하고 훨씬 앞의 다른 자세가 잡힌다. 0.5 s면 그 이동이
%                끝난 보행 시작 직전 자세가 잡힌다.
%   meanAngles : [1 x M] 구간 안 관절별 평균
%   maxRange   : 구간 안 관절별 변화 폭 중 최대값(deg)

SEARCH_S = 30;
if nargin < 4
    winS = 0.5;
end
if nargin < 5
    tolDeg = 2.5;
end

startTime = NaN;
endTime = NaN;
meanAngles = nan(1, size(angles, 2));
maxRange = NaN;
for e = tEnd:-0.1:(tEnd - SEARCH_S)
    w = t > e - winS & t <= e;
    r = max(angles(w, :), [], 1) - min(angles(w, :), [], 1);
    if max(r) < tolDeg
        startTime = e - winS;
        endTime = e;
        meanAngles = mean(angles(w, :), 1);
        maxRange = max(r);
        return
    end
end
end
