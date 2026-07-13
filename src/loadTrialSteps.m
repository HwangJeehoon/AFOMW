function stepTables = loadTrialSteps(subject, dateStr, outPrefix, steps, rootDir)
% LOADTRIALSTEPS  EMG_processed/{outPrefix}_step{N}.csv를 steps 순서로 읽어
%   테이블 cell array로 반환한다.
%   outPrefix : 'bare'/'P1'/'P2'/'P3'
%   steps     : 사용할 step 번호 벡터 (예: 5:70)

if nargin < 5
    rootDir = pwd;
end

procDir = fullfile(rootDir, subject, dateStr, 'EMG_processed');
stepTables = cell(numel(steps), 1);
for i = 1:numel(steps)
    p = fullfile(procDir, sprintf('%s_step%d.csv', outPrefix, steps(i)));
    stepTables{i} = readtable(p);
end
end
