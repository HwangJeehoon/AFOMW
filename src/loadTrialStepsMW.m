function stepTables = loadTrialStepsMW(subject, dateStr, outPrefix, steps, rootDir)
% LOADTRIALSTEPSMW  processed/emg_afo_mw_steps/{trialKey}/step{N}.csv를 steps 순서로
%   읽어 테이블 cell array로 반환한다. 'endheader'까지 메타데이터 줄이 있으므로
%   readProcessedEMGCsv로 읽는다(컬럼 구성은 processSubjectDateMW 참고).
%   outPrefix : 'bare'/'P1'/'P2'/'P3' (폴더 이름은 소문자: bare/p1/p2/p3)
%   steps     : 사용할 step 번호 벡터 (예: 5:70)

if nargin < 5
    rootDir = pwd;
end

paths = getSubjectDatePaths(rootDir, subject, dateStr);
procDir = fullfile(paths.emgAfoMwStepsDir, lower(outPrefix));
stepTables = cell(numel(steps), 1);
for i = 1:numel(steps)
    p = fullfile(procDir, sprintf('step%d.csv', steps(i)));
    stepTables{i} = readProcessedEMGCsv(p);
end
end
