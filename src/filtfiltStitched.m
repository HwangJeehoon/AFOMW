function yFilt = filtfiltStitched(filtB, filtA, yPrev, yCur, yNext, padLenTarget)
% FILTFILTSTITCHED  filtfilt 전에 step 경계 양쪽에 (가능하면) 이웃 step의 실제
%   EMG 데이터를 이어붙여 패딩한 뒤 필터링하고, 다시 이 step 길이만큼만 잘라
%   반환한다. realignToTrueCycles(processTrialCycles.m)로 같은 trial 안에서는
%   인접 step끼리 시간이 끊김 없이 이어지므로, 합성 반사(odd-reflection) 패딩
%   대신 진짜 이웃 데이터를 쓰면 gait cycle 경계(0%/100%)에서 필터가 왜곡 없이
%   정착한다. 이웃 step이 없는 trial 맨 처음/마지막 step만 odd-reflection으로
%   대체한다.

n = numel(yCur);

if ~isempty(yPrev)
    padLenL = min(padLenTarget, numel(yPrev));
    leftPad = yPrev(end - padLenL + 1:end);
else
    padLenL = min(padLenTarget, n - 1);
    leftPad = 2 * yCur(1) - yCur(padLenL + 1:-1:2);
end

if ~isempty(yNext)
    padLenR = min(padLenTarget, numel(yNext));
    rightPad = yNext(1:padLenR);
else
    padLenR = min(padLenTarget, n - 1);
    rightPad = 2 * yCur(end) - yCur(end - 1:-1:end - padLenR);
end

yPadded = [leftPad; yCur; rightPad];
yFiltPadded = filtfilt(filtB, filtA, yPadded);
yFilt = yFiltPadded(padLenL + 1:padLenL + n);
end
