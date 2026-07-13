% run_EMG_processing.m
% EMG 데이터를 sync 정보로 0초를 맞추고, gait cycle 정보로 step 단위로 잘라
% rectify + 같은 날짜 RMS normalize를 적용해 Subject/날짜/EMG_processed/에 저장한다.
% (대응하는 sync/gaitCycle 파일이 있는 subject/날짜 조합만 처리)

clear; clc;
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));

rootDir = fullfile(fileparts(mfilename('fullpath')), '..');

targets = struct( ...
    'subject', {'SAH01', 'SAH01', 'SAH03', 'SAH03'}, ...
    'dateStr', {'260706', '260713', '260623', '260630'});

for i = 1:numel(targets)
    processSubjectDate(targets(i).subject, targets(i).dateStr, rootDir);
end

fprintf('\n=== All subject/date processing complete ===\n');
