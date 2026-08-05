function outTables = realignToTrueCycles(inTables)
% REALIGNTOTRUECYCLES  각 cycle의 앞머리(90~100%로 wrap된, 실제로는 이전 cycle의
%   꼬리)를 이전 cycle 뒤로 옮겨 붙여, 매 step이 진짜 0~100% 한 사이클을 온전히·
%   연속적으로 담게 한다. cycle 경계가 low tick 시각 기준이라 pct(1)<0인
%   subject(예: SAH03)는 low tick이 진짜 phase 0%보다 앞서 있어서, cycle마다
%   앞부분에 이전 cycle의 90~100% 데이터가 wrap되어 섞여 들어와 있었다.
%   맨 처음 cycle의 앞머리(붙일 이전 step이 없음)와 마지막 cycle의 몸통(붙여줄
%   다음 wrap 조각이 없어 90~100%를 못 채움)은 불완전하므로 버려서, trial당
%   step 개수가 N개에서 N-1개로 줄어든다.
%   (원래 processTrialCycles.m의 로컬 함수였던 것을 EMG/AFO 양쪽에서 재사용하기
%   위해 분리했다. 동작은 그대로다.)

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
