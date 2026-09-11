function stepTables = loadTrialSteps(subject, dateStr, outPrefix, steps, rootDir)
% LOADTRIALSTEPS  EMG_processed/{trialKey}/step{N}.csv를 steps 순서로 읽어
%   테이블 cell array로 반환한다.
%   outPrefix : 'bare'/'P1'/'P2'/'P3' (폴더 이름은 소문자: bare/p1/p2/p3)
%   steps     : 사용할 step 번호 벡터 (예: 5:70)

if nargin < 5
    rootDir = pwd;
end

procDir = fullfile(rootDir, subject, dateStr, 'EMG_processed', lower(outPrefix));
stepTables = cell(numel(steps), 1);
for i = 1:numel(steps)
    p = fullfile(procDir, sprintf('step%d.csv', steps(i)));
    stepTables{i} = readProcessedEMGCsv(p);
end
end
